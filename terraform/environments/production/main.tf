# Main Configuration - Production Environment

# Security Groups
module "security_groups" {
  source = "../../modules/security-groups"

  name_prefix = var.project_name
  vpc_id      = data.aws_vpc.main.id

  tags = local.common_tags
}

# EKS Cluster
module "eks" {
  source = "../../modules/eks"

  cluster_name     = var.project_name
  cluster_version  = var.eks_cluster_version
  cluster_role_arn = local.lab_role_arn
  node_role_arn    = local.lab_role_arn

  subnet_ids         = local.filtered_subnet_ids
  security_group_ids = [module.security_groups.eks_security_group_id]

  authentication_mode = var.access_config

  node_group_name = var.node_group
  desired_size    = var.node_desired_size
  max_size        = var.node_max_size
  min_size        = var.node_min_size
  instance_types  = [var.instance_type]

  tags = local.common_tags

  node_tags = {
    Workload = "kubernetes-nodes"
    Scaling  = "auto"
  }
}

# Network Load Balancer
# Usado pelo API Gateway para rotear tráfego para os pods via NodePort
module "nlb" {
  source = "../../modules/nlb"

  name     = "${var.project_name}-nlb"
  subnets  = local.filtered_subnet_ids
  vpc_id   = data.aws_vpc.main.id
  asg_name = module.eks.node_group_asg_name

  target_group_port = 30080
  health_check_path = "/health"

  microservice_ports = {
    ms1 = { node_port = 30081, health_check_path = "/health" }
    ms2 = { node_port = 30082, health_check_path = "/health" }
    ms3 = { node_port = 30083, health_check_path = "/health" }
  }

  tags = local.common_tags
}

# Datadog Monitors (ativo apenas quando as chaves são fornecidas)
module "datadog" {
  source = "../../modules/datadog"
  count  = var.datadog_api_key != "" ? 1 : 0

  datadog_api_key = var.datadog_api_key
  datadog_app_key = var.datadog_app_key
}

# SQS Queues — mensageria assíncrona entre microsserviços
# customer-deleted: ms1 publica → ms2 consome
resource "aws_sqs_queue" "customer_deleted" {
  name                       = "${lower(var.project_name)}-customer-deleted"
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 30

  tags = merge(local.common_tags, {
    Name    = "${lower(var.project_name)}-customer-deleted"
    Purpose = "ms1-to-ms2"
  })
}

# inventory-op-requested: ms2 publica → ms3 consome
resource "aws_sqs_queue" "inventory_op_requested" {
  name                       = "${lower(var.project_name)}-inventory-op-requested"
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 30

  tags = merge(local.common_tags, {
    Name    = "${lower(var.project_name)}-inventory-op-requested"
    Purpose = "ms2-to-ms3"
  })
}

# inventory-op-succeeded: ms3 publica → ms2 consome
resource "aws_sqs_queue" "inventory_op_succeeded" {
  name                       = "${lower(var.project_name)}-inventory-op-succeeded"
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 30

  tags = merge(local.common_tags, {
    Name    = "${lower(var.project_name)}-inventory-op-succeeded"
    Purpose = "ms3-to-ms2"
  })
}

# inventory-op-failed: ms3 publica → ms2 consome
resource "aws_sqs_queue" "inventory_op_failed" {
  name                       = "${lower(var.project_name)}-inventory-op-failed"
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 30

  tags = merge(local.common_tags, {
    Name    = "${lower(var.project_name)}-inventory-op-failed"
    Purpose = "ms3-to-ms2"
  })
}

# Regra adicional: Permitir que o NLB alcance a NodePort no cluster security group (auto-criado pelo EKS)
resource "aws_vpc_security_group_ingress_rule" "eks_cluster_nodeport" {
  security_group_id = module.eks.cluster_security_group_id
  description       = "Allow NLB to reach NodePorts 30080-30083 (cluster SG)"
  from_port         = 30080
  to_port           = 30083
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-eks-nodeport"
      Purpose = "allow-nlb-to-eks-nodeport"
    }
  )
}

