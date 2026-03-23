output "nlb_id" {
  description = "ID do NLB"
  value       = aws_lb.this.id
}

output "nlb_arn" {
  description = "ARN do NLB"
  value       = aws_lb.this.arn
}

output "nlb_dns_name" {
  description = "DNS name do NLB"
  value       = aws_lb.this.dns_name
}

output "nlb_zone_id" {
  description = "Zone ID do NLB"
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
  description = "ARN do listener TCP"
  value       = aws_lb_listener.http.arn
}
