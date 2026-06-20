# Security Groups Module

resource "aws_security_group" "eks" {
  name        = "${var.name_prefix}-eks-sg"
  description = "Security group for EKS cluster"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name         = "${var.name_prefix}-eks-sg"
    ResourceType = "security-group"
    Service      = "ec2"
    Purpose      = "eks-cluster"
  })
}

resource "aws_vpc_security_group_ingress_rule" "eks_https" {
  security_group_id = aws_security_group.eks.id
  description       = "Allow HTTPS from anywhere"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# NodePort 30080 — framecast-api (NLB → nodes)
resource "aws_vpc_security_group_ingress_rule" "eks_nodeport" {
  security_group_id = aws_security_group.eks.id
  description       = "Allow NLB to reach NodePort 30080 (framecast-api)"
  from_port         = 30080
  to_port           = 30080
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "eks_all" {
  security_group_id = aws_security_group.eks.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
