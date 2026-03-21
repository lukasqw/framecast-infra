# GitHub Actions Workflows - Infrastructure

Este diretório contém os workflows do GitHub Actions para gerenciar a infraestrutura do Oficina Tech.

## Fluxo de Trabalho

Os workflows seguem o mesmo padrão da aplicação principal:

```
develop → CI → Release → main → Deploy
```

### 1. CI - Validação (terraform-plan.yml)

**Trigger:**

- Pull Requests para `develop` ou `main`
- Push para `develop`

**Ações:**

- Validação de formato Terraform (`terraform fmt`)
- Validação de sintaxe (`terraform validate`)
- Scan de segurança (tfsec, Checkov)
- Geração de plano Terraform
- Estimativa de custos (Infracost)
- Comentário no PR com o plano

**Objetivo:** Garantir que as mudanças de infraestrutura são válidas e seguras antes do merge.

### 2. Release - Criar Branch de Release (terraform-release.yml)

**Trigger:**

- Push para `develop` (automático)
- Manual via `workflow_dispatch`

**Ações:**

1. Cria branch `release/YYYYMMDD-SHA` a partir de `develop`
2. Abre Pull Request para `main`
3. Adiciona checklist de deployment no PR

**Objetivo:** Preparar mudanças de infraestrutura para produção de forma controlada.

### 3. Deploy - Aplicar Infraestrutura (terraform-apply.yml)

**Trigger:**

- Merge para `main` (automático)
- Manual via `workflow_dispatch`

**Ações:**

1. Executa `terraform apply` no ambiente de produção
2. Obtém outputs da infraestrutura (RDS, EKS, ALB)
3. Atualiza recursos Kubernetes
4. Salva outputs como artefatos
5. Notifica repositório da API sobre mudanças

**Objetivo:** Aplicar mudanças de infraestrutura em produção e notificar aplicação.

### 4. Destroy - Destruir Infraestrutura (destroy.yml)

**Trigger:**

- Manual via `workflow_dispatch` (requer confirmação)

**Ações:**

- Destrói toda a infraestrutura Terraform
- Requer aprovação manual
- Usado apenas para ambientes de teste ou descomissionamento

**Objetivo:** Remover infraestrutura quando necessário.

## Estrutura dos Workflows

### terraform-plan.yml (CI)

```yaml
jobs:
  validate: # Validação de formato e sintaxe
  security-scan: # Scan de segurança
  plan: # Geração do plano Terraform
  cost-estimate: # Estimativa de custos
```

### terraform-release.yml (Release)

```yaml
jobs:
  create-release: # Cria branch e PR para main
```

### terraform-apply.yml (Deploy)

```yaml
jobs:
  apply: # Aplica infraestrutura
  notify-api-repo: # Notifica repositório da API
  deployment-summary: # Resumo do deployment
```

## Variáveis de Ambiente

### Secrets Necessários

**AWS:**

- `AWS_ACCESS_KEY_ID`: Chave de acesso AWS
- `AWS_SECRET_ACCESS_KEY`: Chave secreta AWS
- `AWS_SESSION_TOKEN`: Token de sessão (se usar MFA)

**Integração com API:**

- `API_REPO_TOKEN`: Token para notificar repositório da API
- `API_REPO_OWNER`: Owner do repositório da API

**Custos:**

- `INFRACOST_API_KEY`: API key do Infracost

**Email (opcional):**

- `SMTP_HOST`: Servidor SMTP
- `SMTP_PORT`: Porta SMTP
- `SMTP_USERNAME`: Usuário SMTP
- `SMTP_PASSWORD`: Senha SMTP
- `SMTP_FROM`: Email remetente
- `ALERT_EMAIL`: Email para alertas críticos (usado no destroy)

### Variáveis de Ambiente

```yaml
AWS_REGION: us-east-1
TF_VERSION: 1.7.0
NAMESPACE: app-oficina-tech
```

## Ambientes GitHub

### production

- Requer aprovação manual
- Usado no workflow `terraform-apply.yml`
- URL: ALB DNS da infraestrutura

## Artefatos Gerados

### tfplan

- Plano Terraform gerado no CI
- Retenção: 5 dias
- Usado para review antes do apply

### infra-outputs-{environment}

- Outputs da infraestrutura (RDS, EKS, ALB)
- Retenção: 90 dias
- Usado para integração com API

## Integração com Repositório da API

Após o deploy da infraestrutura, o workflow notifica o repositório da API via `repository_dispatch`:

```json
{
  "event_type": "infrastructure_updated",
  "client_payload": {
    "environment": "production",
    "rds_endpoint": "...",
    "alb_dns": "...",
    "eks_cluster": "..."
  }
}
```

Isso aciona o workflow `deploy-dev.yml` no repositório da API para atualizar a aplicação.

## Exemplo de Fluxo Completo

1. **Desenvolvedor faz mudanças em `develop`:**

   ```bash
   git checkout develop
   # Editar arquivos Terraform
   git add terraform/
   git commit -m "feat: add new RDS parameter"
   git push origin develop
   ```

2. **CI executa automaticamente:**
   - Valida Terraform
   - Gera plano
   - Estima custos

3. **Release cria PR automaticamente:**
   - Branch `release/20260318-abc123`
   - PR para `main` com checklist

4. **Equipe revisa e aprova PR:**
   - Review do plano Terraform
   - Verificação de custos
   - Aprovação de segurança

5. **Merge para `main` aciona Deploy:**
   - Terraform apply em produção
   - Atualização de recursos Kubernetes
   - Notificação para API
   - Deploy automático da aplicação

## Troubleshooting

### Terraform Plan falha no CI

- Verificar formato: `terraform fmt -check -recursive`
- Validar sintaxe: `terraform validate`
- Revisar erros de segurança no scan

### Apply falha em produção

- Verificar credenciais AWS
- Confirmar permissões IAM
- Revisar logs do Terraform
- Usar `terraform-apply.yml` manual com `auto_approve: false`

### Notificação da API não funciona

- Verificar `API_REPO_TOKEN` tem permissões corretas
- Confirmar `API_REPO_OWNER` está correto
- Verificar webhook no repositório da API

## Comandos Úteis

### Executar workflow manualmente

```bash
# Release
gh workflow run terraform-release.yml -f version=v1.0.0

# Deploy
gh workflow run terraform-apply.yml -f auto_approve=false -f environment=production

# Destroy
gh workflow run destroy.yml -f confirm=yes
```

### Ver status dos workflows

```bash
gh run list --workflow=terraform-plan.yml
gh run list --workflow=terraform-apply.yml
```

### Baixar artefatos

```bash
gh run download <run-id> -n infra-outputs-production
```

## Segurança

- Todos os workflows usam `permissions` mínimas necessárias
- Secrets nunca são expostos em logs
- Scans de segurança obrigatórios no CI
- Aprovação manual requerida para produção
- Terraform state armazenado em S3 com criptografia

## Monitoramento

- Summaries detalhados no GitHub Actions
- Artefatos salvos para auditoria
- Logs completos disponíveis por 90 dias
