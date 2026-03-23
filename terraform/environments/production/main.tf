# Main Configuration - Production Environment

# Security Groups
module "security_groups" {
  source = "../../modules/security-groups"

  name_prefix = var.project_name
  vpc_id      = data.aws_vpc.main.id
  vpc_cidr    = data.aws_vpc.main.cidr_block

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

# RDS PostgreSQL
module "rds" {
  source = "../../modules/rds"

  identifier     = "${lower(var.project_name)}-db"
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class

  database_name = local.db_name
  username      = local.db_username
  password      = var.db_password

  subnet_ids             = local.filtered_subnet_ids
  vpc_security_group_ids = [module.security_groups.rds_security_group_id]

  allocated_storage       = var.rds_allocated_storage
  backup_retention_period = var.rds_backup_retention_period
  multi_az                = var.rds_multi_az
  skip_final_snapshot     = var.rds_skip_final_snapshot
  deletion_protection     = var.rds_deletion_protection

  tags = local.common_tags
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

  tags = local.common_tags
}

# Regra adicional: Permitir que o Security Group do cluster EKS acesse o RDS
# Esta regra é necessária porque o EKS cria automaticamente um Security Group para os nodes
resource "aws_vpc_security_group_ingress_rule" "rds_from_eks_cluster_nodes" {
  security_group_id            = module.security_groups.rds_security_group_id
  description                  = "PostgreSQL from EKS cluster nodes (auto-created cluster SG)"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.eks.cluster_security_group_id

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-rds-from-eks-nodes"
      Purpose = "allow-eks-nodes-to-rds"
    }
  )
}

# Regra adicional: Permitir que o NLB alcance a NodePort no cluster security group (auto-criado pelo EKS)
resource "aws_vpc_security_group_ingress_rule" "eks_cluster_nodeport" {
  security_group_id = module.eks.cluster_security_group_id
  description       = "Allow NLB to reach NodePort 30080 (cluster SG)"
  from_port         = 30080
  to_port           = 30080
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

