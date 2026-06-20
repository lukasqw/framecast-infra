# framecast-infra

Infraestrutura AWS do Framecast provisionada via Terraform. Fundação de todo o ecossistema — cluster EKS, NLB, S3, SQS, SES, KEDA, metrics-server e Datadog Agent.

> Topologia, outputs e contratos: [docs/architecture.md](docs/architecture.md)
> Regras de modificação e fronteiras: [docs/business-rules.md](docs/business-rules.md)
> Workflows, actions, variáveis e secrets: [.github/README.md](.github/README.md)

---

## O que este repo provisiona

| Recurso | Detalhe |
|---|---|
| **EKS** | Cluster `framecast`, K8s 1.31, nodes `t3.medium` (min1/desired2/max3) |
| **NLB** | `framecast-nlb` internet-facing → NodePort 30080 → framecast-api |
| **Security Groups** | Ingress 443 (control plane) + 30080 (NodePort) |
| **SQS** | `framecast-processing` (visibility 900s) + `framecast-processing-dlq` (maxReceiveCount=3) |
| **S3** | `framecast-videos-raw` (CORS + lifecycle abort-multipart) + `framecast-videos-output` |
| **SES** | Identidade verificada para notificações do worker |
| **KEDA** | Helm — escala o worker por `aws-sqs-queue-length` |
| **metrics-server** | Helm — habilita HPA CPU/memória da api |
| **Datadog Agent** | Helm DaemonSet com OTLP gRPC 4317 (opcional) |

**Não gerenciado aqui:** VPC/subnets (data source), RDS (`framecast-db`), API Gateway/WAF (`framecast-gateway`), Deployments/HPA/ScaledObject das aplicações (repos `framecast-api`/`framecast-worker`).

---

## Ecossistema Framecast

| Repo | O que é |
|---|---|
| **`framecast-infra`** (este) | Terraform: EKS, NLB, S3, SQS, SES, controllers Helm |
| `framecast-api` | Modular monolith Go: auth, videos, status, outbox + frontend |
| `framecast-worker` | Consumer SQS: FFmpeg + S3 ZIP + SES |
| `framecast-db` | Terraform RDS PostgreSQL (schema via GORM AutoMigrate na api) |
| `framecast-gateway` | Terraform API Gateway + VPC Link + WAF |

---

## EKS

- **Cluster:** `framecast` (Kubernetes 1.31)
- **Autenticação:** `API_AND_CONFIG_MAP` (Access Entries API + ConfigMap)
- **Acesso público/privado:** ambos habilitados
- **Logs:** api, audit, authenticator, controllerManager, scheduler

### Node Group

| Parâmetro | Valor |
|---|---|
| Nome | `framecast` |
| Instance type | `t3.medium` |
| Capacity type | `ON_DEMAND` |
| Disk | 20 GB |
| Min/Desired/Max | 1 / 2 / 3 |

---

## NLB

- **Nome:** `framecast-nlb` (internet-facing, TCP)
- **Listener:** TCP:80 → Target Group NodePort 30080 → framecast-api
- **Health check:** HTTP GET `/health`, intervalo 30s, threshold 3

---

## SQS

| Fila | Visibility timeout | Retention | DLQ |
|---|---|---|---|
| `framecast-processing` | 900s (= lease worker) | 14 dias | `framecast-processing-dlq` (3 tentativas) |
| `framecast-processing-dlq` | — | 14 dias | — |

---

## S3

| Bucket | Configuração |
|---|---|
| `framecast-videos-raw` | Block public access + SSE-S3 + CORS PUT + lifecycle abort-multipart (3 dias) |
| `framecast-videos-output` | Block public access + SSE-S3 |

---

## IAM

Usa a **LabRole** da AWS Academy (passada via `lab_role`). IRSA não configurado.

---

## Módulos Terraform

```
terraform/modules/
├── eks/                  # aws_eks_cluster + aws_eks_node_group
├── nlb/                  # aws_lb + target group TCP:30080 + ASG attachment
├── security-groups/      # 443 + 30080 ingress, egress livre
├── s3/                   # NOVO — raw + output, CORS, lifecycle, SSE-S3
├── ses/                  # NOVO — aws_ses_email_identity
├── keda/                 # NOVO — Helm KEDA
├── metrics-server/       # NOVO — Helm metrics-server
├── datadog-agent/        # NOVO — Helm Datadog Agent (OTLP gRPC)
└── datadog/              # Monitors + dashboards Terraform (opcional)
```

---

## Variáveis de destaque

| Variável | Default | Descrição |
|---|---|---|
| `project_name` | `framecast` | Prefixo de todos os recursos |
| `s3_bucket_raw` | `framecast-videos-raw` | Nome do bucket raw (contrato com api/worker) |
| `s3_bucket_output` | `framecast-videos-output` | Nome do bucket output |
| `ses_from_email` | `noreply@framecast.app` | Remetente SES |
| `sqs_visibility_timeout` | `900` | Deve casar com lease+heartbeat do worker |
| `enable_keda` | `true` | Instala KEDA |
| `enable_metrics_server` | `true` | Instala metrics-server |
| `enable_datadog_agent` | `false` | Instala Datadog Agent DaemonSet |

---

## Outputs consumidos por outros repos

| Output | Consumidor |
|---|---|
| `eks_cluster_name/endpoint/ca` | framecast-api, framecast-worker (deploy) |
| `nlb_dns_name`, `nlb_arn` | framecast-gateway |
| `vpc_id`, `subnet_ids` | framecast-db, framecast-gateway |
| `eks_cluster_security_group_id` | framecast-db |
| `sqs_queue_url` | framecast-api (outbox dispatcher) |
| `s3_bucket_raw`, `s3_bucket_output` | framecast-api, framecast-worker |
| `ses_from_identity` | framecast-worker |
| `github_secrets_json` | CI/CD de todos os repos |

---

## Remote State

```hcl
# Consumir de outro repo
data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = var.tf_state_bucket          # fiap-soat-tf-backend-framecast
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
DD_API_KEY=sua-key docker compose -f docker-compose.dev.yml --profile datadog up
```

---

## Deploy em dois passos (EKS + Helm)

Os providers Helm e Kubernetes requerem que o cluster EKS já exista:

```bash
cd terraform/environments/production

# Passo 1: provisionar EKS, NLB, S3, SQS, SES
terraform init -backend-config="bucket=fiap-soat-tf-backend-framecast" \
               -backend-config="region=us-east-1"
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

---

## CI/CD

| Workflow | Gatilho | O que faz |
|---|---|---|
| `ci.yml` | PRs para `develop`/`main` | validate + security scan + terraform plan |
| `deploy.yml` | Merge de `release/*` na `main` ou `workflow_dispatch` | terraform apply + health check + tag |
| `release.yml` | `workflow_dispatch` | Cria PR `release/<versão>` via Conventional Commits |
| `rollback.yml` | `workflow_dispatch` + tag | Redeploya versão anterior |
| `destroy.yml` | `workflow_dispatch` (proteção manual) | `terraform destroy` |

### Secrets necessários

| Secret | Descrição |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access key da AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret key da AWS |
| `AWS_SESSION_TOKEN` | Session token (AWS Academy) |
| `DD_API_KEY` | Datadog API key (opcional) |
| `DD_APP_KEY` | Datadog App key (opcional) |

### Variáveis de repositório

| Variável | Default | Descrição |
|---|---|---|
| `AWS_REGION` | `us-east-1` | Região AWS |
| `TF_VERSION` | `1.7.0` | Versão do Terraform |
| `TF_WORKING_DIR` | `terraform/environments/production` | Diretório raiz |
| `TF_STATE_BUCKET` | `fiap-soat-tf-backend-framecast` | Bucket S3 do state |
| `K8S_NAMESPACE` | `framecast` | Namespace Kubernetes |
