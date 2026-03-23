# Network Load Balancer Module
resource "aws_lb" "this" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = "network"
  subnets            = var.subnets

  enable_deletion_protection       = var.enable_deletion_protection
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing

  tags = merge(
    var.tags,
    {
      Name             = var.name
      ResourceType     = "network-load-balancer"
      Service          = "elb"
      LoadBalancerType = "network"
      Internal         = tostring(var.internal)
    }
  )
}

resource "aws_lb_target_group" "this" {
  name        = "${var.name}-tg"
  port        = var.target_group_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    interval            = var.health_check_interval
    port                = tostring(var.target_group_port)
    protocol            = "HTTP"
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
      TargetType   = "instance"
      Protocol     = "TCP"
      Port         = tostring(var.target_group_port)
    }
  )
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# Auto-registra todos os EC2 nodes do ASG no Target Group
resource "aws_autoscaling_attachment" "this" {
  autoscaling_group_name = var.asg_name
  lb_target_group_arn    = aws_lb_target_group.this.arn
}
