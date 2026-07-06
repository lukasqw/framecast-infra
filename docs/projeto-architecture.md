# Framecast — Arquitetura (v6)

Sistema de processamento de vídeos: upload via web, extração de frames com FFmpeg, entrega de ZIP. Multi-tenant, escalável, resiliente a picos, com autenticação, notificações e observabilidade.

**Componentes:**

- **`api`** — modular monolith Go (Clean Architecture): auth (HS256), videos, status, outbox + frontend embutido (`embed.FS`)
- **`worker`** — consumer SQS + FFmpeg + S3 + envio de e-mail inline (SES)

**Repositórios (5):** `framecast-infra` · `framecast-db` · `framecast-gateway` · `framecast-api` · `framecast-worker`

> Plano de implementação detalhado da `api` (endpoints, modelo de dados, fases): `PLAN_FRAMECAST_API.md`.
> Diagrama com ícones oficiais AWS: [`framecast-infra/docs/architecture-aws.drawio`](framecast-infra/docs/architecture-aws.drawio) ([PNG](framecast-infra/docs/architecture-aws.drawio.png)).

---

## 1. Visão Geral (C4 — Nível de Contêineres)

```
                    ┌─────────────────────────────────────────┐
                    │                Usuário                   │
                    └─────────────────┬───────────────────────┘
                                      │ HTTPS
                                      ▼
                    ┌─────────────────────────────────────────┐
                    │  API Gateway REST (regional)  stage: v1  │
                    │  WAF · throttling · request validation   │
                    └─────────────────┬───────────────────────┘
                                      │ VPC Link → NLB NodePort 30080
                                      ▼
                    ┌─────────────────────────────────────────┐
                    │      NLB (framecast-infra) → EKS         │
                    └─────────────────┬───────────────────────┘
                                      │
                           ┌──────────▼────────────┐
                           │         api           │
                           │   (Go/Gin · HTTP)     │
                           │  ┌─────────────────┐  │
                           │  │ static/         │  │── HTML/CSS/JS embutido (embed.FS)
                           │  │ módulo: auth    │  │── JWT HS256, bcrypt, users
                           │  │ módulo: videos  │  │── upload, presign, complete
                           │  │ módulo: status  │  │── list (polling)
                           │  │ módulo: outbox  │  │── dispatcher (goroutine)
                           │  │ shared/         │  │── middleware, db (GORM), errors
                           │  └─────────────────┘  │
                           │  HPA por CPU          │
                           └──────┬────────────────┘
                                  │ publish (outbox dispatcher)
                                  ▼
                           ┌──────────────────┐
                           │     AWS SQS      │
                           │ framecast-       │
                           │  processing      │
                           │ + DLQ            │
                           └────────┬─────────┘
                                    │
                                    ▼
                           ┌──────────────────┐
                           │     worker       │
                           │  (Go + FFmpeg)   │
                           │  S3 ↑↓           │
                           │  SES inline      │
                           │  KEDA SQS        │
                           └──────┬───────────┘
                                  │ updates status
                                  ▼
              ┌──────────────────────┐  ┌──────────────────────────┐
              │      PostgreSQL      │  │           S3             │
              │ users · videos       │  │ framecast-videos-raw     │
              │ outbox_events        │  │ framecast-videos-output  │
              └──────────────────────┘  └──────────────────────────┘
```

**Sem Redis:** logout/invalidação de token é feita por coluna `token_invalidated_at` no Postgres. Sem cache externo nem denylist.

**Dev/CI:** S3, SQS e SES rodam em **LocalStack** (container único). `AWS_ENDPOINT_URL=http://localstack:4566`. API Gateway não sobe em dev — acesso direto à `api` na porta 8080.

---

## 2. Frontend (embutido na `api`)

O frontend é HTML/CSS/JS simples servido diretamente pela `api` via `embed.FS`. Sem processo de build separado, sem repo dedicado, sem CloudFront.

```
api/
└── static/
    ├── index.html      # SPA com 3 views: #auth (login), #dashboard (listagem), #upload (upload multipart)
    ├── app.js          # vanilla JS: navegação de view, fetch wrapper, auth, upload multipart, polling
    └── style.css
```

```go
//go:embed static/*
var staticFiles embed.FS

r.StaticFS("/", http.FS(staticFiles))
```

- Sem framework JS: vanilla `fetch` com polling (SSE removido — ver DIAGNOSTICO P2-7).
- JWT armazenado em `localStorage`; injetado como `Authorization: Bearer` em todas as requisições.
- Upload multipart: `init` → presigned URLs → PUT paralelo no S3 → `complete`.
- Status: polling `GET /api/videos` — 5s enquanto houver vídeo em `PENDING`/`PROCESSING`, 10s quando ocioso. SSE removido (não atravessa o API Gateway REST); token só via header `Authorization`.

---

## 3. Serviços (2 deploys)

| Serviço      | Responsabilidade                                                                                                        | Stack                                                          | Escalabilidade                    |
| ------------ | ----------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- | --------------------------------- |
| **`api`**    | Modular monolith: auth (HS256), videos (multipart S3), status (polling), outbox dispatcher + frontend estático embutido | Go + Gin + GORM + `aws-sdk-go-v2` + `golang-jwt/v5` + Postgres | HPA por CPU                       |
| **`worker`** | Consome `framecast-processing`, FFmpeg, ZIP streaming, S3, e-mail SES inline (best-effort)                              | Go + FFmpeg + `aws-sdk-go-v2` (SQS/S3/SES)                     | KEDA `aws-sqs-queue-length` (0→N) |

---

## 4. Autenticação (JWT HS256)

```
Cliente → POST /api/auth/login
   ▼
api (módulo auth):
   1. Verifica email + bcrypt hash no Postgres
   2. Emite JWT HS256:
        claims: { sub=user_id, email, iat=now, exp=now+24h }
        assinado com JWT_SECRET (env var, ≥ 32 bytes)
   ← { access_token, token_type: "Bearer", expires_in: 86400 }

Cliente → GET /api/videos (Authorization: Bearer <jwt>)
   ▼
api (middleware shared/infra/http/middleware/auth.go):
   1. Extrai Bearer token
   2. Valida assinatura HS256 com JWT_SECRET + exp
   3. Carrega user; rejeita se iat < token_invalidated_at
   4. Injeta user_id no contexto Gin
```

**Por que HS256:** segredo compartilhado entre instâncias da `api` — sem JWKS, sem Lambda Authorizer, sem par RSA. Único serviço emite e valida. `JWT_SECRET` comprometido permite forjar tokens — mitigado por rotação via Secrets Manager.

**Logout / revogação (sem Redis):** `POST /api/auth/logout` executa `UPDATE users SET token_invalidated_at = NOW()`. O middleware rejeita qualquer token cujo `iat` seja anterior a esse timestamp — invalida **todos** os tokens ativos do usuário de uma vez. Custo: uma leitura do usuário por request autenticado (já necessária para o contexto).

---

## 5. Estrutura interna da `api` (Modular Monolith — Clean Architecture)

```
api/
├── cmd/api/main.go
├── static/                              # frontend embutido (embed.FS)
├── internal/
│   ├── core/entities/value_objects/     # email, password (bcrypt)
│   ├── modules/
│   │   ├── auth/
│   │   │   ├── domain/{user,token}/     # entidades + interfaces (Repository, JWTService)
│   │   │   ├── application/usecases/    # register, login, logout
│   │   │   └── infra/{persistence,jwt,http}/
│   │   ├── videos/
│   │   │   ├── domain/video/
│   │   │   ├── application/usecases/    # init/presign/list/complete/abort
│   │   │   └── infra/{persistence,storage,http}/   # storage = wrapper multipart S3
│   │   └── status/
│   │       ├── application/usecases/    # list (cursor), get (presigned)
│   │       └── infra/http/              # handlers (list/get)
│   ├── outbox/                          # Event (GORM) + dispatcher → SQS
│   └── shared/
│       ├── config/                      # leitura centralizada de env (fail-fast)
│       ├── infra/
│       │   ├── database/                # GORM + AutoMigrate
│       │   ├── awsclient/               # factory S3/SQS/SES (endpoint configurável)
│       │   ├── http/middleware/         # auth (HS256), observability
│       │   └── observability/           # slog (JSON) + OTel (OTLP gRPC)
│       ├── httperr/
│       └── utils/                       # Envelope de resposta
└── Dockerfile
```

**Camadas por módulo:** `handler (HTTP) → usecase → repository (interface no domain) → infra/persistence (GORM)`. A entidade de domínio é pura (sem imports de infra).

**Regras:**

1. Módulos não importam `internal/` de outros — comunicação só via interfaces de domínio / adapters.
2. Cada módulo é dono de suas tabelas; `status` faz SELECT em `videos` mas não escreve.
3. Wire-up centralizado em `main.go`: instancia deps + `RegisterRoutes(rg *gin.RouterGroup, ...)` por módulo.
4. **Schema via GORM AutoMigrate** no boot — sem migrations SQL externas.

---

## 6. Fluxo de Upload (S3 Multipart)

> O cliente trafega apenas `video_id`; o servidor resolve `upload_id` + `s3_key` no banco e valida ownership em cada chamada (recurso de outro usuário → **404**).

```
1.  POST /api/videos/upload/init { filename, content_type, size_bytes }
    → valida content_type (allowlist de vídeo, senão 400)
    → valida 0 < size_bytes ≤ MAX_UPLOAD_BYTES (senão 413)
    → s3_key_raw = raw/{user_id}/{video_id}/orig   # derivada do UUID; filename NUNCA entra na key
    → S3.CreateMultipartUpload
    → INSERT videos (status=PENDING, upload_id, s3_key_raw, original_name, content_type, size_bytes)
    ← { video_id, upload_id, s3_key }

2.  POST /api/videos/upload/parts { video_id, part_numbers: [1..N] }
    → PresignUploadPart por parte (TTL ~15min)
    ← { urls: [{ part_number, url, expires_at }] }

3.  PUT <url-parte-N>   (cliente, 3-6 conexões em paralelo)
    S3 ← ETag por parte

4.  [Resume após falha]
    GET /api/videos/upload/{video_id}/parts → S3.ListParts
    ← { parts: [{ part_number, etag, size_bytes }] }
    Cliente pede URLs só das partes faltantes (volta ao passo 2)

5.  POST /api/videos/upload/complete { video_id, parts: [{ part_number, etag }] }
    BEGIN TX
      S3.CompleteMultipartUpload
      UPDATE videos SET status='PROCESSING'
      INSERT INTO outbox_events (event_type='VideoUploaded')
    COMMIT
    → outbox dispatcher → SQS framecast-processing
    ← { video_id, status: 'PROCESSING' }
    # idempotente: se já PROCESSING/DONE, retorna estado atual sem republicar

    [Cancelamento]
    DELETE /api/videos/upload/{video_id}
    → S3.AbortMultipartUpload + DELETE do registro
```

**Tamanho de parte:** 5 MB (até 100 MB) · 10 MB (até 1 GB) · 25 MB (até `MAX_UPLOAD_BYTES`).
**Lifecycle no bucket:** aborta multipart incompleto após 7 dias (regra em `framecast-infra`).

---

## 7. Fluxo do `worker`

```
1.  RECEIVE   SQS.ReceiveMessage(framecast-processing, WaitTime=20s, MaxMessages=1)
              VisibilityTimeout=15min

2.  IDEMPOTÊNCIA + frescor de lease (discrimina por last_heartbeat_at, não por status —
    a api grava PROCESSING já no complete)
              SELECT status, last_heartbeat_at FROM videos WHERE id=$id FOR UPDATE
              - DONE / ERROR → DeleteMessage e sai
              - PROCESSING + heartbeat fresco (< leaseTTL=3min) → worker vivo →
                DeleteMessage (suprime duplicata) e sai
              - PENDING | PROCESSING com heartbeat nulo/velho → adquire lease

3.  LEASE     UPDATE videos SET worker_id=$pod, attempt=attempt+1, last_heartbeat_at=NOW()
              COMMIT

4.  HEARTBEAT goroutine (a cada 1min): ChangeMessageVisibility(+15min)
              + UPDATE videos SET last_heartbeat_at=NOW()  -- renova o lease no banco

5.  DOWNLOAD  S3.GetObject(framecast-videos-raw, s3_key_raw) → /tmp/<id>/input.mp4

6.  FFMPEG    exec.CommandContext(ctx30min, "ffmpeg",
                  "-i", input, "-vf", "fps=1", "-loglevel", "error",
                  "/tmp/<id>/frame_%04d.png")

7.  ZIP+UPLOAD (streaming via io.Pipe — sem materializar ZIP em disco)
              goroutine A: zip.Writer → pipe writer
              goroutine B: S3.PutObject(framecast-videos-output, <id>.zip, pipe reader)

8.  FINALIZAR BEGIN TX
                UPDATE videos SET status='DONE', s3_key_output, frame_count
              COMMIT

8b. E-MAIL    SES.SendEmail("Seu vídeo está pronto") — best-effort
              erro logado mas não bloqueia ACK

9.  ACK       SQS.DeleteMessage
10. CLEANUP   defer os.RemoveAll(tempDir)
```

**Falha no FFmpeg (não-retentável):**

```
→ UPDATE videos SET status='ERROR', error_message
→ SES.SendEmail("Falha no processamento: <motivo>") — best-effort
→ SQS.DeleteMessage
```

### Tratamento de falhas

| Falha                           | Tratamento                                                                |
| ------------------------------- | ------------------------------------------------------------------------- |
| Worker crasha                   | Heartbeat para → visibility expira → SQS reentrega → idempotência protege |
| Download S3 falha               | Não deleta msg → reentrega; após `maxReceiveCount=3` → DLQ                |
| FFmpeg falha (codec/corrompido) | Não-retentável: status=ERROR, e-mail enviado, deleta msg                  |
| Timeout FFmpeg                  | `context.WithTimeout` mata processo → ERROR "timeout"                     |
| Upload ZIP falha                | Retentável: reentrega → refaz do zero                                     |
| SES falha                       | Best-effort: logado, não bloqueia ACK nem reprocessamento                 |
| Mensagem duplicada              | `FOR UPDATE` + check status descarta                                      |

### Recursos e scaling

```yaml
resources:
  requests: { cpu: 500m, memory: 512Mi }
  limits: { cpu: 2, memory: 2Gi }
```

```yaml
# KEDA ScaledObject (framecast-worker/k8s/scaledobject.yaml)
triggers:
  - type: aws-sqs-queue
    authenticationRef:
      name: keda-aws-trigger-auth # Secret com credenciais AWS do worker
    metadata:
      queueURL: <SQS_QUEUE_URL>
      queueLength: "3" # 1 pod adicionado por 3 msgs (visíveis + em processamento)
      awsRegion: <AWS_REGION>
      scaleOnInFlight: "true" # conta msgs invisíveis (em processamento) no cálculo
minReplicaCount: 2 # 2 pods sempre prontos; elimina cold start na demo
maxReplicaCount: 10
pollingInterval: 10 # verifica fila a cada 10s — reage rápido a picos
cooldownPeriod: 60 # aguarda 60s antes de escalar para baixo
```

**Concorrência:** `WORKER_CONCURRENCY=1` (default) — 1 vídeo por pod. Parametrizável via env; paralelismo vem de mais pods via KEDA.

---

## 8. Modelo de Dados (PostgreSQL — GORM AutoMigrate)

> Schema criado e evoluído por **GORM AutoMigrate** no boot da `api`. Sem arquivos SQL. As colunas do worker (`s3_key_output`, `frame_count`, `attempt`, `worker_id`) vivem em `videos` (api é dona do schema).

```sql
users (
  id UUID PK default gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,         -- bcrypt cost 12
  token_invalidated_at TIMESTAMPTZ,    -- logout
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ               -- soft delete (index)
)

videos (
  id UUID PK default gen_random_uuid(),
  user_id UUID FK NOT NULL,
  original_name TEXT NOT NULL,
  content_type TEXT,                   -- nullable até P1-5 (validação no init)
  size_bytes BIGINT,                   -- nullable até P1-5 (validação no init)
  status VARCHAR(20) NOT NULL default 'PENDING',  -- PENDING|PROCESSING|DONE|ERROR
  upload_id TEXT,                      -- multipart S3 em andamento
  s3_key_raw TEXT NOT NULL,
  s3_key_output TEXT,                  -- preenchido pelo worker
  error_message TEXT,
  frame_count INT,                     -- worker
  attempt INT default 0,               -- worker (lease)
  worker_id TEXT,                      -- worker (lease)
  last_heartbeat_at TIMESTAMPTZ,       -- worker (heartbeat; usado pelo lease em P1-6)
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
  deleted_at TIMESTAMPTZ               -- soft delete (gorm.DeletedAt, index); abort usa hard delete (Unscoped)
)

outbox_events (
  id UUID PK default gen_random_uuid(),
  type TEXT NOT NULL,                  -- 'video.process'
  payload TEXT NOT NULL,              -- JSON
  status VARCHAR(20) NOT NULL default 'PENDING',  -- PENDING|PROCESSING|SENT|FAILED|DEAD
  attempts INT default 0,
  last_error TEXT,
  next_retry_at TIMESTAMPTZ,           -- backoff: só elegível para retry após este instante
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ
)
```

**Índices:** `videos(user_id, created_at DESC, id DESC)` (paginação por cursor) · `videos(status)` · `outbox_events(status)`.

**Evento `video.process`** (payload do outbox → SQS):

```json
{
  "video_id": "uuid",
  "user_id": "uuid",
  "s3_key": "raw/{user_id}/{video_id}/orig",
  "bucket": "framecast-videos-raw",
  "output_bucket": "framecast-videos-output"
}
```

---

## 9. Mensageria (AWS SQS)

| Fila                       | Producer       | Consumer          | maxReceiveCount | VisibilityTimeout |
| -------------------------- | -------------- | ----------------- | --------------- | ----------------- |
| `framecast-processing`     | `api` (outbox) | `worker`          | 3 → DLQ         | 15 min            |
| `framecast-processing-dlq` | automático     | alarme CloudWatch | —               | 12h               |

Long polling `WaitTimeSeconds=20`. Idempotência por `video_id` (UUID).

**Outbox dispatcher (`api`):** goroutine com ticker (5s) que reivindica (`ClaimBatch`) eventos elegíveis — `PENDING`, `FAILED` com `next_retry_at` vencido, e `PROCESSING` órfão (reaper por `updated_at` > 2min) — marcando-os `PROCESSING`, publica no SQS e marca `SENT`. Em falha, `MarkFailed` aplica backoff exponencial (5s→5min) e, ao atingir `maxAttempts=8`, marca `DEAD` (terminal, para alarme). Em múltiplas réplicas, `SELECT ... FOR UPDATE SKIP LOCKED` evita publicação duplicada.

---

## 10. Armazenamento (S3)

| Bucket                    | Conteúdo          | Lifecycle                                                                                                                                         |
| ------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `framecast-videos-raw`    | Uploads originais | Abort multipart incompleto após 7d. (Delete pós-DONE não é suportado por lifecycle puro — exigiria tag setada pelo worker; ver DIAGNOSTICO P2-11) |
| `framecast-videos-output` | ZIPs gerados      | Delete após 7 dias                                                                                                                                |

Downloads servidos via **presigned GET URL** (TTL 1h) — backend nunca proxia bytes.

**SDK único** (`aws-sdk-go-v2`), endpoint por `AWS_ENDPOINT_URL`:

```go
cfg, _ := config.LoadDefaultConfig(ctx, config.WithRegion("us-east-1"))
s3client := s3.NewFromConfig(cfg, func(o *s3.Options) {
    if ep := os.Getenv("AWS_ENDPOINT_URL"); ep != "" {
        o.BaseEndpoint = aws.String(ep)
        o.UsePathStyle = true   // LocalStack requer path-style
    }
})
```

---

## 11. Segurança

- JWT **HS256**, `exp=24h`; logout invalida via `token_invalidated_at` (sem denylist externa).
- Senhas com **bcrypt** (cost **12**).
- `JWT_SECRET` em `.env` (gitignored) no AWS Academy — nunca no Git. _(Secrets Manager indisponível no LabRole; ver DIAGNOSTICO P2.)_
- **Path traversal eliminado:** a key raw é derivada do `video_id` (UUID) no servidor — `raw/{user_id}/{video_id}/orig`; o `filename` do cliente nunca entra na key.
- **Validação de content_type** de vídeo no `init` (allowlist → 400).
- **Limite de tamanho** validado no `init`: `0 < size_bytes ≤ MAX_UPLOAD_BYTES` (senão **413**) + throttling no API Gateway.
- **WAF** no API Gateway: regras gerenciadas OWASP top 10.
- **AWS Academy (LabRole):** acesso a S3/SQS/SES via `LabRole` anexada aos nodes do EKS — sem IRSA/OIDC (indisponíveis no LabRole). KEDA usa `identityOwner: operator`.

---

## 12. Observabilidade (OpenTelemetry → Datadog)

**Stack:** instrumentação via **OpenTelemetry SDK** exportando OTLP gRPC; o **Datadog Agent** (DaemonSet no EKS / container no docker-compose) recebe OTLP nativamente (v7.33+) e encaminha para o Datadog. Sem dependência de `dd-trace-go`.

### Traces e Métricas

`InitOTel(ctx)` configura `TracerProvider` + `MeterProvider` com exportadores OTLP gRPC para `OTEL_EXPORTER_OTLP_ENDPOINT`. Métricas de negócio via OTel `Meter`:

| Métrica                     | Tipo      | Atributos                   |
| --------------------------- | --------- | --------------------------- |
| `http.request.duration`     | histogram | `route`, `method`, `status` |
| `video.processing.duration` | histogram | `status`                    |
| `video.processed.total`     | counter   | `status:done\|error`        |
| `outbox.pending`            | gauge     | —                           |

### Logs

`log/slog` emite JSON estruturado para stdout → coletado pelo Datadog Agent. `LoggerFromContext(ctx)` enriquece cada log com `dd.trace_id` e `dd.span_id` (lower 64 bits do trace OTel, em decimal) para correlação log↔trace no Datadog.

```yaml
# label no pod/container (autodiscovery de logs)
ad.datadoghq.com/api.logs: '[{"source":"go","service":"framecast-api"}]'
```

Campos em todo log: `service`, `env`, `version`, `dd.trace_id`, `dd.span_id`.

### Monitors / Alertas

| Alerta              | Condição                                                |
| ------------------- | ------------------------------------------------------- |
| DLQ com mensagens   | `sqs.approximate_number_of_messages_visible > 0` na DLQ |
| Alta taxa de erro   | `http.request.errors / http.requests > 5%` por 5min     |
| Processamento lento | `p95(video.processing.duration) > 10min`                |
| Outbox acumulando   | `outbox.pending > 100` por 5min                         |

### Dev local

Datadog Agent no docker-compose com OTLP habilitado (requer `DD_API_KEY`):

```yaml
datadog:
  image: gcr.io/datadoghq/agent:latest
  environment:
    DD_API_KEY: ${DD_API_KEY}
    DD_SITE: datadoghq.com
    DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_GRPC_ENDPOINT: "0.0.0.0:4317"
    DD_LOGS_ENABLED: "true"
    DD_ENV: dev
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
```

Sem `DD_API_KEY` em dev: deixar `OTEL_EXPORTER_OTLP_ENDPOINT` vazio — o `InitOTel` opera em modo no-op e a aplicação roda normalmente.

---

## 13. Testes

| Camada      | Ferramenta            | Escopo                                                     |
| ----------- | --------------------- | ---------------------------------------------------------- |
| Unit        | `testing` + `testify` | value objects, entidades, usecases (mock de Repository/S3) |
| Integration | `testcontainers-go`   | Postgres + LocalStack (S3+SQS+SES) reais                   |
| E2E         | `k6`                  | fluxo upload → download                                    |
| Carga       | `k6`                  | N vídeos paralelos sem perda                               |
| Lint        | `golangci-lint`       | govet, errcheck, gosec                                     |
| Cobertura   | `go test -cover`      | gate CI: **api ≥ 85%** · **worker ≥ 60%**                  |

---

## 14. CI/CD (GitHub Actions — por repositório)

### Pipelines de aplicação (`framecast-api`, `framecast-worker`)

```yaml
jobs:
  lint-test:
    - golangci-lint run
    - go test ./... -race -coverprofile=cover.out
    - govulncheck
    - gate de cobertura ≥ 60%
  build-push:
    needs: lint-test
    - docker buildx (multi-stage)
    - push para GHCR :${{ sha }}
  deploy-dev:
    needs: build-push
    if: branch == 'main'
    - helm upgrade --install <service> --namespace framecast-dev
    - kubectl rollout status
  promote-prod:
    needs: deploy-dev
    if: tag ~ 'v*'
    - helm upgrade ... --namespace framecast-prod  # manual approval
```

**Migrations:** não há job separado — o schema é aplicado por **GORM AutoMigrate** no startup da `api`. (O worker não migra.)

### Pipeline do `framecast-infra`

```yaml
jobs:
  plan:    # em PR
    - terraform fmt -check && tflint && tfsec
    - terraform plan -out=tfplan
    - comenta plan no PR
  apply:   # em merge na main
    environment: prod  # approval gate
    - terraform apply tfplan
```

### Pipeline do `framecast-db`

Mesmo formato do `framecast-infra` com **approval gate mais rigoroso** (2 reviewers; falha se detectar `destroy` em `aws_db_instance` sem flag explícita). Provisiona apenas o RDS — **não** contém migrations.

### Pipeline do `framecast-gateway`

Mesmo formato do `framecast-infra` — Terraform do API Gateway, VPC Link, WAF.

---

## 15. Deploy

**Local (dev):** `docker-compose.yml` em `framecast-infra/deploy/`:

```
postgres · localstack (S3+SQS+SES) · api · worker (Nx) · datadog-agent (opcional)
```

Bootstrap via `localstack/init/ready.d/` (buckets, queues, lifecycle, SES identity).

**Produção (AWS):**

- **EKS** com HPA (`api`) + KEDA (`worker`).
- **API Gateway REST (regional)** + VPC Link → NLB NodePort 30080 → EKS.
- **RDS PostgreSQL 16** (single-AZ, `db.t3.micro` — limite AWS Academy; `rds.force_ssl=0` e `skip_final_snapshot=true` são trade-offs assumidos da demo).
- **S3, SQS, SES** nativos.
- **LabRole** (AWS Academy) para acesso AWS — sem IRSA/OIDC.
- **ACM** (TLS) + **Route 53** (DNS) + **WAF**.

---

## 16. Repositórios (Polyrepo)

| Repositório             | Conteúdo                                                                   | Frequência | Blast radius       |
| ----------------------- | -------------------------------------------------------------------------- | ---------- | ------------------ |
| **`framecast-api`**     | Modular monolith Go + frontend estático embutido · Dockerfile · Helm chart | Diária     | Deploy api         |
| **`framecast-worker`**  | Consumer SQS + FFmpeg + SES inline · Dockerfile · Helm chart               | Diária     | Deploy worker      |
| **`framecast-gateway`** | Terraform API Gateway · VPC Link · WAF                                     | Mensal     | Edge routing       |
| **`framecast-infra`**   | Terraform EKS/VPC/S3/SQS/SES/ACM · docker-compose dev                      | Semanal    | Infra AWS          |
| **`framecast-db`**      | Terraform RDS + subnet/SG/backup                                           | Rarissíma  | **Perda de dados** |

### Contrato entre repos (Terraform remote state + GitHub secrets)

Não há SSM Parameter Store. Os repos consumidores leem os outputs uns dos outros via
**`terraform_remote_state`** (bucket S3 `fiap-soat-tf-backend-framecast`), e os segredos de
app (ex.: `DB_PASSWORD`) vêm de **GitHub Actions secrets**, montados no `deploy.yml`.

| Origem (remote state key)           | Output consumido                                | Consumidor                                       |
| ----------------------------------- | ----------------------------------------------- | ------------------------------------------------ |
| `framecast/db/terraform.tfstate`    | `rds_address`, `rds_username`                   | `framecast-api`, `framecast-worker` (via deploy) |
| `framecast/infra/terraform.tfstate` | `nlb_arn`, sqs/url, buckets, `cluster-name`, SG | `framecast-gateway`, `framecast-db`, CI/CD       |
| GitHub secret                       | `DB_PASSWORD` (monta `DATABASE_URL`)            | `framecast-api`, `framecast-worker`              |

> **Restrição AWS Academy:** sem SSM/Secrets Manager — o LabRole não garante acesso; o contrato é remote state + GitHub secrets.

### Ordem de bootstrap

1. `framecast-infra` apply → cria EKS/NLB/S3/SQS/SES/KEDA, expõe outputs no remote state (`framecast/infra/terraform.tfstate`)
2. `framecast-db` apply → lê SGs do EKS via remote state do infra; cria RDS, expõe `rds_address` no remote state (`framecast/db/terraform.tfstate`)
3. `framecast-gateway` apply → lê remote state do infra; cria API Gateway + VPC Link + WAF
4. `framecast-api` / `framecast-worker` deploy → `deploy.yml` monta env a partir dos remote states + GitHub secrets; `api` migra schema via AutoMigrate no startup

---

## 17. Mapeamento Requisito → Solução

| Requisito                                  | Como é atendido                                                      |
| ------------------------------------------ | -------------------------------------------------------------------- |
| Processar mais de um vídeo simultaneamente | N réplicas do `worker` consumindo a mesma fila SQS                   |
| Não perder requisição em picos             | SQS durável + DLQ + outbox pattern; KEDA escala workers pela fila    |
| Autenticação                               | JWT **HS256** + bcrypt + invalidação por `token_invalidated_at`      |
| Listagem de status por usuário             | módulo `status` com Postgres (paginação por cursor) + polling        |
| Notificação de erro/sucesso                | SES enviado inline pelo `worker` (best-effort)                       |
| Persistência                               | PostgreSQL (metadados, GORM) + S3 (binários)                         |
| Escalabilidade                             | K8s + HPA (api) + KEDA (worker) + stateless                          |
| Testes                                     | Unit + integration (testcontainers) + e2e (k6); gate 60%             |
| CI/CD                                      | GitHub Actions por repositório: lint, test, build, push, Helm deploy |
| Observabilidade                            | OTel SDK (OTLP gRPC) + `log/slog` → Datadog Agent                    |

---
