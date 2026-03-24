# Oficina Tech - Infrastructure

Infraestrutura como código (IaC) para o projeto Oficina Tech, provisionando cluster EKS, networking, load balancers e recursos AWS necessários.

## Descrição

Este repositório contém toda a infraestrutura base do sistema Oficina Tech na AWS, incluindo cluster Kubernetes (EKS), networking (VPC, subnets, security groups), load balancers (NLB), e configurações de acesso e segurança. A infraestrutura é totalmente automatizada usando Terraform com módulos reutilizáveis e pipelines CI/CD completos.

O projeto provisiona um cluster EKS v1.31 com node groups auto-scaling, Network Load Balancer para roteamento de tráfego externo, AWS Load Balancer Controller para gerenciar Ingress resources, cert-manager para certificados TLS, e toda a configuração de IAM, RBAC e security groups necessária para operação segura.

## Estrutura de Pastas

```

oficina-tech-infra/
├── .github/
│   └── workflows/              # Pipelines CI/CD
│       ├── ci.yml              # Validação e testes
│       ├── deploy.yml          # Deploy automatizado
│       ├── destroy.yml         # Destruição de recursos
│       └── release.yml         # Versionamento e releases
├── docs/
│   └── infrastructure-component-diagram.puml  # Diagrama de arquitetura
├── k8s/
│   ├── rbac/                   # Configurações RBAC
│   └── aws-auth-configmap.yaml # ConfigMap de autenticação
├── terraform/
│   ├── environments/           # Configurações por ambiente
│   │   └── production/         # Ambiente de produção
│   │       ├── backend.tf          # Backend S3 para state
│   │       ├── data.tf             # Data sources
│   │       ├── eks-access.tf       # Access entries do EKS
│   │       ├── aws-auth-configmap.tf  # ConfigMap auth
│   │       ├── locals.tf           # Variáveis locais
│   │       ├── main.tf             # Recursos principais
│   │       ├── outputs.tf          # Outputs
│   │       ├── provider.tf         # Provider AWS
│   │       ├── variables.tf        # Variáveis de entrada
│   │       ├── versions.tf         # Versões requeridas
│   │       └── terraform.tfvars.example  # Exemplo de variáveis
│   └── modules/                # Módulos Terraform reutilizáveis
│       ├── alb-controller/         # AWS Load Balancer Controller
│       ├── alb-controller-role/    # IAM role para ALB Controller
│       ├── eks/                    # Cluster EKS
│       ├── nlb/                    # Network Load Balancer
│       ├── rds/                    # RDS PostgreSQL (deprecated)
│       └── security-groups/        # Security Groups
├── .gitignore
├── terraform.tfstate           # State local (backup)
└── README.md
```

## Funcionalidades

### Cluster Kubernetes (EKS)

- **EKS v1.31**: Cluster Kubernetes gerenciado pela AWS
- **Node Groups**: Auto-scaling com instâncias t3.medium
- **Multi-AZ**: Deployment em múltiplas zonas de disponibilidade
- **Access Entries**: Autenticação moderna via EKS Access API
- **ConfigMap Auth**: Suporte legado para aws-auth ConfigMap
- **IRSA**: IAM Roles for Service Accounts configurado

### Networking

- **VPC Integration**: Utiliza VPC existente (AWS Academy)
- **Multi-AZ Subnets**: Subnets em us-east-1a e us-east-1b
- **Security Groups**: Controle granular de acesso
  - EKS Security Group (nodes e control plane)
  - NLB Security Group (load balancer)
  - RDS Security Group (banco de dados)
- **Network Load Balancer**: Roteamento de tráfego externo para NodePort

### Load Balancing

- **Network Load Balancer (NLB)**:
  - Listener TCP:80 para tráfego HTTP
  - Target Group apontando para NodePort 30080
  - Health checks configurados
  - Multi-AZ para alta disponibilidade
- **AWS Load Balancer Controller**:
  - Gerencia Application Load Balancers via Ingress
  - Integração com EKS via Helm
  - IRSA para permissões AWS

### Certificados e TLS

- **cert-manager**: Gerenciamento automático de certificados TLS
- **Let's Encrypt**: Integração para certificados gratuitos
- **Auto-renewal**: Renovação automática de certificados

### IAM e Segurança

- **LabRole Integration**: Compatibilidade com AWS Academy
- **OIDC Provider**: Federação para IRSA
- **Access Entries**: Controle de acesso ao cluster
- **RBAC**: Roles e bindings Kubernetes
- **Service Accounts**: Contas de serviço com permissões específicas

### Monitoramento e Observabilidade

- **CloudWatch Integration**: Logs e métricas do cluster
- **EKS Control Plane Logs**: Logs do API server, audit, etc
- **Node Metrics**: Métricas de CPU, memória, disco
- **Application Logs**: Logs dos pods e containers

### CI/CD

- **Validação Automática**: Terraform validate, format check
- **Security Scanning**: tfsec e Checkov para vulnerabilidades
- **Terraform Plan**: Preview de mudanças em PRs
- **Deploy Automatizado**: Apply automático na branch main
- **Health Checks**: Verificação pós-deploy
- **Release Management**: Versionamento automático com tags

### FinOps e Tagging

- **Cost Center**: Tags para rastreamento de custos
- **Business Unit**: Organização por unidade de negócio
- **Environment**: Separação por ambiente (prod, staging, dev)
- **Owner**: Responsável pelos recursos
- **Application**: Nome da aplicação
- **Microservice**: Identificação de microserviços

## Tecnologias Usadas

- **Terraform** (>= 1.7.0): Infraestrutura como código
- **AWS EKS**: Kubernetes gerenciado (v1.31)
- **AWS VPC**: Networking e subnets
- **AWS NLB**: Network Load Balancer
- **AWS IAM**: Gerenciamento de identidade e acesso
- **Helm**: Gerenciador de pacotes Kubernetes
- **kubectl**: CLI do Kubernetes
- **GitHub Actions**: CI/CD pipelines

### Recursos AWS

- AWS EKS (Elastic Kubernetes Service)
- AWS EC2 (instâncias dos nodes)
- AWS Auto Scaling Groups
- AWS VPC (Virtual Private Cloud)
- AWS NLB (Network Load Balancer)
- AWS IAM (Roles, Policies, OIDC Provider)
- AWS CloudWatch (Logs e Métricas)
- AWS S3 (Terraform state backend)

### Helm Charts

- AWS Load Balancer Controller (v2.x)
- cert-manager (v1.x)

## Como Rodar o Projeto

### Pré-requisitos

- [Terraform](https://www.terraform.io/downloads) >= 1.7.0
- [AWS CLI](https://aws.amazon.com/cli/) configurado
- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.31
- [Helm](https://helm.sh/docs/intro/install/) >= 3.x
- Credenciais AWS com permissões adequadas
- Acesso ao S3 bucket para Terraform state

### Configuração Inicial

1. Clone o repositório:

```bash
git clone <repository-url>
cd oficina-tech-infra
```

2. Configure as credenciais AWS:

```bash
aws configure
```

3. Navegue para o ambiente desejado:

```bash
cd terraform/environments/production
```

4. Crie um arquivo de variáveis (opcional):

```bash
cp terraform.tfvars.example terraform.tfvars
```

5. Edite as variáveis conforme necessário:

```hcl
# terraform.tfvars
project_name         = "EKS-OFICINA-TECH"
eks_cluster_version  = "1.31"
instance_type        = "t3.medium"
node_desired_size    = 1
node_max_size        = 2
node_min_size        = 1

# FinOps Tags
cost_center    = "engineering"
business_unit  = "technology"
environment    = "production"
owner          = "devops-team"
application    = "oficina-tech"
```

### Deploy da Infraestrutura

#### Usando Terraform Diretamente

```bash
# 1. Inicializar Terraform
terraform init

# 2. Validar configuração
terraform validate

# 3. Formatar código
terraform fmt -recursive

# 4. Planejar mudanças
terraform plan -out=tfplan

# 5. Aplicar mudanças
terraform apply tfplan

# 6. Ver outputs
terraform output
```

#### Deploy Completo Passo a Passo

```bash
# Navegar para o ambiente
cd terraform/environments/production

# Inicializar
terraform init

# Planejar
terraform plan

# Aplicar (com aprovação manual)
terraform apply

# Ou aplicar automaticamente
terraform apply -auto-approve
```

### Configurar kubectl

Após o deploy do cluster EKS:

```bash
# Obter nome do cluster
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)

# Atualizar kubeconfig
aws eks update-kubeconfig \
  --name $CLUSTER_NAME \
  --region us-east-1

# Verificar conectividade
kubectl get nodes

# Ver pods do sistema
kubectl get pods -n kube-system
```

### Aplicar Recursos Kubernetes

```bash
# Aplicar ConfigMap de autenticação
kubectl apply -f ../../k8s/aws-auth-configmap.yaml

# Aplicar RBAC (se existir)
kubectl apply -f ../../k8s/rbac/
```

### Verificar Componentes

```bash
# Verificar nodes
kubectl get nodes

# Verificar AWS Load Balancer Controller
kubectl get deployment -n kube-system aws-load-balancer-controller

# Verificar cert-manager
kubectl get pods -n cert-manager

# Verificar CRDs
kubectl get crd | grep elbv2
kubectl get crd | grep cert-manager
```

### Obter Informações da Infraestrutura

```bash
# Ver todos os outputs
terraform output

# Outputs específicos
terraform output eks_cluster_name
terraform output eks_cluster_endpoint
terraform output nlb_dns_name
terraform output vpc_id
terraform output eks_security_group_id

# JSON formatado para GitHub Secrets
terraform output -json github_secrets_json
```

### CI/CD via GitHub Actions

O projeto possui pipelines automatizados:

#### CI Workflow (Pull Requests)

Executado em PRs para develop ou main:

- Validação do Terraform (format, validate)
- Security scan (tfsec, Checkov)
- Terraform plan com comentário no PR
- Verificação de estrutura de arquivos

#### Deploy Workflow (Push para main)

Executado automaticamente ao fazer push para main:

- Terraform apply
- Atualização do kubeconfig
- Aplicação de recursos Kubernetes
- Health checks pós-deploy
- Finalização de release

#### Destroy Workflow (Manual)

Workflow manual para destruir recursos:

- Remoção de recursos Kubernetes
- Terraform destroy
- Limpeza de state

#### Release Workflow (Manual)

Workflow para criar releases:

- Criação de tags RC
- Geração de changelog
- Criação de GitHub Release

### Secrets Necessários no GitHub

Configure os seguintes secrets no repositório:

- `AWS_ACCESS_KEY_ID`: Access key da AWS
- `AWS_SECRET_ACCESS_KEY`: Secret key da AWS
- `AWS_SESSION_TOKEN`: Session token (AWS Academy)

### Variáveis de Ambiente

As principais variáveis configuráveis:

#### Cluster EKS

- `project_name`: Nome do projeto (padrão: "EKS-OFICINA-TECH")
- `eks_cluster_version`: Versão do Kubernetes (padrão: "1.31")
- `access_config`: Modo de autenticação (API, CONFIG_MAP, API_AND_CONFIG_MAP)

#### Node Group

- `node_group`: Nome do node group (padrão: "oficina_tech")
- `instance_type`: Tipo de instância (padrão: "t3.medium")
- `node_desired_size`: Número desejado de nodes (padrão: 1)
- `node_max_size`: Número máximo de nodes (padrão: 2)
- `node_min_size`: Número mínimo de nodes (padrão: 1)

#### AWS Academy

- `lab_role`: ARN da LabRole (opcional)
- `principal_arn`: ARN do principal para acesso (opcional)

#### FinOps Tags

- `cost_center`: Centro de custo
- `business_unit`: Unidade de negócio
- `environment`: Ambiente (production, staging, development)
- `owner`: Responsável
- `application`: Nome da aplicação
- `microservice`: Nome do microserviço

## Arquitetura

### Diagrama de Componentes

```
┌─────────────────┐
│  External       │
│  Users          │
└────────┬────────┘
         │ HTTP :80
         ▼
┌─────────────────────────────────────┐
│  Network Load Balancer (Multi-AZ)   │
│  • TCP:80 → NodePort:30080          │
│  • Health checks: /health           │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  EKS Cluster v1.31                  │
│  ┌───────────────────────────────┐  │
│  │  Control Plane (Managed)      │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │  Node Group (Auto Scaling)    │  │
│  │  • t3.medium instances        │  │
│  │  • Multi-AZ (1a, 1b)         │  │
│  │  • Min: 1, Max: 2            │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │  AWS Load Balancer Controller │  │
│  │  • Manages ALB/NLB           │  │
│  │  • IRSA enabled              │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │  cert-manager                 │  │
│  │  • TLS certificates          │  │
│  │  • Auto-renewal              │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Fluxo de Tráfego

1. Usuário faz requisição HTTP para o NLB
2. NLB roteia para NodePort 30080 nos nodes do EKS
3. Kubernetes Service roteia para os pods da aplicação
4. Aplicação processa e retorna resposta

### Autenticação e Acesso

1. **EKS Access Entries**: Autenticação moderna via API
2. **aws-auth ConfigMap**: Suporte legado para compatibilidade
3. **RBAC**: Roles e bindings Kubernetes
4. **IRSA**: Service accounts com permissões AWS

## Monitoramento

### CloudWatch Logs

```bash
# Ver logs do control plane
aws logs tail /aws/eks/EKS-OFICINA-TECH/cluster --follow

# Ver logs de um node específico
kubectl logs -n kube-system <pod-name>
```

### Métricas do Cluster

```bash
# Ver uso de recursos dos nodes
kubectl top nodes

# Ver uso de recursos dos pods
kubectl top pods -A

# Descrever node
kubectl describe node <node-name>
```

### Health Checks

```bash
# Verificar saúde do cluster
aws eks describe-cluster \
  --name EKS-OFICINA-TECH \
  --query 'cluster.status'

# Verificar nodes
kubectl get nodes

# Verificar componentes do sistema
kubectl get pods -n kube-system

# Verificar NLB
aws elbv2 describe-load-balancers \
  --names EKS-OFICINA-TECH-nlb
```

## Troubleshooting

### Cluster não Acessível

```bash
# Verificar status do cluster
aws eks describe-cluster --name EKS-OFICINA-TECH

# Atualizar kubeconfig
aws eks update-kubeconfig --name EKS-OFICINA-TECH --region us-east-1

# Verificar credenciais
aws sts get-caller-identity
```

### Nodes não Aparecem

```bash
# Verificar node group
aws eks describe-nodegroup \
  --cluster-name EKS-OFICINA-TECH \
  --nodegroup-name oficina_tech

# Verificar Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
  --query 'AutoScalingGroups[?contains(Tags[?Key==`eks:cluster-name`].Value, `EKS-OFICINA-TECH`)]'

# Ver logs do node
kubectl logs -n kube-system -l k8s-app=aws-node
```

### AWS Load Balancer Controller não Funciona

```bash
# Verificar deployment
kubectl get deployment -n kube-system aws-load-balancer-controller

# Ver logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Verificar CRDs
kubectl get crd | grep elbv2

# Verificar service account e IRSA
kubectl describe sa -n kube-system aws-load-balancer-controller
```

### Terraform Apply Falha

```bash
# Limpar state local
rm -rf .terraform terraform.tfstate*

# Reinicializar
terraform init -reconfigure

# Validar
terraform validate

# Tentar novamente
terraform plan
terraform apply
```

### Problemas de Permissão

```bash

# Verificar access entries
aws eks list-access-entries --cluster-name EKS-OFICINA-TECH

# Verificar aws-auth ConfigMap
kubectl get configmap -n kube-system aws-auth -o yaml

# Adicionar usuário manualmente
kubectl edit configmap -n kube-system aws-auth
```

## Documentação Adicional

- [Diagrama de Arquitetura](docs/infrastructure-component-diagram.puml): Diagrama completo da infraestrutura
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/): Documentação oficial do EKS
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs): Documentação do provider
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/): Documentação do controller

## Segurança

### Boas Práticas Implementadas

- Security groups restritivos
- IRSA para permissões granulares
- Access entries para controle de acesso
- Encryption at rest (EBS volumes)
- Private subnets para nodes
- Network policies (recomendado implementar)

### Recomendações para Produção

- Habilitar encryption de secrets no EKS
- Implementar Pod Security Standards
- Configurar Network Policies
- Habilitar audit logs
- Usar AWS Secrets Manager para secrets
- Implementar backup e disaster recovery
- Configurar alertas no CloudWatch
- Implementar WAF para proteção adicional

## Manutenção

### Atualização do Cluster

```bash
# Verificar versão atual
kubectl version --short

# Atualizar versão no Terraform
# Editar variables.tf: eks_cluster_version = "1.32"

# Aplicar mudança
terraform plan
terraform apply
```

### Scaling de Nodes

```bash
# Via Terraform
# Editar variables.tf: node_desired_size, node_max_size, node_min_size
terraform apply

# Via AWS CLI
aws eks update-nodegroup-config \
  --cluster-name EKS-OFICINA-TECH \
  --nodegroup-name oficina_tech \
  --scaling-config desiredSize=3,minSize=2,maxSize=4
```

### Backup e Restore

```bash
# Backup do state
aws s3 cp s3://fiap-soat-tf-backend-bispo-730335587750/fiap/eks/terraform.tfstate ./backup/

# Backup de recursos Kubernetes
kubectl get all -A -o yaml > backup/k8s-resources.yaml
```

## Custos

### Recursos Principais

- EKS Control Plane: ~$0.10/hora (~$73/mês)
- EC2 Nodes (t3.medium): ~$0.0416/hora por node
- NLB: ~$0.0225/hora + data processing
- EBS Volumes: ~$0.10/GB-mês
- Data Transfer: Variável

### Otimização de Custos

- Use Spot Instances para nodes (não críticos)
- Configure auto-scaling adequadamente
- Monitore recursos não utilizados
- Use tags FinOps para rastreamento
- Revise regularmente o tamanho das instâncias

## Licença

Este projeto faz parte do sistema Oficina Tech.
