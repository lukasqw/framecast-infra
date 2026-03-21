output "alb_id" {
  description = "ID do ALB"
  value       = aws_lb.this.id
}

output "alb_arn" {
  description = "ARN do ALB"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "DNS name do ALB"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Zone ID do ALB"
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "ARN do target group"
  value       = aws_lb_target_group.this.arn
}

output "target_group_id" {
  description = "ID do target group"
  value       = aws_lb_target_group.this.id
}

output "listener_arn" {
  description = "ARN do listener HTTP"
  value       = aws_lb_listener.http.arn
}
