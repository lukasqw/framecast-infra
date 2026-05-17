# oficina-tech-infra

Infraestrutura base de toda a plataforma Oficina Tech na AWS, provisionada via Terraform. Este repositório é a fundação — todos os outros repos dependem dos outputs criados aqui via remote state S3.

> Topologia de rede, componentes e outputs: [docs/architecture.md](docs/architecture.md)
> Regras de modificação, segurança e acesso: [docs/business-rules.md](docs/business-rules.md)
> Workflows, actions, variáveis e secrets: [.github/README.md](.github/README.md)

---

## O que este repo provisiona

| Recurso | Detalhes |
|---------|----------|
| Cluster EKS | `EKS-OFICINA-TECH`, Kubernetes 1.31 |
| Node Group | `oficina_tech`, instâncias `t3.medium`, min 1 / desired 2 / max 3 |
| Network Load Balancer | `EKS-OFICINA-TECH-nlb`, internet-facing, TCP |
| Security Group EKS | Ingress 443 e 30080–30083; egress livre |
| SQS Queues | 4 filas para mensageria entre microsserviços |
| VPC / Subnets | Descobertos via data source (VPC padrão `172.31.0.0/16`), filtrados para `us-east-1a` e `us-east-1b` |

**Nao gerenciado aqui:** VPC/subnets/NAT Gateway, banco de dados, API Gateway, deploy da aplicação, aws-auth ConfigMap.

---

## EKS

- **Versão Kubernetes:** 1.31
- **Nome do cluster:** `EKS-OFICINA-TECH`
- **Modo de autenticação:** `API_AND_CONFIG_MAP`
- **Endpoint:** acesso público e privado habilitados (`0.0.0.0/0`)
- **Logs habilitados:** `api`, `audit`, `authenticator`, `controllerManager`, `scheduler`

### Node Group

| Parâmetro | Valor |
|-----------|-------|
| Nome | `oficina_tech` |
| Instance type | `t3.medium` |
| Capacity type | `ON_DEMAND` |
| Disk size | 20 GB |
| Min | 1 |
| Desired | 2 |
| Max | 3 |
| Max unavailable (update) | 1 |

### Acesso ao Cluster

O acesso é gerenciado via EKS Access Entries API (`eks-access.tf`). O caller que executa o Terraform recebe `AmazonEKSClusterAdminPolicy` automaticamente. Um principal adicional pode ser configurado via variável `principal_arn`.

---

## NLB — Network Load Balancer

- **Nome:** `EKS-OFICINA-TECH-nlb`
- **Tipo:** internet-facing (não interno)
- **Protocolo:** TCP (camada 4)
- **Cross-zone load balancing:** desabilitado por padrão
- **Deletion protection:** desabilitada por padrão

### Listeners e Target Groups

| Listener (porta NLB) | Target Group | NodePort | Health Check Path | Microsserviço |
|----------------------|--------------|----------|-------------------|---------------|
| TCP:80 | `EKS-OFICINA-TECH-nlb-tg` | 30080 | `/health` | roteamento principal |
| TCP:30081 | `EKS-OFICINA-TECH-nlb-ms1-tg` | 30081 | `/health` | ms-identity |
| TCP:30082 | `EKS-OFICINA-TECH-nlb-ms2-tg` | 30082 | `/health` | ms-order-service |
| TCP:30083 | `EKS-OFICINA-TECH-nlb-ms3-tg` | 30083 | `/health` | ms-workshop |

Todos os target groups usam `target_type = instance` e registram os nodes do EKS via `aws_autoscaling_attachment`.

**Health check:** HTTP, intervalo 30s, threshold healthy/unhealthy = 3, códigos de sucesso `200-299`, deregistration delay 30s.

---

## Security Groups

### `EKS-OFICINA-TECH-eks-sg` (módulo `security-groups`)

| Direção | Porta(s) | Protocolo | Origem | Finalidade |
|---------|----------|-----------|--------|-----------|
| Ingress | 443 | TCP | `0.0.0.0/0` | HTTPS para o control plane |
| Ingress | 30080–30083 | TCP | `0.0.0.0/0` | NodePorts dos microsserviços via NLB |
| Egress | todos | todos | `0.0.0.0/0` | tráfego de saída livre |

### Regra adicional no cluster SG auto-criado pelo EKS

Criada diretamente em `main.tf` via `aws_vpc_security_group_ingress_rule.eks_cluster_nodeport`:

| Direção | Porta(s) | Protocolo | Origem | Finalidade |
|---------|----------|-----------|--------|-----------|
| Ingress | 30080–30083 | TCP | `0.0.0.0/0` | NLB alcanca NodePorts no cluster SG gerenciado pelo EKS |

---

## SQS

Quatro filas provisionadas diretamente em `main.tf`. Nenhuma DLQ configurada.

| Nome da fila | Direção | Visibility timeout | Retencao |
|---|---|---|---|
| `eks-oficina-tech-customer-deleted` | ms1 publica, ms2 consome | 30s | 86400s (1 dia) |
| `eks-oficina-tech-inventory-op-requested` | ms2 publica, ms3 consome | 30s | 86400s (1 dia) |
| `eks-oficina-tech-inventory-op-succeeded` | ms3 publica, ms2 consome | 30s | 86400s (1 dia) |
| `eks-oficina-tech-inventory-op-failed` | ms3 publica, ms2 consome | 30s | 86400s (1 dia) |

> Os nomes reais seguem o padrao `${lower(var.project_name)}-<sufixo>`. Com `project_name = "EKS-OFICINA-TECH"` o prefixo fica `eks-oficina-tech-`.

---

## IAM

Este repo nao cria roles IAM proprias. Utiliza a `LabRole` da AWS Academy, passada via variavel `lab_role` e resolvida em `locals.tf` como `lab_role_arn`. Essa role e usada tanto para o cluster EKS quanto para os nodes. IRSA (OIDC Provider) nao esta configurado neste repo.

---

## Modulos Terraform

```
terraform/modules/
├── eks/                  # aws_eks_cluster + aws_eks_node_group
├── nlb/                  # aws_lb, aws_lb_listener, aws_lb_target_group, aws_autoscaling_attachment
├── security-groups/      # aws_security_group + regras ingress/egress
├── alb-controller/       # Helm release do AWS Load Balancer Controller (nao instanciado em producao)
├── alb-controller-role/  # IAM role para o ALB Controller via IRSA (nao instanciado em producao)
├── rds/                  # RDS PostgreSQL (deprecated — banco gerenciado pelo repo oficina-tech-db)
└── datadog/              # Monitors e dashboards Datadog (instanciado apenas quando api_key e fornecida)
```

A configuracao de producao fica em `terraform/environments/production/`.

---

## Variaveis Terraform

Arquivo: `terraform/environments/production/variables.tf`

| Variavel | Tipo | Padrao | Descricao |
|---|---|---|---|
| `aws_region` | string | `us-east-1` | Regiao AWS |
| `project_name` | string | `EKS-OFICINA-TECH` | Nome do projeto (prefixo de todos os recursos) |
| `environment` | string | `production` | Ambiente |
| `eks_cluster_version` | string | `1.31` | Versao do Kubernetes |
| `access_config` | string | `API_AND_CONFIG_MAP` | Modo de autenticacao do EKS |
| `node_group` | string | `oficina_tech` | Nome do node group |
| `instance_type` | string | `t3.medium` | Tipo de instancia dos nodes |
| `node_desired_size` | number | `2` | Nodes desejados |
| `node_max_size` | number | `3` | Nodes maximos |
| `node_min_size` | number | `1` | Nodes minimos |
| `lab_role` | string | `""` | ARN da LabRole AWS Academy |
| `principal_arn` | string | `""` | ARN adicional para acesso ao cluster |
| `policy_arn` | string | `arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy` | Policy de acesso ao EKS |
| `additional_users` | list(object) | `[]` | Usuarios IAM adicionais para aws-auth |
| `additional_roles` | list(object) | `[]` | Roles IAM adicionais para aws-auth |
| `datadog_api_key` | string (sensitive) | `""` | API key Datadog (modulo so e instanciado se nao vazio) |
| `datadog_app_key` | string (sensitive) | `""` | App key Datadog |
| `datadog_api_url` | string | `https://api.datadoghq.com/` | URL da API Datadog |
| `cost_center` | string | `engineering` | Tag FinOps — centro de custo |
| `business_unit` | string | `technology` | Tag FinOps — unidade de negocio |
| `owner` | string | `devops-team` | Tag FinOps — responsavel |
| `application` | string | `oficina-tech` | Tag FinOps — aplicacao |
| `microservice` | string | `shared` | Tag FinOps — microsservico |

---

## Outputs Terraform

Arquivo: `terraform/environments/production/outputs.tf`

Estes outputs sao consumidos por outros repos via `terraform_remote_state`. Nunca renomear sem coordenar com `oficina-tech-db` e `oficina-tech-api-gateway`.

| Output | Sensitive | Consumido por | Descricao |
|---|---|---|---|
| `eks_cluster_name` | nao | api-gateway, db | Nome do cluster EKS |
| `eks_cluster_endpoint` | sim | api-gateway | Endpoint do cluster |
| `eks_cluster_arn` | nao | — | ARN do cluster |
| `eks_cluster_certificate_authority` | sim | api-gateway | Certificado CA |
| `eks_cluster_version` | nao | — | Versao do Kubernetes em uso |
| `eks_access_entries` | nao | — | Lista de access entries configuradas |
| `vpc_id` | nao | db, api-gateway | ID da VPC |
| `vpc_cidr_block` | nao | db | CIDR da VPC |
| `subnet_ids` | nao | db, api-gateway | IDs das subnets filtradas |
| `eks_security_group_id` | nao | db | SG do modulo security-groups |
| `eks_cluster_security_group_id` | nao | db | SG auto-criado pelo EKS |
| `nlb_dns_name` | nao | api-gateway | DNS do NLB |
| `nlb_arn` | nao | api-gateway | ARN do NLB |
| `nlb_zone_id` | nao | api-gateway | Zone ID do NLB para Route53 |
| `aws_region` | nao | todos | Regiao AWS |
| `aws_account_id` | nao | — | ID da conta AWS |
| `sqs_customer_deleted_url` | nao | ms1, ms2 | URL da fila customer-deleted |
| `sqs_inventory_op_requested_url` | nao | ms2, ms3 | URL da fila inventory-op-requested |
| `sqs_inventory_op_succeeded_url` | nao | ms2, ms3 | URL da fila inventory-op-succeeded |
| `sqs_inventory_op_failed_url` | nao | ms2, ms3 | URL da fila inventory-op-failed |
| `github_secrets_json` | sim | CI/CD | JSON com todos os valores para GitHub Secrets |
| `current_caller_info` | nao | — | Debug: ARN/usuario que executou o Terraform |
| `aws_auth_configmap_command` | nao | — | Comando para aplicar o ConfigMap aws-auth |

---

## Remote State

```hcl
# terraform/environments/production/backend.tf
terraform {
  backend "s3" {
    key = "fiap/infra/terraform.tfstate"
    # bucket fornecido em runtime via -backend-config ou variavel TF_STATE_BUCKET
    # bucket padrao usado pelo CI: fiap-soat-tf-backend-oficina-tech
  }
}
```

Outros repos consomem este state assim:

```hcl
data "terraform_remote_state" "main" {
  backend = "s3"
  config = {
    bucket = var.tf_state_bucket          # ex: fiap-soat-tf-backend-oficina-tech
    key    = "fiap/infra/terraform.tfstate"
    region = "us-east-1"
  }
}
```

**Sem DynamoDB lock** — nao executar `terraform apply` em paralelo neste repo.

---

## Como fazer deploy

### Pre-requisitos

- Terraform >= 1.7.0
- AWS CLI configurado com credenciais validas
- kubectl >= 1.31
- Acesso de leitura/escrita ao bucket S3 do state

### Deploy manual

```bash
cd terraform/environments/production

# Inicializar backend (informar o bucket S3)
terraform init -backend-config="bucket=fiap-soat-tf-backend-oficina-tech" \
               -backend-config="region=us-east-1"

# Visualizar mudancas
terraform plan -var="db_password=<senha>"

# Aplicar
terraform apply -var="db_password=<senha>"

# Ver outputs
terraform output
```

### Configurar kubectl apos o deploy

```bash
CLUSTER=$(terraform output -raw eks_cluster_name)
aws eks update-kubeconfig --name "$CLUSTER" --region us-east-1
kubectl get nodes
```

---

## CI/CD

O pipeline e composto por 4 workflows:

### `ci.yml` — Validacao (PRs para `develop` e `main`)

Etapas executadas em sequencia:

1. **Validate** — `terraform validate` + verificacao de estrutura de arquivos
2. **Security Scan** (paralelo ao Plan) — tfsec e Checkov; resultado publicado na aba Security
3. **Terraform Plan** (somente em PRs) — executa `terraform plan`, faz upload do artefato `tfplan-<sha>` e posta comentario colapsavel no PR

### `deploy.yml` — Deploy automatizado

Disparado quando um PR `release/*` e mergeado na `main` ou via `workflow_dispatch`.

1. Reusa o artefato `tfplan` gerado no CI (mesmo SHA do commit)
2. Executa `terraform apply -auto-approve tfplan`
3. Executa health check pos-deploy via `kubectl` e HTTP GET em `/health`
4. Cria a tag de release somente apos o health check passar
5. Em `workflow_dispatch`, nao cria nova tag (redeploy de versao existente)

### `release.yml` — Versionamento

Cria PR `release/<versao>` com versao calculada via Conventional Commits (`feat:` → minor, `feat!:` → major, demais → patch).

### `rollback.yml` — Rollback

Redeploya uma tag anterior sem criar nova tag.

#### Secrets necessarios no GitHub

| Secret | Descricao |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access key da AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret key da AWS |
| `AWS_SESSION_TOKEN` | Session token (AWS Academy) |
| `DB_PASSWORD` | Senha do banco (passada como `TF_VAR_db_password`) |
| `DD_API_KEY` | Datadog API key (opcional) |
| `DD_APP_KEY` | Datadog App key (opcional) |

#### Variaveis de repositorio

| Variavel | Padrao | Descricao |
|---|---|---|
| `AWS_REGION` | `us-east-1` | Regiao AWS |
| `TF_VERSION` | `1.7.0` | Versao do Terraform |
| `TF_WORKING_DIR` | `terraform/environments/production` | Diretorio raiz do Terraform |
| `TF_STATE_BUCKET` | `fiap-soat-tf-backend-oficina-tech` | Bucket S3 do state |
| `K8S_NAMESPACE` | `app-oficina-tech` | Namespace Kubernetes |

---

## Nota importante — apply paralelo

Este repositorio **nao usa DynamoDB para lock de state**. Executar `terraform apply` simultaneamente em duas maquinas diferentes causara corrupcao do state. Certifique-se de que apenas um apply esteja em execucao por vez. O workflow `deploy.yml` usa `concurrency: group: deploy` com `cancel-in-progress: false` para garantir isso no CI.
