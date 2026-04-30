# Arquitetura — oficina-tech-infra

## Visão Geral

Infraestrutura base de toda a plataforma na AWS. Provisionado via Terraform: networking (VPC default), cluster EKS, NLB e configurações de IAM/acesso. Todos os outros repos dependem dos outputs deste repo via remote state.

---

## Diagrama de Rede

```
Internet
    │
    ▼
┌────────────────────────────────────────────────────────────┐
│              AWS Region (us-east-1)                        │
│                                                            │
│  VPC padrão AWS  (172.31.0.0/16)                          │
│                                                            │
│  ┌───────────────────────┐  ┌───────────────────────────┐  │
│  │  Subnet (us-east-1a)  │  │  Subnet (us-east-1b)      │  │
│  │                       │  │                           │  │
│  │  ┌─────────────────┐  │  │  ┌─────────────────────┐  │  │
│  │  │  EKS Node       │  │  │  │  EKS Node           │  │  │
│  │  │  t3.medium      │  │  │  │  t3.medium          │  │  │
│  │  └────────┬────────┘  │  │  └──────────┬──────────┘  │  │
│  └───────────┼───────────┘  └─────────────┼─────────────┘  │
│              │                             │                │
│              └──────────────┬──────────────┘                │
│                             │                               │
│                    ┌────────▼────────┐                      │
│                    │  NLB (Network   │                      │
│                    │  Load Balancer) │                      │
│                    │  Port 80→30080  │                      │
│                    └────────┬────────┘                      │
└─────────────────────────────┼──────────────────────────────┘
                              │
                      API Gateway / Clientes
```

---

## Componentes Principais

### VPC

- **Tipo:** VPC padrão da AWS (não criada por este repo — descoberta via data source)
- **CIDR:** `172.31.0.0/16`
- **Subnets usadas:** descobertas dinamicamente, filtradas para `us-east-1a` e `us-east-1b`
- **Sem criação de:** Internet Gateway, NAT Gateway, Route Tables — usa a infraestrutura existente da VPC padrão

### EKS Cluster

| Parâmetro | Valor |
|-----------|-------|
| Nome | `EKS-OFICINA-TECH` |
| Versão Kubernetes | `1.31` |
| Instance type | `t3.medium` |
| Nodes (min / desired / max) | `1 / 1 / 2` |
| Disk size por node | `20 GB` |
| Capacity type | `ON_DEMAND` |
| Endpoint público | Sim (`0.0.0.0/0`) |
| Endpoint privado | Sim |
| Authentication mode | `API_AND_CONFIG_MAP` |
| Cluster logs habilitados | `api`, `audit`, `authenticator`, `controllerManager`, `scheduler` |

### Network Load Balancer (NLB)

- **Tipo:** público (não interno)
- **Protocolo/Porta listener:** TCP/80
- **Target:** NodePort `30080` nos nodes EKS (protocolo TCP)
- **Target type:** `instance` — registra EC2 diretamente via Auto Scaling Group
- **Health check:** `GET /health` na porta `30080` (HTTP), intervalo 30s, thresholds 3
- **Cross-zone load balancing:** desabilitado
- **IP:** apenas DNS name (sem Elastic IP)
- **Deletion protection:** desabilitada

### Security Group (`eks-sg`)

| Direção | Protocolo | Porta | Origem |
|---------|-----------|-------|--------|
| Entrada | TCP | 443 | `0.0.0.0/0` |
| Entrada | TCP | 30080 | `0.0.0.0/0` |
| Saída | Todos | Todas | `0.0.0.0/0` |

> A mesma regra de entrada na porta `30080` também é adicionada ao security group auto-criado pelo EKS (`cluster_security_group_id`).

### Controllers no EKS

Os módulos Terraform para os controllers existem mas **não são instanciados em produção**:

| Controller | Helm Chart | Versão | Status |
|------------|-----------|--------|--------|
| AWS Load Balancer Controller | `aws-load-balancer-controller` | `1.7.0` | Módulo não instanciado |
| cert-manager | `cert-manager` | `v1.13.0` | Módulo não instanciado |

---

## IAM e Acesso ao Cluster

### Roles

- Cluster EKS e node group usam `arn:aws:iam::<account_id>:role/LabRole` (AWS Academy)
- IRSA (IAM Roles for Service Accounts) **não está configurado** — o OIDC Provider não é criado

### Access Entries (EKS Access API)

Dois access entries são criados automaticamente:

| Entry | Principal | Política |
|-------|-----------|---------|
| `current_caller` | ARN do caller Terraform (auto-detectado) | `AmazonEKSClusterAdminPolicy` |
| `lab_access` (opcional) | `var.principal_arn` (se fornecido) | `AmazonEKSClusterAdminPolicy` |

- **aws-auth ConfigMap:** não criado via Terraform (evita o problema "chicken and egg")
- Acesso humano: `aws eks update-kubeconfig --name EKS-OFICINA-TECH --region us-east-1`

---

## Estrutura do Projeto

```
oficina-tech-infra/
├── terraform/
│   ├── modules/
│   │   ├── eks/                    ← cluster + node group
│   │   ├── nlb/                    ← Network Load Balancer
│   │   ├── security-groups/        ← security groups da VPC
│   │   ├── alb-controller/         ← Helm: AWS LB Controller + cert-manager (não instanciado)
│   │   └── alb-controller-role/    ← IAM role para o ALB Controller via IRSA (não instanciado)
│   └── environments/
│       └── production/
│           ├── main.tf             ← instancia os módulos (eks, nlb, security-groups)
│           ├── data.tf             ← data sources (VPC, subnets, account ID)
│           ├── locals.tf           ← filtro de subnets e conversão de ARN LabRole
│           ├── eks-access.tf       ← access entries do EKS
│           ├── backend.tf          ← remote state S3
│           ├── outputs.tf          ← outputs consumidos por outros repos
│           ├── variables.tf        ← variáveis e defaults
│           └── versions.tf         ← Terraform ≥1.0, AWS ~>5.0, Datadog ~>3.0
└── docs/
```

---

## Remote State S3

| Parâmetro | Valor |
|-----------|-------|
| Bucket | `fiap-soat-tf-backend-bispo-730335587750` |
| Key | `fiap/infra/terraform.tfstate` |
| Region | `us-east-1` |
| DynamoDB lock | não configurado |

---

## Outputs Críticos (consumidos por outros repos)

| Output | Valor | Consumido por |
|--------|-------|--------------|
| `vpc_id` | ID da VPC | `oficina-tech-db` |
| `vpc_cidr_block` | `172.31.0.0/16` | `oficina-tech-db` |
| `subnet_ids` | IDs das subnets em 1a e 1b | `oficina-tech-db` |
| `eks_security_group_id` | ID do SG criado pelo módulo | `oficina-tech-db` |
| `eks_cluster_security_group_id` | ID do SG auto-criado pelo EKS | `oficina-tech-db` |
| `eks_cluster_name` | `EKS-OFICINA-TECH` | CI/CD de `oficina-tech` |
| `eks_cluster_endpoint` | URL do API server (sensitive) | CI/CD de `oficina-tech` |
| `eks_cluster_certificate_authority` | CA do cluster (sensitive) | CI/CD de `oficina-tech` |
| `nlb_dns_name` | DNS do NLB | `oficina-tech-api-gateway` |
| `nlb_arn` | ARN do NLB | `oficina-tech-api-gateway` |
| `github_secrets_json` | JSON com todos os secrets do CI/CD (sensitive) | GitHub Actions |
