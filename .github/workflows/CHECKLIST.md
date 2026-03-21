# ✅ Checklist de Verificação dos Workflows

Use este checklist para garantir que tudo está configurado corretamente.

---

## 📋 Configuração Inicial

### Secrets do GitHub

- [ ] `AWS_ACCESS_KEY_ID` configurado
- [ ] `AWS_SECRET_ACCESS_KEY` configurado
- [ ] `AWS_SESSION_TOKEN` configurado (se necessário)
- [ ] `DB_PASSWORD` configurado (opcional)

**Como verificar:**

```bash
gh secret list
```

---

### Environments do GitHub

- [ ] Environment `production` criado
- [ ] Reviewers configurados para `production`
- [ ] Deployment branch rule configurado (apenas `main`)
- [ ] Environment `staging` criado (opcional)

**Como verificar:**

```bash
# Via web: Settings → Environments
```

---

### Backend do Terraform

- [ ] Bucket S3 criado para state
- [ ] Versionamento habilitado no bucket
- [ ] Criptografia habilitada no bucket
- [ ] Tabela DynamoDB criada para locks
- [ ] `backend.tf` atualizado com valores corretos

**Como verificar:**

```bash
aws s3 ls s3://oficina-tech-terraform-state
aws dynamodb describe-table --table-name oficina-tech-terraform-locks
```

---

### Permissões IAM

- [ ] Usuário AWS tem permissões EC2
- [ ] Usuário AWS tem permissões RDS
- [ ] Usuário AWS tem permissões EKS
- [ ] Usuário AWS tem permissões ELB
- [ ] Usuário AWS tem permissões IAM (criar roles)
- [ ] Usuário AWS tem permissões S3
- [ ] Usuário AWS tem permissões DynamoDB

**Como verificar:**

```bash
aws sts get-caller-identity
aws iam get-user
```

---

### Estrutura de Branches

- [ ] Branch `main` existe
- [ ] Branch `develop` existe
- [ ] Branch protection rules configuradas para `main`
- [ ] Branch protection rules configuradas para `develop`

**Como verificar:**

```bash
git branch -r
```

---

## 🔄 Verificação dos Workflows

### CI Workflow (ci.yml)

- [ ] Workflow existe em `.github/workflows/ci.yml`
- [ ] Triggers configurados corretamente
- [ ] Jobs de validação funcionando
- [ ] Security scan funcionando
- [ ] Terraform plan funcionando
- [ ] Tests funcionando
- [ ] Comentários no PR funcionando

**Como testar:**

```bash
# Criar PR de teste
git checkout -b test/ci-workflow
echo "# Test" >> README.md
git add README.md
git commit -m "test: CI workflow"
git push origin test/ci-workflow
gh pr create --base develop --title "Test: CI Workflow"

# Verificar execução
gh run list --workflow=ci.yml --limit 1
```

---

### Release Workflow (release.yml)

- [ ] Workflow existe em `.github/workflows/release.yml`
- [ ] Triggers configurados corretamente
- [ ] Criação de release branch funcionando
- [ ] Criação de PR funcionando
- [ ] Merge em release existente funcionando
- [ ] Reabertura de PR funcionando
- [ ] Labels adicionadas corretamente
- [ ] Reviewers solicitados corretamente

**Como testar:**

```bash
# Push para develop
git checkout develop
echo "# Test Release" >> README.md
git add README.md
git commit -m "test: release workflow"
git push origin develop

# Verificar execução
gh run list --workflow=release.yml --limit 1

# Verificar PR criado
gh pr list --base main
```

---

### Deploy Workflow (deploy.yml)

- [ ] Workflow existe em `.github/workflows/deploy.yml`
- [ ] Triggers configurados corretamente
- [ ] Terraform apply funcionando
- [ ] Outputs coletados corretamente
- [ ] Kubernetes resources aplicados
- [ ] ConfigMap atualizado
- [ ] Health checks funcionando
- [ ] Artefatos salvos corretamente
- [ ] Summary gerado corretamente

**Como testar:**

```bash
# Executar manualmente (cuidado: aplica em produção!)
gh workflow run deploy.yml -f environment=staging -f auto_approve=true

# Verificar execução
gh run list --workflow=deploy.yml --limit 1

# Baixar artefatos
gh run download <run-id>
```

---

## 🧪 Testes Locais

### Terraform

- [ ] `terraform fmt` passa
- [ ] `terraform validate` passa
- [ ] `terraform init` funciona
- [ ] `terraform plan` funciona
- [ ] Módulos validados

**Como testar:**

```bash
cd terraform/environments/production
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
```

---

### Security Scan

- [ ] tfsec instalado
- [ ] tfsec passa sem erros críticos
- [ ] Checkov instalado
- [ ] Checkov passa sem erros críticos

**Como testar:**

```bash
cd terraform/environments/production
tfsec .
checkov -d .
```

---

### Cost Estimate

- [ ] Infracost instalado
- [ ] Infracost API key configurada
- [ ] Infracost breakdown funciona

**Como testar:**

```bash
cd terraform/environments/production
infracost breakdown --path .
```

---

## 🔗 Integrações

### Repositório da API

- [ ] Repositório `oficina-tech-api` existe
- [ ] Workflow para `repository_dispatch` configurado
- [ ] Token tem permissões corretas
- [ ] Event type `infrastructure_updated` configurado

**Como testar:**

```bash
# Testar repository dispatch manualmente
curl -X POST \
  -H "Authorization: token $API_REPO_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$API_REPO_OWNER/oficina-tech-api/dispatches \
  -d '{"event_type":"infrastructure_updated","client_payload":{"test":true}}'
```

---

### GitHub Security

- [ ] SARIF uploads funcionando
- [ ] Security tab mostrando resultados
- [ ] Alertas configurados

**Como verificar:**

```bash
# Via web: Security → Code scanning alerts
```

---

## 📊 Monitoramento

### Artefatos

- [ ] Artefatos de plan sendo salvos
- [ ] Artefatos de outputs sendo salvos
- [ ] Retenção configurada corretamente

**Como verificar:**

```bash
gh run list --limit 1
gh run view <run-id>
# Verificar seção "Artifacts"
```

---

### Summaries

- [ ] CI summary gerado
- [ ] Release summary gerado
- [ ] Deploy summary gerado
- [ ] Summaries contêm informações corretas

**Como verificar:**

```bash
gh run view <run-id> --web
# Verificar seção "Summary"
```

---

### Logs

- [ ] Logs detalhados disponíveis
- [ ] Secrets não expostos em logs
- [ ] Erros claramente identificados

**Como verificar:**

```bash
gh run view <run-id> --log
```

---

## 🔒 Segurança

### Secrets

- [ ] Secrets não expostos em logs
- [ ] Secrets não em código
- [ ] Secrets rotacionados regularmente

---

### Permissões

- [ ] Workflows usam permissões mínimas
- [ ] Tokens com escopo limitado
- [ ] Environments com aprovação manual

---

### Scans

- [ ] tfsec executando em todos os PRs
- [ ] Checkov executando em todos os PRs
- [ ] SARIF reports sendo gerados
- [ ] Issues de segurança sendo rastreados

---

## 📚 Documentação

- [ ] README.md atualizado
- [ ] SETUP.md completo
- [ ] FLOW.md com diagramas
- [ ] EXAMPLES.md com exemplos
- [ ] CHECKLIST.md (este arquivo)

---

## 🎯 Fluxo Completo

### Teste End-to-End

- [ ] Criar feature branch
- [ ] Fazer mudança em Terraform
- [ ] Push para feature branch
- [ ] Criar PR para develop
- [ ] CI executa e passa
- [ ] Mergear PR para develop
- [ ] Release workflow cria/atualiza PR
- [ ] Revisar PR de release
- [ ] Aprovar PR de release
- [ ] Mergear PR para main
- [ ] Deploy workflow executa
- [ ] Infraestrutura aplicada
- [ ] API notificada
- [ ] Health checks passam
- [ ] Summary gerado

**Como testar:**

```bash
# 1. Feature branch
git checkout -b feature/test-complete-flow
echo "# Test" >> terraform/environments/production/README.md
git add terraform/
git commit -m "test: fluxo completo"
git push origin feature/test-complete-flow

# 2. Criar PR
gh pr create --base develop --title "Test: Fluxo Completo"

# 3. Aguardar CI
gh run watch

# 4. Mergear PR
gh pr merge --merge

# 5. Aguardar Release
gh run watch

# 6. Verificar PR de release
gh pr list --base main

# 7. Aprovar e mergear PR de release
gh pr review <pr-number> --approve
gh pr merge <pr-number> --merge

# 8. Aguardar Deploy
gh run watch

# 9. Verificar outputs
gh run view <run-id>
```

---

## ✅ Status Final

Após completar todos os itens acima, você deve ter:

- ✅ Workflows configurados e funcionando
- ✅ Secrets e environments configurados
- ✅ Backend do Terraform configurado
- ✅ Permissões IAM corretas
- ✅ Integrações funcionando
- ✅ Monitoramento ativo
- ✅ Segurança validada
- ✅ Documentação completa
- ✅ Fluxo end-to-end testado

---

## 🆘 Troubleshooting

Se algum item falhar, consulte:

1. **SETUP.md** - Guia de configuração
2. **README.md** - Documentação geral
3. **EXAMPLES.md** - Exemplos práticos
4. **Logs do workflow** - `gh run view <run-id> --log`
5. **GitHub Security** - Security tab no repositório

---

## 📅 Manutenção Regular

### Semanal

- [ ] Revisar security alerts
- [ ] Verificar custos estimados
- [ ] Revisar logs de deploy

### Mensal

- [ ] Atualizar dependências
- [ ] Revisar permissões IAM
- [ ] Rotacionar secrets
- [ ] Revisar artefatos antigos

### Trimestral

- [ ] Atualizar versão do Terraform
- [ ] Revisar workflows
- [ ] Atualizar documentação
- [ ] Revisar políticas de segurança

---

**Última atualização:** 2026-03-21
**Versão:** 1.0
