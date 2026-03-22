# Kubernetes Manifests

Este diretório contém os manifests Kubernetes para configuração do cluster EKS.

## 📁 Estrutura

```
k8s/
├── aws-auth-configmap.yaml    # ConfigMap para acesso ao cluster (método alternativo)
├── rbac/
│   ├── developers-role.yaml   # RBAC para desenvolvedores
│   └── readonly-role.yaml     # RBAC para usuários read-only
└── README.md                  # Este arquivo
```

## 🚀 Uso

### Configurar Acesso ao Cluster (aws-auth)

#### Método Automático (Recomendado)

Use o script que detecta automaticamente seu usuário AWS:

```bash
# Da raiz do projeto
./scripts/apply-aws-auth.sh
```

O script irá:

1. Detectar seu usuário AWS atual usando `aws sts get-caller-identity`
2. Gerar o ConfigMap com seu ARN automaticamente
3. Aplicar no cluster

#### Método Manual

Se preferir fazer manualmente:

**1. Descubra seu ARN:**

```bash
aws sts get-caller-identity
```

**2. Edite o arquivo `aws-auth-configmap.yaml`:**

Substitua os placeholders:

- `ACCOUNT_ID` → seu Account ID (ex: 730335587750)
- `USER_ARN_PLACEHOLDER` → seu ARN completo (ex: arn:aws:iam::730335587750:user/awsstudent)
- `USER_NAME_PLACEHOLDER` → seu username (ex: awsstudent)

**3. Aplique o ConfigMap:**

```bash
kubectl apply -f k8s/aws-auth-configmap.yaml
```

### Aplicar RBAC Customizado

Para criar grupos de permissões customizados:

```bash
# Grupo de desenvolvedores (permissões de edição)
kubectl apply -f k8s/rbac/developers-role.yaml

# Grupo read-only (apenas visualização)
kubectl apply -f k8s/rbac/readonly-role.yaml
```

## 🔐 Grupos de Permissões

### system:masters

- Acesso administrativo completo ao cluster
- Pode criar, modificar e deletar qualquer recurso
- **Cuidado:** Use apenas para administradores

### developers

- Permissões de edição (criar, modificar, deletar recursos)
- Não pode modificar RBAC ou namespaces
- Ideal para desenvolvedores

### readonly

- Apenas visualização de recursos
- Não pode modificar nada
- Ideal para auditoria ou suporte

## 📝 Exemplos

### Adicionar Múltiplos Usuários

Edite `aws-auth-configmap.yaml`:

```yaml
mapUsers: |
  - userarn: arn:aws:iam::730335587750:user/admin
    username: admin
    groups:
      - system:masters
  - userarn: arn:aws:iam::730335587750:user/developer1
    username: developer1
    groups:
      - developers
  - userarn: arn:aws:iam::730335587750:user/viewer
    username: viewer
    groups:
      - readonly
```

### Verificar Configuração Atual

```bash
# Ver ConfigMap atual
kubectl get configmap aws-auth -n kube-system -o yaml

# Ver ClusterRoleBindings
kubectl get clusterrolebindings

# Testar acesso
kubectl auth can-i create pods
kubectl auth can-i delete deployments
```

## 🔧 Troubleshooting

### Erro: "You must be logged in to the server (Unauthorized)"

**Causa:** Seu usuário não está no ConfigMap aws-auth.

**Solução:**

1. Execute `./scripts/apply-aws-auth.sh`
2. Ou adicione manualmente seu ARN no ConfigMap

### Erro: "configmaps 'aws-auth' not found"

**Causa:** ConfigMap não existe ainda.

**Solução:**

```bash
kubectl apply -f k8s/aws-auth-configmap.yaml
```

### Verificar Quem Você É

```bash
# Ver seu usuário AWS
aws sts get-caller-identity

# Ver contexto kubectl atual
kubectl config current-context

# Ver permissões
kubectl auth can-i --list
```

## 📚 Referências

- [EKS Access Entries](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Managing Users in EKS](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html)

## 💡 Dicas

1. **Backup:** Sempre faça backup do ConfigMap antes de modificar:

   ```bash
   kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth-backup.yaml
   ```

2. **Teste:** Após modificar, teste o acesso:

   ```bash
   kubectl get nodes
   ```

3. **AWS Academy:** Credenciais expiram frequentemente. Use o script automático para facilitar.

4. **Terraform:** Prefira usar EKS Access Entries via Terraform (mais moderno e gerenciável).
