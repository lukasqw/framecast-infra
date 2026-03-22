# Infraestrutura - EKS Oficina Tech

Este repositório contém a infraestrutura como código (IaC) para o projeto EKS Oficina Tech, utilizando Terraform para provisionar recursos na AWS.

## Estrutura do Projeto

```
.
├── terraform/
│   ├── modules/                 # Módulos reutilizáveis
│   │   ├── eks/                # Cluster EKS e Node Groups
│   │   ├── rds/                # RDS PostgreSQL
│   │   ├── alb/                # Application Load Balancer
│   │   └── security-groups/    # Security Groups
│   ├── environments/
│   │   └── production/         # Ambiente de produção
│   │       ├── main.tf         # Configuração principal
│   │       ├── variables.tf    # Variáveis
│   │       ├── outputs.tf      # Outputs
│   │       ├── locals.tf       # Valores locais
│   │       ├── data.tf         # Data sources
│   │       ├── provider.tf     # Providers
│   │       ├── backend.tf      # Backend S3
│   │       ├── versions.tf     # Versões Terraform/Providers
│   │       └── terraform.tfvars.example
│   ├── README.md               # Documentação da estrutura
│   ├── BEST_PRACTICES.md       # Guia de melhores práticas
│   ├── MIGRATION_GUIDE.md      # Guia de migração
│   ├── EXAMPLES.md             # Exemplos de uso
│   └── CHANGELOG.md            # Histórico de mudanças
└── .github/
    └── workflows/
        └── terraform-deploy.yml # Pipeline CI/CD
```

### Estrutura Modular

O projeto segue as melhores práticas do mercado com:

- **Módulos Reutilizáveis**: Cada componente (EKS, RDS, ALB) é um módulo independente
- **Separação de Ambientes**: Configurações específicas por ambiente
- **Documentação Completa**: README em cada módulo e guias detalhados
- **Código DRY**: Evita duplicação através de módulos
- **Escalabilidade**: Fácil adicionar novos ambientes (staging, dev, etc)

## Recursos Provisionados

- **EKS Cluster**: Cluster Kubernetes gerenciado com node groups
- **RDS PostgreSQL**: Banco de dados relacional com backups automáticos
- **Security Groups**: Grupos de segurança isolados para EKS, RDS e ALB
- **Application Load Balancer**: Balanceador de carga para aplicações

## Arquitetura

A infraestrutura é organizada em módulos reutilizáveis:

- **Módulo EKS**: Provisiona cluster EKS e node groups
- **Módulo RDS**: Provisiona instância PostgreSQL com subnet group
- **Módulo ALB**: Provisiona load balancer com target groups
- **Módulo Security Groups**: Gerencia todos os security groups e regras

## Configuração Inicial

### 1. Pré-requisitos

- Terraform >= 1.0
- AWS CLI configurado
- kubectl instalado
- Credenciais AWS com permissões adequadas

### 2. Configurar Variáveis

Copie o arquivo de exemplo e preencha com seus valores:

```bash
cd terraform/environments/production
cp terraform.tfvars.example terraform.tfvars
```

Edite `terraform.tfvars` com suas configurações. Principais variáveis:

```hcl
# Obrigatório
db_password = "sua_senha_segura"

# Obrigatório para acesso ao EKS
principal_arn = "arn:aws:iam::730335587750:user/awsstudent"

# Configurações opcionais (já têm valores padrão)
aws_region          = "us-east-1"
project_name        = "EKS-OFICINA-TECH"
eks_cluster_version = "1.31"
rds_instance_class  = "db.t3.micro"
```

### 3. Descobrir seu ARN (AWS Academy)

```bash
aws sts get-caller-identity
```

Use o ARN retornado na variável `principal_arn`.

### 4. Inicializar Terraform

```bash
terraform init
```

### 5. Planejar Mudanças

```bash
terraform plan
```

### 6. Aplicar Infraestrutura

```bash
terraform apply
```

### 7. Configurar Acesso ao Cluster EKS

O Terraform detecta automaticamente seu usuário/role e configura o acesso ao cluster:

```bash
# Configurar kubectl
aws eks update-kubeconfig --name EKS-OFICINA-TECH --region us-east-1

# Testar acesso
kubectl get nodes
```

O Terraform já configurou seu acesso automaticamente! Para ver quem foi detectado:

```bash
cd terraform/environments/production
terraform output current_caller_info
```

## GitHub Actions - CI/CD

O repositório inclui um workflow automatizado que:

1. Executa `terraform plan` em pull requests
2. Aplica mudanças automaticamente na branch `main`
3. Exibe outputs do Terraform nos logs

### Secrets Necessários no GitHub (Repositório de Infraestrutura)

Configure os seguintes secrets no repositório de infraestrutura em `Settings > Secrets and variables > Actions`:

- `AWS_ACCESS_KEY_ID`: Access Key da AWS
- `AWS_SECRET_ACCESS_KEY`: Secret Key da AWS
- `AWS_SESSION_TOKEN`: Session Token (se usar AWS Academy/Learner Lab)
- `DB_PASSWORD`: Senha do banco de dados RDS

### Outputs Disponíveis

Os seguintes outputs são expostos pelo Terraform para serem usados nos outros repositórios:

- `eks_cluster_name`: Nome do cluster EKS
- `eks_cluster_endpoint`: Endpoint do cluster EKS
- `rds_endpoint`: Endpoint completo do RDS (host:port)
- `rds_address`: Endereço do RDS (apenas host)
- `rds_port`: Porta do RDS
- `rds_database_name`: Nome do banco de dados
- `rds_username`: Username do banco de dados
- `vpc_id`: ID da VPC
- `alb_dns_name`: DNS do Application Load Balancer
- `aws_region`: Região AWS

Para obter os outputs:

```bash
terraform output              # Ver todos
terraform output -json        # Ver em JSON
```

## Outputs

Após aplicar o Terraform, você pode visualizar os outputs:

```bash
terraform output
```

Para obter um output específico:

```bash
terraform output eks_cluster_name
```

Para obter o JSON formatado para GitHub Secrets:

```bash
terraform output -json github_secrets_json
```

## Uso no Repositório da Aplicação

Copie os outputs do Terraform e configure manualmente como secrets no repositório da aplicação. Depois use-os no workflow:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-region: ${{ secrets.AWS_REGION }}

- name: Update kubeconfig
  run: |
    aws eks update-kubeconfig \
      --name ${{ secrets.EKS_CLUSTER_NAME }} \
      --region ${{ secrets.AWS_REGION }}

- name: Deploy to EKS
  env:
    DATABASE_URL: postgresql://${{ secrets.RDS_USERNAME }}:${{ secrets.DB_PASSWORD }}@${{ secrets.RDS_ADDRESS }}:${{ secrets.RDS_PORT }}/${{ secrets.RDS_DATABASE_NAME }}
  run: |
    kubectl apply -f k8s/
```

## Manutenção

### Documentação Adicional

Para mais informações, consulte:

- **[terraform/README.md](terraform/README.md)** - Visão geral da estrutura Terraform
- **[terraform/BEST_PRACTICES.md](terraform/BEST_PRACTICES.md)** - Guia de melhores práticas
- **[terraform/FINOPS_GUIDE.md](terraform/FINOPS_GUIDE.md)** - Guia de FinOps e gestão de custos
- **[terraform/MIGRATION_GUIDE.md](terraform/MIGRATION_GUIDE.md)** - Guia de migração
- **[terraform/EXAMPLES.md](terraform/EXAMPLES.md)** - Exemplos práticos de uso
- **[terraform/CHANGELOG.md](terraform/CHANGELOG.md)** - Histórico de mudanças

### Atualizar Infraestrutura

1. Faça alterações nos arquivos Terraform
2. Commit e push para uma branch
3. Abra um Pull Request
4. Revise o plano do Terraform
5. Merge para `main` para aplicar

### Destruir Infraestrutura

```bash
cd terraform/environments/production
terraform destroy
```

## Segurança

- Nunca commite arquivos `terraform.tfvars` com credenciais
- Use secrets do GitHub para informações sensíveis
- Revise sempre o plano do Terraform antes de aplicar
- Mantenha o backend S3 com versionamento habilitado

## FinOps - Gestão de Custos

O projeto implementa tags de FinOps para controle de custos:

- **CostCenter**: Centro de custo responsável
- **BusinessUnit**: Unidade de negócio
- **Environment**: Ambiente (production, staging, dev)
- **Owner**: Responsável pelo recurso
- **Application**: Nome da aplicação

Consulte o [Guia de FinOps](terraform/FINOPS_GUIDE.md) para mais detalhes sobre:

- Como configurar tags de custo
- Relatórios de custo no AWS Cost Explorer
- Otimização de custos
- Políticas de governança

## Integração com Repositório da API

Após criar a infraestrutura, você precisa configurar o repositório da API para fazer deploy no EKS.

### Exportar Outputs para a API

```bash
./scripts/export-outputs.sh
```

Este script gera os valores necessários para configurar como GitHub Secrets no repositório da API.

### Documentação Completa

- **[Quick Start](docs/QUICK_START.md)** - Início rápido com detecção automática de usuário
- **[Fluxo Automático](docs/AUTO_ACCESS_FLOW.md)** - Como funciona a detecção automática
- **[AWS Academy Fix](docs/AWS_ACADEMY_FIX.md)** - Correção para assumed-role ARN
- **[RDS Connectivity](docs/RDS_CONNECTIVITY_FIX.md)** - Conectividade entre pods e RDS
- **[Integração com API](docs/API_TO_EKS_GUIDE.md)** - Como a API acessa o cluster
- **[Exemplo de Workflow](docs/API_WORKFLOW_EXAMPLE.yml)** - Workflow pronto para copiar
- **[Configuração de Secrets](docs/SECRETS_SETUP.md)** - Como transferir outputs entre repositórios
- **[Diagrama de Arquitetura](docs/ARCHITECTURE_DIAGRAM.md)** - Visão geral completa

## Suporte

Para questões ou problemas, abra uma issue no repositório.
