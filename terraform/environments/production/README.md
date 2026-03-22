# Ambiente de Produção - Terraform

## 📋 Visão Geral

Este diretório contém a configuração Terraform para o ambiente de produção do projeto EKS Oficina Tech.

## 🔐 Configuração Automática de Acesso ao EKS

Este ambiente está configurado para detectar automaticamente o usuário/role que está executando o Terraform e conceder acesso ao cluster EKS.

### Como Funciona

1. **Detecção Automática**: O Terraform usa `data.aws_caller_identity.current` para obter o ARN do usuário/role atual
2. **EKS Access Entries**: Cria access entries via API moderna da AWS (arquivo `eks-access.tf`)
3. **ConfigMap aws-auth**: Opcionalmente cria o ConfigMap para compatibilidade (arquivo `aws-auth-configmap.tf`)

### Modos de Autenticação

Configure via variável `access_config`:

- `API`: Usa apenas EKS Access Entries (recomendado, mais moderno)
- `CONFIG_MAP`: Usa apenas ConfigMap aws-auth (legado)
- `API_AND_CONFIG_MAP`: Usa ambos (padrão, máxima compatibilidade)

## 🚀 Uso

### 1. Configurar Variáveis

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edite `terraform.tfvars`:

```hcl
# Obrigatório
db_password = "sua_senha_segura"

# Opcional: adicionar usuários extras
additional_users = [
  {
    userarn  = "arn:aws:iam::730335587750:user/developer"
    username = "developer"
    groups   = ["developers"]
  }
]
```

### 2. Inicializar e Aplicar

```bash
terraform init
terraform plan
terraform apply
```

### 3. Verificar Acesso

O Terraform automaticamente:

- Detecta seu usuário: `aws sts get-caller-identity`
- Cria EKS Access Entry com seu ARN
- Aplica ConfigMap aws-auth (se configurado)

Você pode ver quem foi detectado nos outputs:

```bash
terraform output current_caller_info
```

Resultado:

```json
{
  "arn": "arn:aws:iam::730335587750:user/awsstudent",
  "username": "awsstudent",
  "type": "user",
  "account": "730335587750"
}
```

### 4. Configurar kubectl

```bash
aws eks update-kubeconfig --name EKS-OFICINA-TECH --region us-east-1
kubectl get nodes
```

## 📁 Estrutura de Arquivos

```
production/
├── main.tf                    # Recursos principais (EKS, RDS, ALB)
├── eks-access.tf              # EKS Access Entries (API moderna)
├── aws-auth-configmap.tf      # ConfigMap aws-auth (compatibilidade)
├── variables.tf               # Variáveis
├── outputs.tf                 # Outputs
├── locals.tf                  # Valores locais
├── data.tf                    # Data sources (inclui caller_identity)
├── provider.tf                # Providers (AWS + Kubernetes)
├── backend.tf                 # Backend S3
├── versions.tf                # Versões
├── terraform.tfvars.example   # Exemplo de configuração
└── README.md                  # Este arquivo
```

## 🔑 Variáveis Importantes

### Obrigatórias

- `db_password`: Senha do banco de dados RDS

### Acesso ao EKS

- `principal_arn`: ARN do principal (deixe vazio para detecção automática)
- `additional_users`: Lista de usuários extras
- `additional_roles`: Lista de roles extras
- `access_config`: Modo de autenticação (API, CONFIG_MAP, API_AND_CONFIG_MAP)

### Configurações Gerais

- `aws_region`: Região AWS (padrão: us-east-1)
- `project_name`: Nome do projeto (padrão: EKS-OFICINA-TECH)
- `eks_cluster_version`: Versão do Kubernetes (padrão: 1.31)

## 📊 Outputs

Após aplicar, você pode ver os outputs:

```bash
# Ver todos
terraform output

# Ver específico
terraform output eks_cluster_name
terraform output rds_endpoint

# Ver em JSON
terraform output -json

# Ver quem foi detectado
terraform output current_caller_info
```

## 🔄 GitHub Actions

No GitHub Actions, o Terraform detectará automaticamente a role/usuário configurado nos secrets:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-session-token: ${{ secrets.AWS_SESSION_TOKEN }}

- name: Terraform Apply
  run: terraform apply -auto-approve
  # O Terraform detectará automaticamente o usuário/role das credenciais acima
```

## 🚨 Troubleshooting

### Erro: "Unauthorized" ao acessar cluster

**Causa**: Você não tem acesso ao cluster.

**Solução**: Execute `terraform apply` novamente. O Terraform detectará seu usuário atual e concederá acesso.

### Verificar quem tem acesso

```bash
# Via Terraform
terraform output current_caller_info

# Via AWS CLI
aws eks list-access-entries --cluster-name EKS-OFICINA-TECH

# Via kubectl
kubectl get configmap aws-auth -n kube-system -o yaml
```

### AWS Academy - Credenciais Expiradas

Quando as credenciais do AWS Academy expirarem:

1. Atualize as credenciais no `~/.aws/credentials`
2. Execute `terraform apply` novamente
3. O Terraform detectará o novo usuário/role e atualizará o acesso

## 💡 Dicas

1. **Detecção Automática**: Não precisa configurar `principal_arn` manualmente, o Terraform detecta automaticamente
2. **Múltiplos Usuários**: Use `additional_users` para adicionar outros usuários
3. **GitHub Actions**: Funciona automaticamente com as credenciais configuradas nos secrets
4. **Debug**: Use `terraform output current_caller_info` para ver quem foi detectado
5. **Modo Recomendado**: Use `access_config = "API_AND_CONFIG_MAP"` para máxima compatibilidade

## 📚 Referências

- [EKS Access Entries](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
