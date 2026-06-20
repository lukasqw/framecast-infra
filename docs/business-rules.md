# Regras de Negócio — framecast-infra

## Responsabilidades deste repo

**Gerenciado aqui:**
- Cluster EKS, node group, security groups, EKS Access Entries
- NLB (NodePort 30080 → framecast-api)
- S3 buckets (raw + output) com CORS, lifecycle e SSE-S3
- SQS fila `framecast-processing` + DLQ
- SES identidade verificada
- Controllers Helm: KEDA, metrics-server, Datadog Agent

**Não gerenciado aqui:**
- VPC/subnets — descobertos via data source (VPC padrão 172.31.0.0/16)
- RDS PostgreSQL — repo `framecast-db` (schema via GORM AutoMigrate na api)
- API Gateway + VPC Link + WAF — repo `framecast-gateway`
- Deployments, Services, HPA, ScaledObject — repos `framecast-api` e `framecast-worker`
- Secrets de aplicação (JWT_SECRET, senhas) — gerenciados nos repos de app

## Contratos de nome (não alterar sem coordenação)

Estes nomes são hardcoded nas envs da api e do worker. Alterar quebra todos os repos:

| Recurso | Nome fixo | Referência |
|---|---|---|
| Fila SQS | `framecast-processing` | PLAN_FRAMECAST_API.md, PLAN_FRAMECAST_WORKER.md |
| DLQ SQS | `framecast-processing-dlq` | PLAN_FRAMECAST_WORKER.md |
| Bucket raw | `framecast-videos-raw` | CLAUDE.md |
| Bucket output | `framecast-videos-output` | CLAUDE.md |
| NodePort api | `30080` | framecast-api/k8s/service.yaml |
| Namespace K8s | `framecast` | todos os repos |

## Regras de modificação

### EKS
- Upgrades de versão: incrementais, uma minor por vez (ex: 1.31 → 1.32)
- Mudança de instance type: requer substituição do node group — planejar janela de manutenção
- Nunca mudar `authentication_mode` sem verificar impacto no aws-auth

### Security Groups
- Nunca remover regras sem verificar impacto no tráfego existente
- A porta 30080 deve sempre estar aberta para o NLB alcançar os nodes

### NLB
- Mudança de porta (30080) afeta `framecast-gateway` — coordenar antes
- Health check path `/health` deve corresponder ao endpoint da api

### SQS visibility timeout
- Deve sempre cobrir `FFMPEG_TIMEOUT_MINUTES` + heartbeat do worker (15min = 900s)
- Alterar aqui requer alterar `FFMPEG_TIMEOUT_MINUTES` no worker também

### S3 CORS
- Manter `AllowedMethods: [PUT]` e `ExposeHeaders: [ETag]` no bucket raw
- Sem isso o upload multipart presigned do browser quebra

### Outputs Terraform
- Nunca renomear outputs existentes — `framecast-db` e `framecast-gateway` dependem dos nomes
- Ao adicionar um output, incluir em `outputs.tf` e documentar em `docs/architecture.md`

### Helm controllers
- KEDA e metrics-server requerem que o cluster EKS já exista (dois passos de apply)
- ScaledObject do worker é definido em `framecast-worker` — não criar aqui
- HPA da api é definida em `framecast-api` — não criar aqui

## IAM e Acesso

- Usa LabRole da AWS Academy para cluster e nodes
- IRSA (OIDC Provider) não configurado — KEDA usa `identityOwner: operator` (herda LabRole do node)
- Acesso ao cluster via EKS Access Entries API (`eks-access.tf`)
- O caller do Terraform recebe `AmazonEKSClusterAdminPolicy` automaticamente
- Acesso humano: `aws eks update-kubeconfig --name framecast --region us-east-1`

## State

- Backend S3: `fiap-soat-tf-backend-framecast`, key `framecast/infra/terraform.tfstate`
- **Sem DynamoDB lock** — nunca executar `apply` em paralelo
- O workflow `deploy.yml` usa `concurrency: group: deploy` para garantir isso no CI

## SES Sandbox

Em contas novas a AWS coloca o SES em modo sandbox — só envia para identidades verificadas.
Para sair do sandbox em produção: solicitar via AWS Support (fora do escopo do hackathon).
