# Contexto de IA — oficina-tech-infra

> Leia também o [contexto global](../claude.md) antes de trabalhar neste repo.

## O que é este repo

Infraestrutura base de toda a plataforma Oficina Tech na AWS. Provisionado via Terraform: cluster EKS, security groups, NLB e configurações de acesso IAM.

**Este repo é a fundação — todos os outros repos dependem dos outputs criados aqui via remote state S3.**

> Topologia de rede, componentes e outputs críticos: [docs/architecture.md](docs/architecture.md)
> Regras de modificação, segurança e acesso ao cluster: [docs/business-rules.md](docs/business-rules.md)
> Workflows CI/CD, actions, variáveis e secrets: [.github/README.md](.github/README.md)

## Domínio deste repo

- Cluster EKS (`EKS-OFICINA-TECH`, Kubernetes 1.31, nodes `t3.medium`)
- VPC padrão da AWS — **não criada aqui**, descoberta via data source (`172.31.0.0/16`)
- Network Load Balancer (NLB) — expõe o backend via NodePort `30080`
- Security groups para EKS nodes (portas `443` e `30080`)
- Acesso ao cluster via EKS Access Entries API

**Não gerenciado aqui:** VPC/subnets/NAT Gateway, banco de dados, API Gateway, deploy da aplicação, aws-auth ConfigMap.

> Ver lista completa de responsabilidades: [docs/business-rules.md#responsabilidades](docs/business-rules.md#responsabilidades)

## Tecnologias

- **Terraform ≥1.0** — provisionamento IaC (AWS provider `~>5.0`)
- **AWS EKS** — Kubernetes gerenciado
- **AWS NLB** — load balancer camada 4 (TCP/80 → NodePort 30080)
- **Helm provider `~>2.12`** — disponível nos módulos de controllers (não instanciados em produção)

## Convenções específicas

- Módulos reutilizáveis em `terraform/modules/` (`eks`, `nlb`, `security-groups`, `alb-controller`, `alb-controller-role`)
- Configuração de produção em `terraform/environments/production/`
- Remote state S3: bucket `fiap-soat-tf-backend-bispo-730335587750`, key `fiap/infra/terraform.tfstate` — **sem DynamoDB lock**, evitar `apply` paralelo
- Subnets descobertas dinamicamente em `locals.tf`, filtradas para `us-east-1a` e `us-east-1b`
- Acesso ao cluster via `eks-access.tf` (EKS Access Entries API); o caller Terraform recebe `AmazonEKSClusterAdminPolicy` automaticamente

## Como a IA deve trabalhar neste repo

- **Ao modificar o cluster EKS:** editar `terraform/modules/eks/`; upgrades de versão devem ser incrementais (uma minor por vez) — ver [docs/business-rules.md#regras-de-modificação-da-infraestrutura](docs/business-rules.md#regras-de-modificação-da-infraestrutura)
- **Ao modificar security groups:** editar `terraform/modules/security-groups/`; nunca remover regras sem validar impacto no tráfego
- **Ao modificar o NLB:** mudança de porta afeta `oficina-tech-api-gateway` — coordenar antes de aplicar
- **Ao adicionar IAM role para workload:** IRSA não está configurado (OIDC Provider não criado); para ativar controllers ver [docs/business-rules.md#controllers](docs/business-rules.md#controllers)
- **Ao adicionar um output:** incluir em `terraform/environments/production/outputs.tf`; nunca renomear outputs existentes sem atualizar todos os repos consumidores — ver [docs/architecture.md#outputs-críticos-consumidos-por-outros-repos](docs/architecture.md#outputs-críticos-consumidos-por-outros-repos)
- **Nunca criar recursos de banco ou aplicação aqui** — escopo é rede e orquestração
- Secrets sensíveis (`DB_PASSWORD`, `JWT_SECRET`) são responsabilidade do repo que cria o recurso, não deste
