output "eks_security_group_id" {
  description = "ID do security group do EKS"
  value       = aws_security_group.eks.id
}

output "rds_security_group_id" {
  description = "ID do security group do RDS"
  value       = aws_security_group.rds.id
}

output "alb_security_group_id" {
  description = "ID do security group do ALB"
  value       = aws_security_group.alb.id
}
