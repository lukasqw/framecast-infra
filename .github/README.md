# CI/CD Workflows

## Fluxo geral

```
push to develop (terraform/** ou kubernetes/**)
      │
      ▼
  [release.yml] ──── PR existe? ────► update-pr (sync + changelog)
                          │
                          NO
                          ▼
                     create-pr (versão + branch + draft PR)
                          │
      merge PR to main ◄──┘
              │
              ▼
         [deploy.yml]
              │
              ▼
         deploy job
    (tf-apply + post-check)
              │
              ▼
         finalize tag
```

## Workflows

| Workflow | Trigger | Descrição |
|---|---|---|
| `ci.yml` | PR para `develop`/`main` (paths: terraform/\*\*), push em `develop` | Validate, security scan, terraform plan |
| `release.yml` | Push em `develop` (paths: terraform/\*\*), `workflow_dispatch` | Cria ou atualiza PR de release |
| `deploy.yml` | PR de `release/*` mergeado em `main`, `workflow_dispatch` | Terraform apply, health check, finaliza tag |
| `destroy.yml` | `workflow_dispatch` (confirmação manual) | Terraform destroy |

## Composite Actions

```
.github/actions/
├── ci/
│   ├── tf-validate/    fmt check + terraform init (sem backend) + validate
│   ├── tf-security/    tfsec + checkov + upload SARIF
│   ├── tf-plan/        terraform plan + upload artifact + comentário no PR
│   └── tf-structure/   verifica arquivos obrigatórios e estrutura de módulos
├── release/            ← idêntico ao oficina-tech (copiado sem alterações)
│   ├── create-pr/      Calcula versão (conventional commits), cria branch e draft PR
│   ├── update-pr/      Sincroniza branch de release com develop e atualiza changelog
│   └── finalize-tag/   Cria tag anotada após health check confirmado em produção
└── deploy/
    ├── tf-apply/       init + plan/artifact reuse + show + apply + kubectl overlays
    └── post-check/     Verifica EKS cluster (nodes, pods) + NLB endpoint
```

## Configuração por repositório

Todos os valores específicos são configurados em **Settings → Secrets and Variables → Variables**.
Veja [`variables.env.example`](variables.env.example) para a lista completa.

### Variáveis obrigatórias

| Variável | Descrição |
|---|---|
| `AWS_REGION` | Região AWS |
| `TF_VERSION` | Versão do Terraform (ex: `1.7.0`) |
| `TF_WORKING_DIR` | Caminho do módulo Terraform (ex: `terraform/environments/production`) |
| `K8S_NAMESPACE` | Namespace Kubernetes para o ConfigMap de infra e cleanup |

### Secrets obrigatórios

| Secret | Descrição |
|---|---|
| `AWS_ACCESS_KEY_ID` | Credencial AWS |
| `AWS_SECRET_ACCESS_KEY` | Credencial AWS |
| `AWS_SESSION_TOKEN` | Credencial AWS (sessão temporária) |
| `DB_PASSWORD` | Senha do banco de dados (`TF_VAR_db_password`) |
| `DD_API_KEY` | Datadog API key (`TF_VAR_datadog_api_key`) |
| `DD_APP_KEY` | Datadog App key (`TF_VAR_datadog_app_key`) |
| `DD_API_URL` | Datadog API URL (`TF_VAR_datadog_api_url`) |

## Versionamento

Idêntico ao `oficina-tech` — versão calculada automaticamente via [Conventional Commits](https://www.conventionalcommits.org):

| Padrão de commit | Bump |
|---|---|
| `feat!:` ou `BREAKING CHANGE:` no corpo | `major` |
| `feat:` | `minor` |
| Qualquer outro (`fix:`, `chore:`, `docs:`, …) | `patch` |

## Tag de release

A tag só é criada **após** o health check do NLB confirmar que a infraestrutura está saudável em produção — mesmo padrão do `oficina-tech`.
