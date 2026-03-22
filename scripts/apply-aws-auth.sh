#!/bin/bash
# Script para aplicar ConfigMap aws-auth com usuário automático
# Uso: ./scripts/apply-aws-auth.sh

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Configurando aws-auth ConfigMap ===${NC}\n"

# Verificar se AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI não encontrado. Instale: https://aws.amazon.com/cli/${NC}"
    exit 1
fi

# Verificar se kubectl está instalado
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl não encontrado. Instale: https://kubernetes.io/docs/tasks/tools/${NC}"
    exit 1
fi

# Obter informações do usuário atual
echo -e "${YELLOW}📋 Detectando usuário AWS atual...${NC}"
CALLER_IDENTITY=$(aws sts get-caller-identity)
USER_ARN=$(echo $CALLER_IDENTITY | jq -r '.Arn')
ACCOUNT_ID=$(echo $CALLER_IDENTITY | jq -r '.Account')
USER_NAME=$(echo $USER_ARN | awk -F'/' '{print $NF}')

echo -e "${GREEN}✅ Usuário detectado:${NC}"
echo -e "   ARN: ${USER_ARN}"
echo -e "   Account: ${ACCOUNT_ID}"
echo -e "   Username: ${USER_NAME}"
echo ""

# Verificar se é um usuário ou role
if [[ $USER_ARN == *":user/"* ]]; then
    PRINCIPAL_TYPE="user"
elif [[ $USER_ARN == *":role/"* ]]; then
    PRINCIPAL_TYPE="role"
else
    echo -e "${RED}❌ Tipo de principal não reconhecido: ${USER_ARN}${NC}"
    exit 1
fi

echo -e "${BLUE}📝 Tipo de principal: ${PRINCIPAL_TYPE}${NC}\n"

# Criar ConfigMap temporário com valores substituídos
TEMP_FILE="/tmp/aws-auth-configmap-$(date +%s).yaml"

cat > "$TEMP_FILE" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::${ACCOUNT_ID}:role/LabRole
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
  mapUsers: |
    - userarn: ${USER_ARN}
      username: ${USER_NAME}
      groups:
        - system:masters
EOF

echo -e "${YELLOW}📄 ConfigMap gerado:${NC}"
cat "$TEMP_FILE"
echo ""

# Perguntar confirmação
read -p "Deseja aplicar este ConfigMap? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠️ Operação cancelada${NC}"
    rm "$TEMP_FILE"
    exit 0
fi

# Aplicar ConfigMap
echo -e "${YELLOW}🚀 Aplicando ConfigMap...${NC}"

if kubectl apply -f "$TEMP_FILE"; then
    echo -e "${GREEN}✅ ConfigMap aws-auth aplicado com sucesso!${NC}"
else
    echo -e "${RED}❌ Erro ao aplicar ConfigMap${NC}"
    echo -e "${YELLOW}Verifique se você tem acesso ao cluster${NC}"
    rm "$TEMP_FILE"
    exit 1
fi

# Limpar arquivo temporário
rm "$TEMP_FILE"

echo ""
echo -e "${GREEN}=== Configuração Concluída ===${NC}"
echo -e "${YELLOW}Testando acesso ao cluster...${NC}"
echo ""

# Testar acesso
if kubectl get nodes; then
    echo ""
    echo -e "${GREEN}✅ Acesso ao cluster configurado com sucesso!${NC}"
else
    echo ""
    echo -e "${RED}❌ Erro ao acessar o cluster${NC}"
    echo -e "${YELLOW}Pode levar alguns segundos para as permissões serem aplicadas${NC}"
    echo -e "${YELLOW}Tente novamente: kubectl get nodes${NC}"
fi

echo ""
echo -e "${BLUE}💡 Dica: Para adicionar mais usuários, edite o ConfigMap:${NC}"
echo -e "   kubectl edit configmap aws-auth -n kube-system"
echo ""
