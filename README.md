# framecast-infra

Infraestrutura AWS do Framecast provisionada via Terraform. Fundação de todo o ecossistema — cluster EKS, NLB, S3, SQS, SES, KEDA, metrics-server e Datadog Agent.

> Topologia, outputs e contratos: [docs/architecture.md](docs/architecture.md)  
> Regras de modificação e fronteiras: [docs/business-rules.md](docs/business-rules.md)  
> Workflows, actions, variáveis e secrets: [.github/README.md](.github/README.md)

---

## O que este repo provisiona

| Recurso | Detalhe |
|---------|---------|
| **EKS** | Cluster `framecast`, K8s 1.31, nodes `t3.medium` (min 1 / desired 2 / max 3) |
| **NLB** | `framecast-nlb` internet-facing, TCP:80 → NodePort 30080 → framecast-api |
| **Security Groups** | Ingress 443 (control plane) + 30080 (NodePort) |
| **SQS** | `framecast-processing` (visibility 900s) + `framecast-processing-dlq` (maxReceiveCount=3) |
| **S3 raw** | `framecast-videos-raw` — SSE-S3, block public, CORS PUT/ETag, lifecycle abort-multipart após 7 dias |
| **S3 output** | `framecast-videos-output` — SSE-S3, block public, lifecycle expiration após 7 dias |
| **SES** | Identidade de remetente para notificações do worker (`enable_ses=true` obrigatório) |
| **KEDA** | Helm `2.15.1` — escala o worker por profundidade da fila SQS |
| **metrics-server** | Helm `3.12.1` — habilita HPA CPU/memória para a api |
| **Datadog Agent** | Helm DaemonSet, OTLP gRPC 4317 (opcional — requer `datadog_api_key`) |
| **Datadog monitors** | 11 monitores + 2 dashboards via provider Terraform (opcional) |

**Não gerenciado aqui:** VPC/subnets (data source), RDS (`framecast-db`), API Gateway/WAF (`framecast-gateway`), Deployments/HPA/ScaledObject das aplicações (repos `framecast-api`/`framecast-worker`).

---

## Ecossistema Framecast

| Repo | O que é |
|------|---------|
| **`framecast-infra`** (este) | Terraform: EKS, NLB, S3, SQS, SES, controllers Helm |
| `framecast-api` | Modular monolith Go: auth, videos, status, outbox + frontend |
| `framecast-worker` | Consumer SQS: FFmpeg + S3 ZIP + SES |
| `framecast-db` | Terraform RDS PostgreSQL (schema via GORM AutoMigrate na api) |
| `framecast-gateway` | Terraform API Gateway + VPC Link + WAF |

---

## EKS

- **Cluster:** `framecast` (Kubernetes 1.31)
- **Autenticação:** `API_AND_CONFIG_MAP` (Access Entries API + ConfigMap)
- **Acesso:** endpoint público + privado; logs de control plane completos
- **IAM:** LabRole da AWS Academy passada via `lab_role`; IRSA não configurado

### Node Group

| Parâmetro | Valor |
|-----------|-------|
| Nome | `framecast` |
| Instance type | `t3.medium` |
| Capacity type | `ON_DEMAND` |
| Disk | 20 GB |
| Min / Desired / Max | 1 / 2 / 3 |

---

## NLB

- **Nome:** `framecast-nlb` (internet-facing, TCP)
- **Listener:** TCP:80 → Target Group NodePort 30080 → framecast-api
- **Health check:** HTTP GET `/health`, intervalo 30s, threshold 3/3
- **Registro:** todos os nós EKS via `aws_autoscaling_attachment` (ASG attachment automático)

---

## SQS

| Fila | Visibility timeout | Retention | DLQ |
|------|--------------------|-----------|-----|
| `framecast-processing` | **900s** (= lease + heartbeat do worker) | 14 dias | `framecast-processing-dlq` (3 tentativas) |
| `framecast-processing-dlq` | — | 14 dias | — |

> `sqs_visibility_timeout` deve sempre casar com `FFMPEG_TIMEOUT_MINUTES` + margem do heartbeat do worker.

---

## S3

| Bucket | Configuração |
|--------|-------------|
| `framecast-videos-raw` | Block public access · SSE-S3 · CORS PUT + ETag · lifecycle: abort incomplete multipart após **7 dias** |
| `framecast-videos-output` | Block public access · SSE-S3 · lifecycle: expiração dos objetos após **7 dias** |

> Os nomes dos buckets são **contratos** — não podem ser alterados sem atualizar `framecast-api` e `framecast-worker`.

---

## SES

```hcl
enable_ses    = true             # false por padrão — LabRole pode não ter permissão ses:*
ses_from_email = "noreply@framecast.app"
```

Com `enable_ses=false` (default), o output `ses_from_identity` retorna o valor de `var.ses_from_email` sem criar a identidade AWS. Útil em AWS Academy onde SES pode estar bloqueado.

---

## Módulos Terraform

```
terraform/modules/
├── eks/              # aws_eks_cluster + aws_eks_node_group
├── nlb/              # aws_lb + target group TCP:30080 + ASG attachment
├── security-groups/  # SG EKS (443 + 30080 ingress, egress livre)
├── s3/               # 2 buckets + SSE-S3 + CORS + lifecycle (abort + expiration)
├── ses/              # aws_ses_email_identity (opcional via enable_ses)
├── keda/             # Helm KEDA 2.15.1 (namespace keda, watchNamespace="")
├── metrics-server/   # Helm metrics-server 3.12.1 (--kubelet-insecure-tls)
├── datadog-agent/    # Helm Datadog DaemonSet (OTLP gRPC 0.0.0.0:4317, useHostPort)
└── datadog/          # 11 monitors + 2 dashboards via provider Datadog
```

---

## Variáveis de destaque

| Variável | Obrigatória | Default | Descrição |
|----------|-------------|---------|-----------|
| `s3_bucket_raw` | **✅** | — | Nome do bucket raw (contrato com api/worker) |
| `s3_bucket_output` | **✅** | — | Nome do bucket output (contrato com api/worker) |
| `environment` | **✅** | — | Tag FinOps |
| `project_name` | — | `framecast` | Prefixo de todos os recursos |
| `eks_cluster_version` | — | `1.31` | Versão do Kubernetes |
| `instance_type` | — | `t3.medium` | Tipo do nó EC2 |
| `sqs_visibility_timeout` | — | `900` | Deve casar com lease+heartbeat do worker |
| `sqs_max_receive_count` | — | `3` | Tentativas antes da DLQ |
| `s3_multipart_abort_days` | — | `7` | Dias para abortar multipart incompleto |
| `enable_ses` | — | `false` | Cria identidade SES (desabilitar no Academy) |
| `ses_from_email` | — | `noreply@framecast.app` | Remetente SES (usado mesmo com enable_ses=false) |
| `enable_keda` | — | — | Instala KEDA via Helm |
| `enable_metrics_server` | — | — | Instala metrics-server via Helm |
| `enable_datadog_agent` | — | — | Instala Datadog Agent DaemonSet |
| `datadog_api_key` | — | `""` | API key Datadog (módulo datadog desativado se vazio) |

---

## Outputs consumidos por outros repos

| Output | Consumidor | Como |
|--------|-----------|------|
| `nlb_dns_name`, `nlb_arn` | `framecast-gateway` | `terraform_remote_state` → VPC Link + API GW |
| `eks_cluster_name/endpoint/ca` | `framecast-api`, `framecast-worker` | CI/CD: `aws eks update-kubeconfig` |
| `vpc_id`, `subnet_ids` | `framecast-db`, `framecast-gateway` | `terraform_remote_state` |
| `eks_cluster_security_group_id` | `framecast-db` | Regra de ingress no RDS SG |
| `sqs_queue_url`, `sqs_queue_arn` | `framecast-api` (outbox), `framecast-worker` (consumer), KEDA ScaledObject | env var / manifest |
| `s3_bucket_raw`, `s3_bucket_output` | `framecast-api`, `framecast-worker` | env var |
| `ses_from_identity` | `framecast-worker` | env var `SES_FROM_EMAIL` |
| `github_secrets_json` | todos os repos | output JSON para setar GitHub Secrets |

---

## Remote State

```hcl
data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = "fiap-soat-tf-backend-framecast"
    key    = "framecast/infra/terraform.tfstate"
    region = "us-east-1"
  }
}
```

**Sem DynamoDB lock** — nunca executar `apply` em paralelo.

---

## Dev local

```bash
# Sobe postgres + localstack (cria buckets, fila, DLQ e identidade SES automaticamente)
docker compose -f docker-compose.dev.yml up postgres localstack -d

# Com Datadog Agent local (OTLP gRPC na porta 4317)
DD_API_KEY=<sua-key> docker compose -f docker-compose.dev.yml --profile datadog up
```

O script `localstack/init.sh` cria automaticamente todos os recursos AWS simulados.

---

## Deploy em dois passos (EKS → Helm)

Os providers Helm e Kubernetes requerem que o cluster EKS já exista. No primeiro deploy:

```bash
cd terraform/environments/production

terraform init \
  -backend-config="bucket=fiap-soat-tf-backend-framecast" \
  -backend-config="region=us-east-1"

# Passo 1: provisionar EKS, NLB, S3, SQS, SES
terraform apply \
  -target=module.security_groups \
  -target=module.eks \
  -target=module.nlb \
  -target=module.s3 \
  -target=module.ses \
  -target=aws_sqs_queue.dlq \
  -target=aws_sqs_queue.processing

# Passo 2: instalar controllers Helm (KEDA, metrics-server, Datadog Agent)
terraform apply
```

Em deploys subsequentes (cluster já existe): `terraform apply` direto.

---

## CI/CD

| Workflow | Gatilho | O que faz |
|----------|---------|-----------|
| `ci.yml` | PR para `develop`/`main`; push em `develop` | tf validate + security scan (tfsec + checkov) + tf plan |
| `deploy.yml` | PR `release/*` mergeado em `main`; `workflow_dispatch` | tf apply → health check (EKS nodes + NLB) → tag + release |
| `release.yml` | Push em `develop`; `workflow_dispatch` | Calcula versão (conventional commits) → cria `release/vX.Y.Z` + draft PR |
| `rollback.yml` | `workflow_dispatch` (versão + ambiente) | Checkout da tag → tf apply → health check; sem nova tag |
| `destroy.yml` | `workflow_dispatch` (confirmação `"DESTROY"`) | tf destroy (Helm state entries primeiro) |

### Secrets necessários

| Secret | Obrigatório | Descrição |
|--------|-------------|-----------|
| `AWS_ACCESS_KEY_ID` | ✅ | Access key da AWS |
| `AWS_SECRET_ACCESS_KEY` | ✅ | Secret key da AWS |
| `AWS_SESSION_TOKEN` | — | Session token (AWS Academy LabRole) |
| `DD_API_KEY` | — | Datadog API key (monitores/dashboards/agent) |
| `DD_APP_KEY` | — | Datadog App key (monitores/dashboards) |

### Variáveis de repositório

| Variável | Default | Descrição |
|----------|---------|-----------|
| `AWS_REGION` | `us-east-1` | Região AWS |
| `TF_VERSION` | `1.7.0` | Versão do Terraform |
| `TF_WORKING_DIR` | `terraform/environments/production` | Diretório raiz Terraform |
| `TF_STATE_BUCKET` | `fiap-soat-tf-backend-framecast` | Bucket S3 do remote state |
| `K8S_NAMESPACE` | `framecast` | Namespace Kubernetes das aplicações |
