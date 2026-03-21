# Application Load Balancer Module
resource "aws_lb" "this" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = var.security_groups
  subnets            = var.subnets

  enable_deletion_protection       = var.enable_deletion_protection
  enable_http2                     = var.enable_http2
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing

  tags = merge(
    var.tags,
    {
      Name             = var.name
      ResourceType     = "application-load-balancer"
      Service          = "elb"
      LoadBalancerType = "application"
      Internal         = tostring(var.internal)
    }
  )
}

resource "aws_lb_target_group" "this" {
  name        = "${var.name}-tg"
  port        = var.target_group_port
  protocol    = var.target_group_protocol
  vpc_id      = var.vpc_id
  target_type = var.target_type

  health_check {
    enabled             = true
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.health_check_path
    matcher             = var.health_check_matcher
  }

  deregistration_delay = var.deregistration_delay

  tags = merge(
    var.tags,
    {
      Name         = "${var.name}-tg"
      ResourceType = "target-group"
      Service      = "elb"
      TargetType   = var.target_type
      Protocol     = var.target_group_protocol
      Port         = tostring(var.target_group_port)
    }
  )
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
