# Contexto de IA — framecast-infra

## O que é este repo

Infraestrutura base do Framecast na AWS. Provisionado via Terraform: cluster EKS, NLB, S3, SQS, SES e controllers Helm (KEDA, metrics-server, Datadog Agent).

**Este repo é a fundação — framecast-db e framecast-gateway consomem seus outputs via remote state S3.**

> Topologia e outputs: [docs/architecture.md](docs/architecture.md)
> Regras de modificação: [docs/business-rules.md](docs/business-rules.md)
> Workflows e secrets: [.github/README.md](.github/README.md)

## Domínio deste repo

- Cluster EKS (`framecast`, K8s 1.31, nodes `t3.medium`)
- NLB `framecast-nlb` → NodePort 30080 (framecast-api)
- Security groups (443 + 30080)
- SQS `framecast-processing` (visibility 900s) + DLQ (maxReceiveCount=3)
- S3 `framecast-videos-raw` (CORS PUT, lifecycle abort-multipart 3d) + `framecast-videos-output`
- SES identidade verificada (`ses_from_email`)
- KEDA, metrics-server, Datadog Agent via Helm

**Não gerenciado aqui:** VPC/subnets (data source), RDS (framecast-db), API Gateway/WAF (framecast-gateway), Deployments/Service/HPA/ScaledObject das aplicações.

## Tecnologias

- **Terraform ≥1.0** — AWS provider `~>5.0`, Helm `~>2.12`, Kubernetes `~>2.30`, Datadog `~>3.0`
- **AWS EKS 1.31**, **NLB**, **S3**, **SQS**, **SES**
- **KEDA 2.15**, **metrics-server 3.12**, **Datadog Agent 3.x**

## Convenções específicas

- Módulos reutilizáveis em `terraform/modules/` — um módulo por serviço AWS ou controller
- Configuração de produção em `terraform/environments/production/`
- Remote state S3: bucket `fiap-soat-tf-backend-framecast`, key `framecast/infra/terraform.tfstate` — **sem DynamoDB lock**, nunca `apply` em paralelo
- Subnets descobertas dinamicamente em `locals.tf` (VPC default 172.31.0.0/16, us-east-1a/b)
- Acesso ao cluster via EKS Access Entries API (`eks-access.tf`); caller automático recebe `AmazonEKSClusterAdminPolicy`
- IAM: usa LabRole da AWS Academy (`local.lab_role_arn`); IRSA não configurado

## Contratos de nome (fixos, não alterar)

Estes nomes são hardcoded no env da api e do worker — alterar aqui quebra os outros repos:

| Contrato | Valor |
|---|---|
| Fila SQS | `framecast-processing` |
| Bucket raw | `framecast-videos-raw` |
| Bucket output | `framecast-videos-output` |
| NodePort api | `30080` |
| Namespace K8s | `framecast` |

## Módulos Terraform disponíveis

| Diretório | Label no main.tf | O que faz |
|---|---|---|
| `modules/eks` | `module.eks` | Cluster + node group |
| `modules/nlb` | `module.nlb` | NLB TCP:80 → NodePort 30080 |
| `modules/security-groups` | `module.security_groups` | SG EKS (443 + 30080) |
| `modules/s3` | `module.s3` | 2 buckets + CORS + lifecycle |
| `modules/ses` | `module.ses` | SES email identity |
| `modules/keda` | `module.keda` (count) | Helm KEDA 2.15.1 |
| `modules/metrics-server` | `module.metrics_server` (count) | Helm metrics-server 3.12.1 |
| `modules/datadog-agent` | `module.datadog_agent` (count) | Helm Datadog DaemonSet |
| `modules/datadog` | `module.datadog` (count) | Monitors + dashboards via provider |

> Módulos `alb-controller`, `alb-controller-role` e `rds` foram removidos — não pertencem a este repo.

## Como a IA deve trabalhar neste repo

- **Ao modificar EKS:** editar `terraform/modules/eks/`; upgrades de versão devem ser incrementais (uma minor por vez)
- **Ao modificar security groups:** editar `terraform/modules/security-groups/`; nunca remover regras sem validar impacto
- **Ao modificar NLB:** mudança de porta afeta `framecast-gateway` — coordenar antes de aplicar
- **Ao adicionar IAM role:** IRSA não configurado (Academy); usar LabRole do node ou `identityOwner: operator` no KEDA
- **Ao adicionar output:** incluir em `outputs.tf`; nunca renomear outputs sem atualizar `framecast-db` e `framecast-gateway`
- **Ao modificar SQS visibility timeout:** deve casar com `FFMPEG_TIMEOUT_MINUTES` + heartbeat do worker (15min); alterar os dois juntos
- **Providers Helm/Kubernetes:** requerem cluster EKS existente — primeiro apply usa `-target=module.eks` (ver README §Deploy em dois passos)
- **Nunca criar recursos de banco ou aplicação aqui** — escopo é rede, armazenamento e orquestração
