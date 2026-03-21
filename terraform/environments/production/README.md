# Production Environment

Configuração do ambiente de produção usando módulos Terraform.

## Estrutura

- `main.tf` - Configuração principal com chamadas aos módulos
- `variables.tf` - Definição de variáveis
- `outputs.tf` - Outputs do ambiente
- `locals.tf` - Valores locais calculados
- `data.tf` - Data sources (VPC, subnets, etc)
- `provider.tf` - Configuração dos providers
- `backend.tf` - Configuração do backend S3
- `versions.tf` - Versões do Terraform e providers

## Uso

1. Configure as variáveis:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edite terraform.tfvars com seus valores
```

2. Inicialize o Terraform:

```bash
terraform init
```

3. Planeje as mudanças:

```bash
terraform plan
```

4. Aplique a infraestrutura:

```bash
terraform apply
```

## Módulos Utilizados

- `eks` - Cluster EKS e Node Groups
- `rds` - RDS PostgreSQL
- `alb` - Application Load Balancer
- `security-groups` - Security Groups para todos os recursos

## Variáveis Importantes

Ver `variables.tf` para lista completa. Principais:

- `aws_region` - Região AWS (padrão: us-east-1)
- `project_name` - Nome do projeto
- `db_password` - Senha do banco (obrigatória)
- `eks_cluster_version` - Versão do Kubernetes
- `rds_instance_class` - Classe da instância RDS

## Outputs

Ver `outputs.tf` para lista completa. Principais outputs para GitHub Actions:

- `eks_cluster_name`
- `eks_cluster_endpoint`
- `rds_endpoint`
- `alb_dns_name`
- `github_secrets_json` - JSON formatado com todos os secrets
