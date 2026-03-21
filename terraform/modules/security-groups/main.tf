# Security Groups Module
resource "aws_security_group" "eks" {
  name        = "${var.name_prefix}-eks-sg"
  description = "Security group for EKS cluster"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name         = "${var.name_prefix}-eks-sg"
      ResourceType = "security-group"
      Service      = "ec2"
      Purpose      = "eks-cluster"
    }
  )
}

resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name         = "${var.name_prefix}-rds-sg"
      ResourceType = "security-group"
      Service      = "ec2"
      Purpose      = "rds-database"
    }
  )
}

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name         = "${var.name_prefix}-alb-sg"
      ResourceType = "security-group"
      Service      = "ec2"
      Purpose      = "application-load-balancer"
    }
  )
}

# EKS Security Group Rules
resource "aws_vpc_security_group_ingress_rule" "eks_https" {
  security_group_id = aws_security_group.eks.id
  description       = "Allow HTTPS from anywhere"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "eks_all" {
  security_group_id = aws_security_group.eks.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# RDS Security Group Rules
resource "aws_vpc_security_group_ingress_rule" "rds_from_eks" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL from EKS"
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.eks.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_vpc" {
  security_group_id = aws_security_group.rds.id
  description       = "PostgreSQL from VPC"
  from_port         = var.rds_port
  to_port           = var.rds_port
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_egress_rule" "rds_all" {
  security_group_id = aws_security_group.rds.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ALB Security Group Rules
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from anywhere"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from anywhere"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
