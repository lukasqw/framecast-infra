# EKS Cluster Module
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = var.security_group_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  access_config {
    authentication_mode = var.authentication_mode
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  tags = merge(
    var.tags,
    {
      ResourceType = "eks-cluster"
      Service      = "eks"
    }
  )
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = var.node_group_name
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  instance_types = var.instance_types
  capacity_type  = var.capacity_type
  disk_size      = var.disk_size

  update_config {
    max_unavailable = var.max_unavailable
  }

  tags = merge(
    var.tags,
    var.node_tags,
    {
      ResourceType = "eks-node-group"
      Service      = "eks"
      InstanceType = join(",", var.instance_types)
      CapacityType = var.capacity_type
    }
  )

  depends_on = [aws_eks_cluster.this]
}
