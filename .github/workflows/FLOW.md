# 🔄 Fluxo de CI/CD - Diagrama Visual

## Visão Geral do Fluxo

```mermaid
graph TB
    A[Desenvolvedor] -->|git push| B[Branch develop]
    B -->|Trigger| C[CI Workflow]

    C --> D[Validação]
    C --> E[Security Scan]
    C --> F[Terraform Plan]
    C --> H[Tests]

    D --> I{Todos<br/>passaram?}
    E --> I
    F --> I
    H --> I

    I -->|Não| J[❌ Falha no CI]
    I -->|Sim| K[✅ CI Passou]

    K -->|Trigger| L[Release Workflow]

    L --> M{Release<br/>existe?}

    M -->|Não| N[Criar nova<br/>release branch]
    M -->|Sim| O[Mergear develop<br/>na release]

    N --> P[Abrir PR<br/>para main]
    O --> Q[Atualizar PR<br/>existente]

    P --> R[Equipe revisa]
    Q --> R

    R --> S{Aprovado?}

    S -->|Não| T[Solicitar<br/>mudanças]
    S -->|Sim| U[Merge para main]

    T --> B

    U -->|Trigger| V[Deploy Workflow]

    V --> W[Terraform Apply]
    W --> X[Coletar Outputs]
    X --> Y[Update K8s]
    Y --> Z[Notificar API]
    Z --> AA[Health Checks]
    AA --> AB[✅ Deploy Completo]

    style A fill:#e1f5ff
    style B fill:#fff3cd
    style C fill:#d4edda
    style I fill:#f8d7da
    style J fill:#f8d7da
    style K fill:#d4edda
    style L fill:#d1ecf1
    style M fill:#f8d7da
    style R fill:#fff3cd
    style S fill:#f8d7da
    style U fill:#d4edda
    style V fill:#cfe2ff
    style AB fill:#d4edda
```

---

## Fluxo Detalhado do CI

```mermaid
sequenceDiagram
    participant Dev as Desenvolvedor
    participant GH as GitHub
    participant CI as CI Workflow
    participant AWS as AWS
    participant PR as Pull Request

    Dev->>GH: git push develop
    GH->>CI: Trigger CI Workflow

    par Validação
        CI->>CI: terraform fmt -check
        CI->>CI: terraform validate
    and Security Scan
        CI->>CI: tfsec scan
        CI->>CI: checkov scan
    and Terraform Plan
        CI->>AWS: Configure credentials
        CI->>AWS: terraform init
        CI->>AWS: terraform plan
    and Tests
        CI->>CI: Verificar estrutura
        CI->>CI: Validar módulos
    end

    CI->>GH: Upload artifacts
    CI->>PR: Comment with plan
    CI->>PR: Comment with costs
    CI->>GH: Update status ✅
```

---

## Fluxo Detalhado do Release

```mermaid
sequenceDiagram
    participant Dev as develop branch
    participant GH as GitHub
    participant Rel as Release Workflow
    participant PR as Pull Request

    Dev->>GH: Push to develop
    GH->>Rel: Trigger Release Workflow

    Rel->>GH: Buscar PRs abertos

    alt Nenhuma release aberta
        Rel->>GH: Criar release/YYYYMMDD-SHA
        Rel->>GH: Abrir PR para main
        Rel->>PR: Adicionar labels
        Rel->>PR: Adicionar checklist
        Rel->>PR: Solicitar reviewers
        Note over Rel,PR: Nova release criada ✨
    else Release já existe
        Rel->>GH: Checkout release branch
        Rel->>GH: Merge develop
        Rel->>GH: Push changes
        Rel->>PR: Comentar sobre merge
        Note over Rel,PR: Release atualizada 🔄
    else PR foi fechado
        Rel->>GH: Reabrir PR
        Rel->>GH: Merge develop
        Rel->>PR: Comentar sobre reabertura
        Note over Rel,PR: PR reaberto 🔄
    end

    Rel->>GH: Generate summary
```

---

## Fluxo Detalhado do Deploy

```mermaid
sequenceDiagram
    participant Main as main branch
    participant GH as GitHub
    participant Deploy as Deploy Workflow
    participant AWS as AWS
    participant K8s as Kubernetes
    participant API as API Repo

    Main->>GH: Merge to main
    GH->>Deploy: Trigger Deploy Workflow

    Deploy->>AWS: Configure credentials
    Deploy->>AWS: terraform init
    Deploy->>AWS: terraform plan
    Deploy->>AWS: terraform apply

    AWS-->>Deploy: Infrastructure created

    Deploy->>AWS: Get outputs (RDS, EKS, ALB)
    Deploy->>GH: Save outputs as artifact

    Deploy->>K8s: Update kubeconfig
    Deploy->>K8s: Apply resources
    Deploy->>K8s: Update ConfigMap

    Deploy->>API: Repository dispatch
    Note over Deploy,API: Notificar sobre infra

    par Health Checks
        Deploy->>K8s: Check cluster health
        Deploy->>AWS: Check RDS status
        Deploy->>AWS: Check ALB status
    end

    Deploy->>GH: Generate summary ✅
    Deploy->>GH: Update environment URL
```

---

## Estados do Release Branch

```mermaid
stateDiagram-v2
    [*] --> NoRelease: develop atualizado

    NoRelease --> Creating: Workflow triggered
    Creating --> ReleaseOpen: PR criado

    ReleaseOpen --> Reviewing: Equipe revisando
    Reviewing --> Approved: Aprovado
    Reviewing --> ChangesRequested: Mudanças solicitadas

    ChangesRequested --> Updating: develop atualizado
    Updating --> ReleaseOpen: Merge na release

    Approved --> Merging: Merge para main
    Merging --> Deployed: Deploy executado

    Deployed --> [*]

    note right of NoRelease
        Nenhuma release
        branch aberta
    end note

    note right of ReleaseOpen
        PR aberto para main
        Aguardando review
    end note

    note right of Deployed
        Infraestrutura
        em produção
    end note
```

---

## Ciclo de Vida de um Commit

```mermaid
journey
    title Jornada de um Commit até Produção
    section Desenvolvimento
      Escrever código: 5: Dev
      Commit local: 5: Dev
      Push para develop: 5: Dev
    section CI
      Validação: 3: CI
      Security scan: 3: CI
      Terraform plan: 4: CI
      Tests: 3: CI
    section Release
      Criar/atualizar release: 5: Release
      Abrir/atualizar PR: 5: Release
    section Review
      Code review: 3: Team
      Plan review: 4: Team
      Aprovação: 5: Team
    section Deploy
      Merge para main: 5: Team
      Terraform apply: 4: Deploy
      Update K8s: 4: Deploy
      Health checks: 5: Deploy
    section Produção
      Infraestrutura ativa: 5: Prod
      Monitoramento: 4: Ops
```

---

## Decisões do Release Workflow

```mermaid
flowchart TD
    Start([Push para develop]) --> Check{Buscar PRs<br/>de release}

    Check -->|Nenhum encontrado| Create[Criar nova<br/>release branch]
    Check -->|PR aberto| Merge[Mergear develop<br/>na release]
    Check -->|PR fechado| Reopen[Reabrir PR]

    Create --> OpenPR[Abrir PR<br/>para main]
    OpenPR --> AddLabels[Adicionar labels]
    AddLabels --> AddReviewers[Solicitar reviewers]
    AddReviewers --> Done1([✅ Nova release])

    Merge --> Push[Push changes]
    Push --> Comment1[Comentar no PR]
    Comment1 --> Done2([✅ Release atualizada])

    Reopen --> ReopenPR[Reabrir PR]
    ReopenPR --> MergeDev[Mergear develop]
    MergeDev --> Comment2[Comentar no PR]
    Comment2 --> Done3([✅ PR reaberto])

    style Start fill:#e1f5ff
    style Check fill:#fff3cd
    style Create fill:#d4edda
    style Merge fill:#d1ecf1
    style Reopen fill:#f8d7da
    style Done1 fill:#d4edda
    style Done2 fill:#d4edda
    style Done3 fill:#d4edda
```

---

## Integração com API Repository

```mermaid
sequenceDiagram
    participant Infra as Infrastructure Repo
    participant GH as GitHub API
    participant API as API Repo
    participant Deploy as API Deploy Workflow

    Infra->>Infra: Deploy completo
    Infra->>Infra: Coletar outputs

    Infra->>GH: POST /repos/.../dispatches
    Note over Infra,GH: repository_dispatch event

    GH->>API: Trigger event
    Note over GH,API: infrastructure_updated

    API->>Deploy: Start workflow

    Deploy->>Deploy: Ler client_payload
    Deploy->>Deploy: Atualizar configs
    Deploy->>Deploy: Deploy aplicação

    Deploy-->>Infra: ✅ Deploy concluído

    Note over Infra,Deploy: Infraestrutura e aplicação<br/>sincronizadas
```

---

## Timeline de Execução

```mermaid
gantt
    title Timeline Típica de Deploy
    dateFormat  mm:ss
    axisFormat %M:%S

    section CI
    Validação           :00:00, 01:00
    Security Scan       :00:30, 02:00
    Terraform Plan      :01:00, 03:00
    Tests               :01:30, 01:00

    section Release
    Gerenciar Release   :04:00, 00:30
    Criar/Atualizar PR  :04:30, 00:30

    section Review
    Code Review         :05:00, 10:00
    Aprovação           :15:00, 01:00

    section Deploy
    Terraform Apply     :16:00, 05:00
    Update K8s          :21:00, 02:00
    Notificar API       :23:00, 00:30
    Health Checks       :23:30, 01:30
```

---

## Arquitetura dos Workflows

```mermaid
graph LR
    subgraph "CI Workflow"
        CI1[Validate]
        CI2[Security]
        CI3[Plan]
        CI4[Cost]
        CI5[Tests]
        CI6[Summary]

        CI1 --> CI6
        CI2 --> CI6
        CI3 --> CI6
        CI4 --> CI6
        CI5 --> CI6
    end

    subgraph "Release Workflow"
        R1[Manage Release]
        R2[Summary]

        R1 --> R2
    end

    subgraph "Deploy Workflow"
        D1[Deploy]
        D2[Notify API]
        D3[Health Check]
        D4[Summary]

        D1 --> D2
        D1 --> D3
        D2 --> D4
        D3 --> D4
    end

    CI6 -.->|Trigger| R1
    R2 -.->|After merge| D1

    style CI1 fill:#d4edda
    style CI2 fill:#f8d7da
    style CI3 fill:#d1ecf1
    style CI5 fill:#e1f5ff
    style CI6 fill:#d4edda

    style R1 fill:#cfe2ff
    style R2 fill:#d4edda

    style D1 fill:#cfe2ff
    style D2 fill:#fff3cd
    style D3 fill:#d1ecf1
    style D4 fill:#d4edda
```

---

## Legenda

- 🟢 **Verde**: Sucesso / Aprovado
- 🟡 **Amarelo**: Em andamento / Aguardando
- 🔵 **Azul**: Informação / Processo
- 🔴 **Vermelho**: Erro / Decisão crítica

---

**Este diagrama é atualizado automaticamente conforme os workflows evoluem.**
