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

# Application Load Balancer
module "alb" {
  source = "../../modules/alb"

  name            = "${var.project_name}-alb"
  security_groups = [module.security_groups.alb_security_group_id]
  subnets         = local.filtered_subnet_ids
  vpc_id          = data.aws_vpc.main.id

  target_type = "ip"

  tags = local.common_tags
}

# EKS Access Entry (AWS Academy)
resource "aws_eks_access_entry" "lab_access" {
  count = var.principal_arn != "" ? 1 : 0

  cluster_name      = module.eks.cluster_name
  principal_arn     = var.principal_arn
  kubernetes_groups = []
  type              = "STANDARD"

  depends_on = [module.eks]
}

# EKS Access Policy (AWS Academy)
resource "aws_eks_access_policy_association" "lab_policy" {
  count = var.principal_arn != "" ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = var.principal_arn
  policy_arn    = var.policy_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.lab_access]
}
