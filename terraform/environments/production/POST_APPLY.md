# Pós-Aplicação do Terraform

## ✅ Terraform Apply Concluído

Parabéns! A infraestrutura foi criada com sucesso.

## 🔐 Acesso ao Cluster EKS

O Terraform já configurou automaticamente o acesso ao cluster usando **EKS Access Entries** (método moderno da AWS).

### Verificar Quem Foi Detectado

```bash
terraform output current_caller_info
```

Você verá algo como:

```json
{
  "arn": "arn:aws:iam::730335587750:user/awsstudent",
  "username": "awsstudent",
  "type": "user",
  "account": "730335587750"
}
```

### Configurar kubectl

```bash
aws eks update-kubeconfig --name EKS-OFICINA-TECH --region us-east-1
```

### Testar Acesso

```bash
kubectl get nodes
```

Se funcionar, você está pronto! ✅

## 🚨 Se Receber "Unauthorized"

Isso pode acontecer se você estiver usando credenciais diferentes das que criaram o cluster.

### Solução 1: Aplicar Novamente (Recomendado)

```bash
terraform apply
```

O Terraform detectará seu usuário atual e atualizará o acesso.

### Solução 2: Aplicar ConfigMap Manualmente

Se preferir usar o método legado (ConfigMap):

```bash
# Da raiz do projeto
./scripts/apply-aws-auth.sh
```

Ou manualmente:

```bash
# 1. Descobrir seu ARN
aws sts get-caller-identity

# 2. Editar k8s/aws-auth-configmap.yaml com seu ARN

# 3. Aplicar
kubectl apply -f k8s/aws-auth-configmap.yaml
```

## 📊 Próximos Passos

### 1. Exportar Outputs para o Repositório da API

```bash
./scripts/export-outputs.sh
```

Copie os valores exibidos e configure como GitHub Secrets no repositório da API.

### 2. Verificar Recursos Criados

```bash
# Ver todos os outputs
terraform output

# Ver cluster EKS
aws eks describe-cluster --name EKS-OFICINA-TECH

# Ver nodes
kubectl get nodes

# Ver namespaces
kubectl get namespaces
```

### 3. Aplicar RBAC Customizado (Opcional)

Se você configurou usuários adicionais com grupos customizados:

```bash
# Grupo de desenvolvedores
kubectl apply -f k8s/rbac/developers-role.yaml

# Grupo read-only
kubectl apply -f k8s/rbac/readonly-role.yaml
```

## 🔍 Verificações de Saúde

### Cluster EKS

```bash
# Status do cluster
aws eks describe-cluster --name EKS-OFICINA-TECH --query 'cluster.status'

# Nodes
kubectl get nodes -o wide

# Pods do sistema
kubectl get pods -n kube-system
```

### RDS Database

```bash
# Status do RDS
terraform output rds_endpoint

# Testar conexão (se tiver psql instalado)
psql "$(terraform output -raw rds_endpoint | sed 's/:5432//')" -U admin -d oficina_tech
```

### ALB Load Balancer

```bash
# DNS do ALB
terraform output alb_dns_name

# Testar (pode retornar 503 se não houver aplicação ainda)
curl -I http://$(terraform output -raw alb_dns_name)
```

## 📚 Documentação

- [Quick Start](../../../docs/QUICK_START.md) - Guia rápido
- [Fluxo Automático](../../../docs/AUTO_ACCESS_FLOW.md) - Como funciona a detecção
- [Integração com API](../../../docs/API_TO_EKS_GUIDE.md) - Deploy da aplicação

## 💡 Dicas

1. **AWS Academy**: Credenciais expiram frequentemente. Quando expirar, atualize e execute `terraform apply` novamente.

2. **Múltiplos Usuários**: Para adicionar mais usuários, edite `terraform.tfvars`:

   ```hcl
   additional_users = [
     {
       userarn  = "arn:aws:iam::123:user/developer"
       username = "developer"
       groups   = ["developers"]
     }
   ]
   ```

   E execute `terraform apply`.

3. **Debug**: Use `kubectl auth can-i --list` para ver suas permissões.

4. **Logs**: Para ver logs de um pod: `kubectl logs -f pod/nome-do-pod`

## 🆘 Suporte

Se encontrar problemas:

1. Verifique os logs do Terraform
2. Consulte a documentação em `docs/`
3. Abra uma issue no repositório
