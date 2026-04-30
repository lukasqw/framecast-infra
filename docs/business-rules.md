# Regras de Negócio — oficina-tech-infra

Este repo é infraestrutura base. As regras aqui são operacionais, de segurança e de dependência entre repos.

---

## Responsabilidades

**Este repo FAZ:**
- Descobre e referencia a VPC padrão da AWS (não cria uma nova VPC)
- Cria e gerencia o cluster EKS e seus node groups
- Cria o NLB que expõe o backend para o API Gateway
- Cria os security groups para EKS nodes
- Configura acesso ao cluster via EKS Access Entries API
- Expõe outputs via remote state S3 para os demais repos

**Este repo NÃO FAZ:**
- Não cria banco de dados (responsabilidade de `oficina-tech-db`)
- Não cria API Gateway ou Lambdas (responsabilidade de `oficina-tech-api-gateway`)
- Não faz deploy da aplicação (responsabilidade do CI/CD de `oficina-tech`)
- Não cria VPC, Internet Gateway, NAT Gateway, Route Tables — usa a VPC padrão existente
- Não cria o aws-auth ConfigMap — usa o EKS Access Entries API para evitar dependência circular

## Rede e Segurança

- Subnets usadas são as existentes na VPC padrão (`172.31.0.0/16`), filtradas para `us-east-1a` e `us-east-1b`
- O security group do EKS permite entrada apenas nas portas `443` e `30080` — não há regras abertas para outras portas
- O NLB é público (sem IP elástico fixo); seu DNS é o ponto de entrada referenciado pelo API Gateway
- O tráfego do NLB atinge os nodes via NodePort `30080`; o roteamento interno ao pod é feito pelo Kubernetes

## Regras de Modificação da Infraestrutura

- **VPC:** não é gerenciada por este repo — modificar subnets via console AWS, não via Terraform aqui
- **EKS — upgrade de versão:** seguir processo incremental, uma versão minor por vez (ex: 1.31 → 1.32)
- **EKS — mudança de instance type:** requer substituição do node group — planejar com janela de manutenção
- **NLB — mudança de porta:** afeta o API Gateway (`oficina-tech-api-gateway`) — coordenar com aquele repo
- **Security groups:** qualquer remoção de regra de entrada pode derrubar o tráfego — validar antes de aplicar
- **Outputs:** nunca renomear ou remover um output existente sem atualizar todos os repos que o consomem

## Remote State

- O state S3 deste repo é lido por `oficina-tech-db` e `oficina-tech-api-gateway`
- Bucket: `fiap-soat-tf-backend-bispo-730335587750`, key: `fiap/infra/terraform.tfstate`
- **Nunca apagar o bucket S3** sem migrar os outros repos
- DynamoDB lock **não está configurado** — evitar execuções paralelas de `terraform apply`

## Acesso ao Cluster EKS

- Acesso via EKS Access Entries API (não via aws-auth ConfigMap)
- O caller que executa o Terraform recebe automaticamente `AmazonEKSClusterAdminPolicy`
- Para adicionar outro principal com acesso admin: fornecer `var.principal_arn` no `terraform.tfvars`
- Acesso humano via CLI: `aws eks update-kubeconfig --name EKS-OFICINA-TECH --region us-east-1`
- Workloads no cluster usam `LabRole` (AWS Academy) — IRSA não está configurado

## Escalamento

- Node group configurado com min=1, desired=1, max=2
- Escalonamento manual via `node_desired_size` no `terraform.tfvars` ou via console EKS
- Cluster Autoscaler **não está instalado** — escalamento automático requer instalação adicional

## Controllers

Os módulos Terraform para AWS Load Balancer Controller e cert-manager existem mas não são instanciados em produção. Para ativá-los é necessário:
1. Criar o OIDC Provider do cluster EKS
2. Instanciar o módulo `alb-controller-role` com o ARN do OIDC Provider
3. Instanciar o módulo `alb-controller` com o ARN da role criada
