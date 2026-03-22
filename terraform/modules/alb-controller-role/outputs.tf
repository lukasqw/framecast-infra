output "role_arn" {
  description = "ARN da IAM Role do AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.arn
}

output "role_name" {
  description = "Nome da IAM Role do AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.name
}

output "policy_arn" {
  description = "ARN da IAM Policy do AWS Load Balancer Controller"
  value       = aws_iam_policy.alb_controller.arn
}
