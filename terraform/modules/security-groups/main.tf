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

# Permitir que o NLB alcance os nodes nas NodePorts dos microsserviços (30080-30083)
resource "aws_vpc_security_group_ingress_rule" "eks_nodeport" {
  security_group_id = aws_security_group.eks.id
  description       = "Allow NLB to reach NodePorts 30080-30083 (ms-identity, ms-order, ms-workshop)"
  from_port         = 30080
  to_port           = 30083
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

