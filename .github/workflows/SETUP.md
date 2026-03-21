# 🚀 Setup dos Workflows

Este guia ajuda você a configurar os workflows do GitHub Actions para o projeto.

## 📋 Pré-requisitos

- Conta AWS com permissões adequadas
- Repositório no GitHub
- Terraform instalado localmente (para testes)
- GitHub CLI (opcional, mas recomendado)

---

## 🔐 Configuração de Secrets

### 1. Secrets AWS

Acesse: `Settings` → `Secrets and variables` → `Actions` → `New repository secret`

#### AWS_ACCESS_KEY_ID

```
Descrição: Chave de acesso AWS
Onde obter: AWS Console → IAM → Users → Security credentials
Permissões necessárias:
  - EC2 (VPC, Security Groups)
  - RDS (Create, Modify, Delete)
  - EKS (Create, Modify, Delete)
  - ELB (Create, Modify, Delete)
  - IAM (Create roles, policies)
```

#### AWS_SECRET_ACCESS_KEY

```
Descrição: Chave secreta AWS
Onde obter: AWS Console → IAM → Users → Security credentials
Nota: Só é exibida uma vez na criação
```

#### AWS_SESSION_TOKEN (opcional)

```
Descrição: Token de sessão para MFA
Onde obter: Gerado ao fazer login com MFA
Nota: Necessário apenas se sua conta exige MFA
```

### 2. Secrets de Integração

#### API_REPO_TOKEN

```
Descrição: Token para notificar repositório da API
Onde obter: GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
Permissões necessárias:
  - repo (Full control of private repositories)
  - workflow (Update GitHub Action workflows)
Escopo: Deve ter acesso ao repositório oficina-tech-api
```

**Como criar:**

```bash
# Via GitHub CLI
gh auth login --scopes repo,workflow

# Ou via web
# 1. Acesse: https://github.com/settings/tokens
# 2. Clique em "Generate new token (classic)"
# 3. Selecione scopes: repo, workflow
# 4. Copie o token gerado
```

#### API_REPO_OWNER

```
Descrição: Owner do repositório da API
Valor: seu-usuario-github
Exemplo: oficina-tech
```

### 3. Secrets de Custos

#### INFRACOST_API_KEY

```
Descrição: API key do Infracost para estimativa de custos
Onde obter: https://www.infracost.io/
Como obter:
  1. Criar conta em https://www.infracost.io/
  2. Acessar Dashboard
  3. Copiar API key
Nota: Plano gratuito disponível
```

### 3. Secrets de Database (opcional)

#### DB_PASSWORD

```
Descrição: Senha do banco de dados RDS
Valor: Senha forte (mínimo 16 caracteres)
Exemplo: MyS3cur3P@ssw0rd!2026
Nota: Será usada na criação do RDS
```

---

## 🌍 Configuração de Environments

### Production Environment

1. Acesse: `Settings` → `Environments` → `New environment`
2. Nome: `production`
3. Configure:
   - ✅ Required reviewers: Adicione revisores obrigatórios
   - ✅ Wait timer: 0 minutos (ou conforme necessário)
   - ✅ Deployment branches: `main` apenas

### Staging Environment (opcional)

1. Acesse: `Settings` → `Environments` → `New environment`
2. Nome: `staging`
3. Configure conforme necessário

---

## 🔧 Configuração do Terraform Backend

Antes de executar os workflows, configure o backend do Terraform:

### 1. Criar S3 Bucket para State

```bash
# Substitua pelos seus valores
AWS_REGION="us-east-1"
BUCKET_NAME="oficina-tech-terraform-state"
DYNAMODB_TABLE="oficina-tech-terraform-locks"

# Criar bucket
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $AWS_REGION

# Habilitar versionamento
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Habilitar criptografia
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Criar tabela DynamoDB para locks
aws dynamodb create-table \
  --table-name $DYNAMODB_TABLE \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $AWS_REGION
```

### 2. Atualizar backend.tf

Edite `terraform/environments/production/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "oficina-tech-terraform-state"  # Seu bucket
    key            = "production/terraform.tfstate"
    region         = "us-east-1"                      # Sua região
    encrypt        = true
    dynamodb_table = "oficina-tech-terraform-locks"  # Sua tabela
  }
}
```

---

## ✅ Verificação da Configuração

### Checklist de Secrets

Execute este comando para verificar se todos os secrets estão configurados:

```bash
# Listar secrets (não mostra valores)
gh secret list

# Deve mostrar:
# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY
# AWS_SESSION_TOKEN (opcional)
# API_REPO_TOKEN
# API_REPO_OWNER
# INFRACOST_API_KEY
# DB_PASSWORD (opcional)
```

### Teste Local

Antes de executar no GitHub Actions, teste localmente:

```bash
# 1. Configurar AWS CLI
aws configure

# 2. Testar Terraform
cd terraform/environments/production
terraform init
terraform validate
terraform plan

# 3. Verificar formatação
terraform fmt -check -recursive

# 4. Executar security scan (opcional)
docker run --rm -v $(pwd):/src aquasec/tfsec /src
```

---

## 🚀 Primeira Execução

### 1. Criar branch develop

```bash
git checkout -b develop
git push origin develop
```

### 2. Fazer primeira mudança

```bash
# Editar algum arquivo Terraform
git add terraform/
git commit -m "feat: configuração inicial da infraestrutura"
git push origin develop
```

### 3. Verificar CI

- Acesse: `Actions` → `CI - Testes e Validação`
- Aguarde conclusão de todos os jobs
- Verifique se todos passaram ✅

### 4. Verificar Release

- Acesse: `Actions` → `Release - Gerenciamento de Release`
- Verifique se o PR foi criado
- Acesse: `Pull Requests` → Encontre o PR de release

### 5. Aprovar e Mergear

- Revise o Terraform Plan no PR
- Verifique estimativa de custos
- Aprove o PR
- Faça o merge para `main`

### 6. Verificar Deploy

- Acesse: `Actions` → `Deploy - Infraestrutura em Produção`
- Aguarde conclusão
- Verifique o summary com todos os dados

---

## 🔍 Monitoramento

### GitHub Actions

```bash
# Ver runs recentes
gh run list --limit 10

# Ver detalhes de um run
gh run view <run-id>

# Ver logs
gh run view <run-id> --log

# Baixar artefatos
gh run download <run-id>
```

### AWS Console

Após o deploy, verifique:

- **EKS:** https://console.aws.amazon.com/eks/
- **RDS:** https://console.aws.amazon.com/rds/
- **EC2 (ALB):** https://console.aws.amazon.com/ec2/
- **VPC:** https://console.aws.amazon.com/vpc/

---

## 🐛 Troubleshooting Comum

### Erro: "Error: No valid credential sources found"

**Solução:** Verificar se os secrets AWS estão configurados corretamente.

```bash
# Testar credenciais localmente
aws sts get-caller-identity
```

### Erro: "Error: Backend initialization required"

**Solução:** Verificar se o bucket S3 e tabela DynamoDB existem.

```bash
# Verificar bucket
aws s3 ls s3://oficina-tech-terraform-state

# Verificar tabela
aws dynamodb describe-table --table-name oficina-tech-terraform-locks
```

### Erro: "Error: Insufficient permissions"

**Solução:** Adicionar permissões IAM necessárias ao usuário AWS.

Política IAM mínima necessária:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "rds:*",
        "eks:*",
        "elasticloadbalancing:*",
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:PutRolePolicy",
        "s3:*",
        "dynamodb:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### Erro: "Repository dispatch failed"

**Solução:** Verificar se `API_REPO_TOKEN` tem permissões corretas.

```bash
# Testar token
curl -H "Authorization: token $API_REPO_TOKEN" \
  https://api.github.com/user
```

---

## 📚 Próximos Passos

1. ✅ Configurar todos os secrets
2. ✅ Criar environments no GitHub
3. ✅ Configurar backend do Terraform
4. ✅ Fazer primeira execução
5. ✅ Monitorar deploy
6. 📖 Ler documentação dos workflows
7. 🎯 Customizar conforme necessário

---

## 🆘 Suporte

Se encontrar problemas:

1. Verifique os logs do workflow
2. Consulte a documentação no README.md
3. Revise este guia de setup
4. Teste localmente antes de executar no CI/CD

---

**Boa sorte com seu deploy! 🚀**
