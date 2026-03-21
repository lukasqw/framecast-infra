# GitHub Actions Workflows - Infrastructure

Este diretório contém os workflows do GitHub Actions para gerenciar a infraestrutura do Oficina Tech.

## 🔄 Fluxo de Trabalho

Os workflows seguem um padrão GitFlow otimizado:

```
develop → CI (testes) → Release (branch + PR) → main → Deploy (produção)
```

## 📋 Workflows

### 1. CI - Testes e Validação (ci.yml)

**Trigger:**

- Pull Requests para `develop` ou `main`
- Push para `develop`

**Jobs:**

1. **Validação Terraform**
   - Verificação de formatação (`terraform fmt`)
   - Validação de sintaxe (`terraform validate`)
   - Inicialização sem backend

2. **Security Scan**
   - tfsec (análise de segurança)
   - Checkov (compliance e best practices)
   - Upload de resultados SARIF para GitHub Security

3. **Terraform Plan**
   - Geração do plano de execução
   - Upload do plano como artefato
   - Comentário automático no PR com o plano

4. **Testes Adicionais**
   - Verificação de estrutura de arquivos
   - Validação de módulos
   - Checagem de arquivos obrigatórios

**Objetivo:** Garantir qualidade, segurança e previsibilidade antes do merge.

---

### 2. Release - Gerenciamento de Release (release.yml)

**Trigger:**

- Push para `develop` (automático)
- Manual via `workflow_dispatch`

**Comportamento Inteligente:**

**Cenário A - Nenhuma release aberta:**

1. Cria nova branch `release/YYYYMMDD-SHA`
2. Abre Pull Request para `main`
3. Adiciona labels e checklist
4. Solicita reviewers

**Cenário B - Release já existe:**

1. Detecta PR de release aberto
2. Mergea `develop` na branch de release existente
3. Adiciona comentário no PR sobre o merge
4. Mantém o mesmo PR (não cria duplicado)

**Cenário C - PR foi fechado:**

1. Reabre o PR automaticamente
2. Adiciona comentário explicando a reabertura
3. Atualiza com novos commits

**Objetivo:** Gerenciar releases de forma inteligente, evitando múltiplos PRs e mantendo histórico organizado.

---

### 3. Deploy - Infraestrutura em Produção (deploy.yml)

**Trigger:**

- Merge para `main` (automático)
- Manual via `workflow_dispatch`

**Jobs:**

1. **Deploy Infraestrutura**
   - Terraform init, plan e apply
   - Coleta de outputs (RDS, EKS, ALB, VPC)
   - Atualização do kubeconfig
   - Aplicação de recursos Kubernetes
   - Atualização de ConfigMaps
   - Upload de outputs como artefato

2. **Verificação Pós-Deploy**
   - Health check do EKS cluster
   - Verificação de status do RDS
   - Teste de conectividade do ALB
   - Validação de pods Kubernetes

3. **Resumo Final**
   - Consolidação de todos os dados
   - URLs importantes (console AWS, aplicação)
   - Status de todos os jobs
   - Próximos passos recomendados

**Objetivo:** Deploy completo e automatizado com verificações de saúde.

---

### 4. Destroy - Destruir Infraestrutura (destroy.yml)

**Trigger:**

- Manual via `workflow_dispatch` (requer confirmação)

**Inputs:**

- `environment`: Ambiente a destruir (staging ou production)
- `confirmation`: Deve digitar "DESTROY" para confirmar
- `reason`: Motivo da destruição (obrigatório)

**Jobs:**

1. **Validar Requisição**
   - Verificar confirmação "DESTROY"
   - Verificar ambiente
   - Criar issue de auditoria
   - Alertas para produção

2. **Backup do State**
   - Backup do Terraform state
   - Lista de recursos
   - Outputs atuais
   - Upload como artefato (90 dias)

3. **Destruir Infraestrutura**
   - Obter informações do cluster EKS
   - Deletar recursos Kubernetes
   - Terraform destroy
   - Verificação da destruição

4. **Atualizar Auditoria**
   - Atualizar issue com resultados
   - Fechar issue se bem-sucedido
   - Links para artefatos

5. **Resumo Final**
   - Status de todos os jobs
   - Informações da destruição
   - Links importantes

**Objetivo:** Destruir infraestrutura de forma segura com backup e auditoria completa.

**Importante:**

- ⚠️ Ação IRREVERSÍVEL
- ✅ Backup automático antes da destruição
- ✅ Issue de auditoria para rastreabilidade
- ✅ Requer environment approval para produção

---

## 🏗️ Estrutura dos Workflows

### ci.yml

```yaml
jobs:
  validate: # Formatação e validação
  security-scan: # tfsec + Checkov
  plan: # Terraform plan
  tests: # Testes estruturais
  ci-summary: # Resumo consolidado
```

### release.yml

```yaml
jobs:
  manage-release: # Gerenciamento inteligente de releases
  release-summary: # Resumo do release
```

### deploy.yml

```yaml
jobs:
  deploy: # Deploy da infraestrutura
  notify-api: # Notificação para API
  post-deploy-check: # Verificações de saúde
  final-summary: # Resumo final completo
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

---

## 🔐 Secrets Necessários

### AWS

- `AWS_ACCESS_KEY_ID`: Chave de acesso AWS
- `AWS_SECRET_ACCESS_KEY`: Chave secreta AWS
- `AWS_SESSION_TOKEN`: Token de sessão (se usar MFA)

### Integração com API

- `API_REPO_TOKEN`: Token para notificar repositório da API (permissões: `repo`, `workflow`)
- `API_REPO_OWNER`: Owner do repositório da API (ex: `seu-usuario`)

### Custos

- `INFRACOST_API_KEY`: API key do Infracost ([obter aqui](https://www.infracost.io/))

### Database (opcional)

- `DB_PASSWORD`: Senha do banco de dados RDS

---

## 🌍 Variáveis de Ambiente

```yaml
AWS_REGION: us-east-1
TF_VERSION: 1.7.0
NAMESPACE: app-oficina-tech
WORKING_DIR: terraform/environments/production
```

---

## 📦 Artefatos Gerados

### tfplan-{sha}

- Plano Terraform gerado no CI
- Retenção: 5 dias
- Usado para review antes do apply

### infra-outputs-{environment}-{sha}

- Outputs da infraestrutura (RDS, EKS, ALB, VPC)
- Retenção: 90 dias
- Formato JSON com todos os dados
- Usado para integração com API

---

## 🔗 Integração com Repositório da API

Após o deploy da infraestrutura, o workflow notifica o repositório da API via `repository_dispatch`:

```json
{
  "event_type": "infrastructure_updated",
  "client_payload": {
    "environment": "production",
    "rds_endpoint": "...",
    "rds_port": "5432",
    "rds_database": "oficina_tech",
    "alb_dns": "...",
    "eks_cluster": "...",
    "deployed_at": "2026-03-21T10:00:00Z",
    "commit_sha": "abc123..."
  }
}
```

Isso aciona automaticamente o workflow de deploy no repositório da API.

---

## 📖 Exemplo de Fluxo Completo

### 1. Desenvolvedor faz mudanças em `develop`

```bash
git checkout develop
# Editar arquivos Terraform
git add terraform/
git commit -m "feat: adicionar novo parâmetro RDS"
git push origin develop
```

### 2. CI executa automaticamente

- ✅ Valida formatação e sintaxe
- 🔒 Executa security scan
- 📋 Gera plano Terraform
- 💰 Estima custos
- 🧪 Executa testes estruturais

### 3. Release cria/atualiza PR automaticamente

**Se não existe release:**

- Cria branch `release/20260321-abc123`
- Abre PR para `main` com checklist

**Se já existe release:**

- Mergea `develop` na branch de release existente
- Atualiza o PR com novos commits

### 4. Equipe revisa e aprova PR

- Review do plano Terraform
- Verificação de custos
- Aprovação de segurança
- Checklist completo

### 5. Merge para `main` aciona Deploy

- 🚀 Terraform apply em produção
- ☸️ Atualização de recursos Kubernetes
- 📢 Notificação para repositório da API
- 🏥 Verificações de saúde
- 📊 Resumo completo com todos os dados

---

## 🛠️ Comandos Úteis

### Executar workflow manualmente

```bash
# CI (não recomendado, executa automaticamente)
gh workflow run ci.yml

# Release
gh workflow run release.yml -f version=v1.0.0

# Deploy
gh workflow run deploy.yml -f environment=production -f auto_approve=true

# Destroy
gh workflow run destroy.yml -f confirm=yes
```

### Ver status dos workflows

```bash
gh run list --workflow=ci.yml
gh run list --workflow=release.yml
gh run list --workflow=deploy.yml
```

### Baixar artefatos

```bash
# Listar runs recentes
gh run list --limit 5

# Baixar outputs da infraestrutura
gh run download <run-id> -n infra-outputs-production-<sha>

# Baixar plano Terraform
gh run download <run-id> -n tfplan-<sha>
```

### Ver logs de um workflow

```bash
gh run view <run-id> --log
```

---

## 🐛 Troubleshooting

### CI falha na validação

```bash
# Verificar formatação localmente
terraform fmt -check -recursive terraform/

# Corrigir formatação
terraform fmt -recursive terraform/

# Validar sintaxe
cd terraform/environments/production
terraform init -backend=false
terraform validate
```

### Security scan encontra problemas

- Revisar relatório SARIF na aba Security
- Corrigir issues críticos e de alta severidade
- Issues de média/baixa podem ser aceitos com justificativa

### Terraform Plan falha

- Verificar credenciais AWS
- Confirmar permissões IAM
- Revisar logs do workflow
- Testar localmente com `terraform plan`

### Deploy falha em produção

- Verificar credenciais AWS
- Confirmar permissões IAM
- Revisar logs do Terraform
- Usar `workflow_dispatch` manual com `auto_approve: false`

### Notificação da API não funciona

- Verificar `API_REPO_TOKEN` tem permissões corretas (`repo`, `workflow`)
- Confirmar `API_REPO_OWNER` está correto
- Verificar se o repositório da API tem workflow configurado para `repository_dispatch`

### Release não cria PR

- Verificar permissões do `GITHUB_TOKEN`
- Confirmar que não há conflitos no merge
- Revisar logs do job `manage-release`

### Múltiplos PRs de release

Isso não deve acontecer com o novo workflow! O sistema detecta PRs existentes e mergea neles ao invés de criar novos.

---

## 🔒 Segurança

- ✅ Todos os workflows usam `permissions` mínimas necessárias
- ✅ Secrets nunca são expostos em logs
- ✅ Scans de segurança obrigatórios no CI
- ✅ Aprovação manual requerida para produção
- ✅ Terraform state armazenado em S3 com criptografia
- ✅ SARIF reports enviados para GitHub Security

---

## 📊 Monitoramento

- Summaries detalhados em cada workflow run
- Artefatos salvos para auditoria (90 dias)
- Logs completos disponíveis por 90 dias
- Notificações automáticas em caso de falha
- Integration com GitHub Security para vulnerabilidades

---

## 🎯 Melhores Práticas

1. **Sempre revise o Terraform Plan** antes de aprovar um PR de release
2. **Corrija issues de segurança** antes do merge
3. **Teste mudanças localmente** quando possível
4. **Use branches feature** para mudanças grandes
5. **Mantenha commits atômicos** e bem descritos
6. **Documente mudanças significativas** no PR

---

## 📚 Recursos Adicionais

- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [tfsec Documentation](https://aquasecurity.github.io/tfsec/)

---

**Última atualização:** 2026-03-21
**Versão dos workflows:** 2.0
