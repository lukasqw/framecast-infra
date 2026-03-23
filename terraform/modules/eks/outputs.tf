output "cluster_id" {
  description = "ID do cluster EKS"
  value       = aws_eks_cluster.this.id
}

output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint do cluster EKS"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_arn" {
  description = "ARN do cluster EKS"
  value       = aws_eks_cluster.this.arn
}

output "cluster_certificate_authority_data" {
  description = "Certificado CA do cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "cluster_version" {
  description = "Versão do Kubernetes"
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "Security group do cluster"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_group_id" {
  description = "ID do node group"
  value       = aws_eks_node_group.this.id
}

output "node_group_arn" {
  description = "ARN do node group"
  value       = aws_eks_node_group.this.arn
}

output "node_group_status" {
  description = "Status do node group"
  value       = aws_eks_node_group.this.status
}

output "node_group_asg_name" {
  description = "Nome do Auto Scaling Group do managed node group"
  value       = aws_eks_node_group.this.resources[0].autoscaling_groups[0].name
}
