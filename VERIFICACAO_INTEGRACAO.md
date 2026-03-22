# Verificação de Integração - Infraestrutura

## ✅ Status da Infraestrutura

A infraestrutura está **corretamente configurada** para integração com a aplicação. Não há alterações obrigatórias.

---

## 🔍 Verificações Realizadas

### 1. ✅ Security Groups do RDS

**Status**: Configurado corretamente com 3 regras de ingress:

```hcl
# Regra 1: Do Security Group do EKS (módulo)
resource "aws_vpc_security_group_ingress_rule" "rds_from_eks" {
  referenced_security_group_id = aws_security_group.eks.id
}

# Regra 2: Do CIDR da VPC (permite pods)
resource "aws_vpc_security_group_ingress_rule" "rds_from_vpc" {
  cidr_ipv4 = var.vpc_cidr  # 172.31.0.0/16
}

# Regra 3: Do Cluster Security Group (auto-criado pelo EKS)
resource "aws_vpc_security_group_ingress_rule" "rds_from_eks_cluster_nodes" {
  referenced_security_group_id = module.eks.cluster_security_group_id
}
```

**Resultado**: Pods conseguirão conectar no RDS de 3 formas diferentes.

---

### 2. ✅ Outputs do Terraform

**Status**: Todos os outputs necessários estão expostos:

```hcl
output "eks_cluster_name"           # ✅ Usado pelo workflow
output "rds_address"                # ✅ Usado no ConfigMap
output "rds_port"                   # ✅ Usado no ConfigMap
output "rds_database_name"          # ✅ Usado no ConfigMap
output "rds_username"               # ✅ Usado no ConfigMap
output "cluster_security_group_id"  # ✅ Usado na regra de SG
```

**Resultado**: Workflow consegue obter todos os valores necessários do state.

---

### 3. ✅ EKS Access Configuration

**Status**: Configurado com detecção automática de usuário/role:

```hcl
# Detecta automaticamente quem está executando
data "aws_caller_identity" "current" {}

# Converte assumed-role para role ARN (AWS Academy)
local.caller_arn = local.is_assumed_role ?
  "arn:aws:iam::${account_id}:role/${role_name}" :
  local.raw_caller_arn

# Cria access entry automaticamente
resource "aws_eks_access_entry" "current_caller" {
  principal_arn = local.caller_arn
}
```

**Resultado**: Funciona automaticamente com AWS Academy sem configuração manual.

---

### 4. ✅ RDS Configuration

**Status**: Configurado corretamente como privado:

```hcl
publicly_accessible = false  # ✅ Privado (seguro)
multi_az           = false   # ✅ Custo otimizado
backup_retention   = 1       # ✅ Backup mínimo
skip_final_snapshot = true   # ✅ Facilita destroy
```

**Resultado**: RDS acessível apenas de dentro da VPC (pods do EKS).

---

### 5. ✅ Backend S3

**Status**: Configurado corretamente:

```hcl
backend "s3" {
  bucket = "fiap-soat-tf-backend-bispo-730335587750"
  key    = "fiap/infra/terraform.tfstate"
  region = "us-east-1"
}
```

**Resultado**: Workflow consegue ler o state via `aws s3 cp`.

---

## 🎯 Melhorias Opcionais (Não Obrigatórias)

### Melhoria 1: Adicionar Output para Facilitar Debug

**Arquivo**: `terraform/environments/production/outputs.tf`

Adicionar output com informações de debug:

```hcl
output "debug_info" {
  description = "Informações para debug de conectividade"
  value = {
    rds_security_group_id     = module.security_groups.rds_security_group_id
    eks_security_group_id     = module.security_groups.eks_security_group_id
    cluster_security_group_id = module.eks.cluster_security_group_id
    vpc_cidr                  = data.aws_vpc.main.cidr_block
    subnet_ids                = local.filtered_subnet_ids
  }
}
```

**Benefício**: Facilita troubleshooting de problemas de rede.

---

### Melhoria 2: Adicionar Tags de Integração

**Arquivo**: `terraform/environments/production/locals.tf`

Adicionar tag indicando integração:

```hcl
finops_tags = {
  # ... tags existentes ...

  # Nova tag
  IntegratedWith = "oficina-tech-app"
  DeployMethod   = "github-actions"
}
```

**Benefício**: Facilita identificar recursos relacionados.

---

### Melhoria 3: Validação de Conectividade (Opcional)

**Arquivo**: `terraform/environments/production/main.tf`

Adicionar null_resource para testar conectividade após apply:

```hcl
# Validação de conectividade (opcional)
resource "null_resource" "validate_connectivity" {
  depends_on = [
    module.eks,
    module.rds,
    aws_vpc_security_group_ingress_rule.rds_from_eks_cluster_nodes
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "✅ Infraestrutura criada com sucesso!"
      echo "Cluster EKS: ${module.eks.cluster_name}"
      echo "RDS Endpoint: ${module.rds.db_instance_address}"
      echo ""
      echo "Próximos passos:"
      echo "1. Configure os secrets no GitHub (repo oficina-tech)"
      echo "2. Execute o workflow de deploy"
      echo "3. Monitore: kubectl get pods -n app-oficina-tech -w"
    EOT
  }
}
```

**Benefício**: Mostra mensagem útil após terraform apply.

---

## 📋 Checklist de Verificação

Antes de fazer deploy da aplicação, verifique:

### No Terraform (oficina-tech-infra)

- [x] ✅ Terraform aplicado com sucesso
- [x] ✅ State salvo no S3
- [x] ✅ Outputs disponíveis
- [x] ✅ EKS cluster criado
- [x] ✅ RDS criado e disponível
- [x] ✅ Security Groups configurados
- [x] ✅ Access entries configuradas

### Comandos de Verificação

```bash
cd oficina-tech-infra/terraform/environments/production

# 1. Verificar state
terraform show

# 2. Ver outputs
terraform output

# 3. Verificar cluster EKS
aws eks describe-cluster --name EKS-OFICINA-TECH --region us-east-1

# 4. Verificar RDS
aws rds describe-db-instances --region us-east-1 | grep DBInstanceStatus

# 5. Testar acesso ao cluster
aws eks update-kubeconfig --name EKS-OFICINA-TECH --region us-east-1
kubectl get nodes

# 6. Verificar security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:Project,Values=EKS-OFICINA-TECH" \
  --region us-east-1
```

---

## 🔧 Troubleshooting

### Problema: Pods não conseguem conectar no RDS

**Diagnóstico**:

```bash
# 1. Verificar se as 3 regras de SG existem
terraform state list | grep security_group_ingress_rule

# Deve mostrar:
# - aws_vpc_security_group_ingress_rule.rds_from_eks_cluster_nodes
# - module.security_groups.aws_vpc_security_group_ingress_rule.rds_from_eks
# - module.security_groups.aws_vpc_security_group_ingress_rule.rds_from_vpc

# 2. Ver detalhes das regras
terraform state show aws_vpc_security_group_ingress_rule.rds_from_eks_cluster_nodes
```

**Solução**: Se alguma regra estiver faltando, fazer `terraform apply` novamente.

---

### Problema: Workflow não consegue ler state do S3

**Diagnóstico**:

```bash
# Verificar se state existe
aws s3 ls s3://fiap-soat-tf-backend-bispo-730335587750/fiap/infra/terraform.tfstate

# Verificar permissões
aws s3api get-bucket-policy --bucket fiap-soat-tf-backend-bispo-730335587750
```

**Solução**: Verificar se as credenciais AWS no GitHub Actions têm permissão de leitura no bucket S3.

---

### Problema: Access denied ao cluster EKS

**Diagnóstico**:

```bash
# Ver quem tem acesso
terraform output eks_access_entries

# Ver seu ARN atual
aws sts get-caller-identity
```

**Solução**:

1. Se usar AWS Academy, o ARN muda a cada sessão
2. Fazer `terraform apply` novamente para atualizar access entries
3. Ou adicionar manualmente via `principal_arn` no terraform.tfvars

---

## 🚀 Fluxo Completo de Deploy

```
1. oficina-tech-infra (este repo)
   ├─ terraform init
   ├─ terraform plan
   ├─ terraform apply
   └─ State salvo no S3

2. GitHub Actions (repo oficina-tech)
   ├─ Lê state do S3
   ├─ Extrai outputs (cluster, RDS)
   ├─ Configura kubectl
   ├─ Cria ConfigMap dinâmico
   ├─ Cria Secrets
   └─ Faz deploy dos pods

3. Pods do EKS
   ├─ Leem ConfigMap (DB_HOST, DB_PORT, etc)
   ├─ Leem Secrets (DB_PASSWORD)
   ├─ Conectam no RDS
   └─ Aplicação roda
```

---

## ✅ Conclusão

**Status**: ✅ Infraestrutura está correta e pronta para integração

**Ações necessárias**: Nenhuma alteração obrigatória

**Próximos passos**:

1. Fazer deploy da aplicação (repo oficina-tech)
2. Monitorar pods: `kubectl get pods -n app-oficina-tech -w`
3. Se houver problemas, verificar logs do workflow e dos pods

---

**Data da verificação**: 2024-03-22
**Versão do Terraform**: >= 1.0
**Região AWS**: us-east-1
