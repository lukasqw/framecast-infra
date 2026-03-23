output "eks_security_group_id" {
  description = "ID do security group do EKS"
  value       = aws_security_group.eks.id
}
