# Arquitetura — framecast-infra

## Visão geral

Este repo provisiona a fundação AWS do Framecast. Os outros repos consomem os outputs via `terraform_remote_state`.

```
                    ┌─────────────────────────────────────────────────────┐
                    │              framecast-infra (este repo)             │
                    │                                                      │
  Browser           │  NLB:80 ──► NodePort 30080 ──► framecast-api (K8s) │
  ───────►  NLB  ───┤                                                      │
                    │  EKS cluster "framecast"  (t3.medium, 1-3 nodes)    │
                    │   ├─ namespace: framecast                            │
                    │   │   ├─ framecast-api  (HPA CPU)                   │
                    │   │   └─ framecast-worker (ScaledObject KEDA/SQS)   │
                    │   ├─ namespace: keda                                 │
                    │   ├─ namespace: kube-system (metrics-server)        │
                    │   └─ namespace: datadog (Agent DaemonSet, opcional) │
                    │                                                      │
                    │  S3: framecast-videos-raw  (upload presigned PUT)   │
                    │  S3: framecast-videos-output (ZIP frames)           │
                    │  SQS: framecast-processing + DLQ                    │
                    │  SES: noreply@framecast.app (notificações worker)   │
                    └─────────────────────────────────────────────────────┘
```

## Fluxo de dados

```
Browser → PUT presigned → S3 raw
       → POST /api/videos/upload/complete → api → outbox → SQS framecast-processing

SQS → worker → GET S3 raw → FFmpeg → ZIP → PUT S3 output
             → UPDATE DB status=DONE
             → SES email (best-effort)
             → DeleteMessage

Browser → GET /api/videos/:id → presigned URL S3 output (TTL 1h)
```

## Topologia de rede

- **VPC:** padrão AWS (172.31.0.0/16) — descoberta via data source
- **Subnets:** us-east-1a e us-east-1b (mínimo 2 AZs para EKS)
- **NLB:** internet-facing, TCP:80 → NodePort 30080

## Security Groups

| SG | Ingress | Egress |
|---|---|---|
| `framecast-eks-sg` (módulo security-groups) | 443 (control plane), 30080 (NLB→NodePort) | tudo |
| Cluster SG auto-criado pelo EKS | 30080 (adicionado via `aws_vpc_security_group_ingress_rule`) | — |

## EKS

| Parâmetro | Valor |
|---|---|
| Nome | `framecast` |
| Versão K8s | `1.31` |
| Instance type | `t3.medium` |
| Nodes (min/desired/max) | `1/1/3` |
| Capacity type | `ON_DEMAND` |
| Authentication mode | `API_AND_CONFIG_MAP` |

## Outputs críticos consumidos por outros repos

| Output | Tipo | Consumidor |
|---|---|---|
| `eks_cluster_name` | string | framecast-api, framecast-worker (deploy) |
| `eks_cluster_endpoint` | string (sensitive) | framecast-api, framecast-worker |
| `eks_cluster_certificate_authority` | string (sensitive) | framecast-api, framecast-worker |
| `eks_cluster_security_group_id` | string | **framecast-db** (SG allowlist para RDS) |
| `vpc_id` | string | framecast-db, framecast-gateway |
| `vpc_cidr_block` | string | framecast-db |
| `subnet_ids` | list(string) | framecast-db, framecast-gateway |
| `nlb_dns_name` | string | **framecast-gateway** (VPC Link) |
| `nlb_arn` | string | framecast-gateway |
| `nlb_zone_id` | string | framecast-gateway |
| `sqs_queue_url` | string | framecast-api (outbox dispatcher) |
| `sqs_queue_arn` | string | framecast-worker (ScaledObject KEDA) |
| `s3_bucket_raw` | string | framecast-api, framecast-worker |
| `s3_bucket_output` | string | framecast-api, framecast-worker |
| `ses_from_identity` | string | framecast-worker |
| `github_secrets_json` | JSON (sensitive) | CI/CD de todos os repos |

> **Nunca renomear outputs** sem coordenar com os repos consumidores.

## Remote state

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

## Módulos

| Módulo | Recursos provisionados |
|---|---|
| `eks` | `aws_eks_cluster` + `aws_eks_node_group` |
| `nlb` | `aws_lb` + target group TCP:30080 + `aws_autoscaling_attachment` |
| `security-groups` | SG EKS + regras 443/30080 |
| `s3` | 2 buckets + public access block + SSE-S3 + CORS + lifecycle |
| `ses` | `aws_ses_email_identity` (+ `aws_ses_domain_identity` opcional) |
| `keda` | Helm release KEDA (namespace `keda`) |
| `metrics-server` | Helm release metrics-server (namespace `kube-system`) |
| `datadog-agent` | Helm release Datadog Agent DaemonSet (OTLP gRPC 4317) |
| `datadog` | Monitors + dashboards Terraform Datadog provider (opcional) |

## Deploy em dois passos

O cluster EKS deve existir antes dos providers Helm/Kubernetes serem configurados:

```bash
# Passo 1: infraestrutura AWS
terraform apply \
  -target=module.security_groups \
  -target=module.eks \
  -target=module.nlb \
  -target=module.s3 \
  -target=module.ses \
  -target=aws_sqs_queue.dlq \
  -target=aws_sqs_queue.processing \
  -target=aws_eks_access_entry.current_caller \
  -target=aws_eks_access_policy_association.current_caller_policy \
  -target=aws_vpc_security_group_ingress_rule.eks_cluster_nodeport

# Passo 2: controllers Helm
terraform apply
```
