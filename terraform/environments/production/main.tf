# Main Configuration — Production Environment

# ── Rede & Segurança ────────────────────────────────────────────────────────

module "security_groups" {
  source = "../../modules/security-groups"

  name_prefix = var.project_name
  vpc_id      = data.aws_vpc.main.id

  tags = local.common_tags
}

# ── EKS ────────────────────────────────────────────────────────────────────

module "eks" {
  source = "../../modules/eks"

  cluster_name     = var.project_name
  cluster_version  = var.eks_cluster_version
  cluster_role_arn = local.lab_role_arn
  node_role_arn    = local.lab_role_arn

  subnet_ids         = local.filtered_subnet_ids
  security_group_ids = [module.security_groups.eks_security_group_id]

  authentication_mode = var.access_config

  node_group_name = var.node_group
  desired_size    = var.node_desired_size
  max_size        = var.node_max_size
  min_size        = var.node_min_size
  instance_types  = [var.instance_type]

  tags = local.common_tags

  node_tags = {
    Workload = "kubernetes-nodes"
    Scaling  = "auto"
  }
}

# Permite que o NLB alcance o NodePort 30080 no cluster SG gerenciado pelo EKS
resource "aws_vpc_security_group_ingress_rule" "eks_cluster_nodeport" {
  security_group_id = module.eks.cluster_security_group_id
  description       = "Allow NLB to reach NodePort 30080 (framecast-api)"
  from_port         = 30080
  to_port           = 30080
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-eks-nodeport"
    Purpose = "allow-nlb-to-eks-nodeport"
  })
}

# ── NLB — expõe a framecast-api via NodePort 30080 ─────────────────────────

module "nlb" {
  source = "../../modules/nlb"

  name     = "${var.project_name}-nlb"
  subnets  = local.filtered_subnet_ids
  vpc_id   = data.aws_vpc.main.id
  asg_name = module.eks.node_group_asg_name

  target_group_port = 30080
  health_check_path = "/health"

  tags = local.common_tags
}

# ── S3 — buckets de vídeos raw e output ────────────────────────────────────

module "s3" {
  source = "../../modules/s3"

  bucket_raw           = var.s3_bucket_raw
  bucket_output        = var.s3_bucket_output
  multipart_abort_days = var.s3_multipart_abort_days

  tags = local.common_tags
}

# ── SES — identidade de e-mail para notificações do worker ─────────────────

module "ses" {
  count  = var.enable_ses ? 1 : 0
  source = "../../modules/ses"

  from_email = var.ses_from_email
  domain     = var.ses_domain

  tags = local.common_tags
}

# ── SQS — fila de processamento + DLQ ──────────────────────────────────────
# visibility_timeout deve casar com o lease+heartbeat do worker (900s = 15min)

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-processing-dlq"
  message_retention_seconds = var.sqs_retention_seconds

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-processing-dlq"
    Purpose = "dead-letter-queue"
  })
}

resource "aws_sqs_queue" "processing" {
  name                       = "${var.project_name}-processing"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = var.sqs_retention_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-processing"
    Purpose = "video-processing"
  })
}

# ── Helm Controllers ────────────────────────────────────────────────────────

# KEDA: escala o framecast-worker por comprimento da fila SQS
module "keda" {
  count  = var.enable_keda ? 1 : 0
  source = "../../modules/keda"

  tags = local.common_tags

  depends_on = [module.eks]
}

# metrics-server: habilita HPA CPU/memória para a framecast-api
module "metrics_server" {
  count  = var.enable_metrics_server ? 1 : 0
  source = "../../modules/metrics-server"

  depends_on = [module.eks]
}

# Datadog Agent: DaemonSet com receptor OTLP gRPC (porta 4317)
module "datadog_agent" {
  count  = var.enable_datadog_agent && var.datadog_api_key != "" ? 1 : 0
  source = "../../modules/datadog-agent"

  datadog_api_key = var.datadog_api_key
  datadog_site    = "datadoghq.com"
  cluster_name    = var.project_name

  depends_on = [module.eks]
}

# ── Datadog Monitors (opcional) ─────────────────────────────────────────────

# module "datadog" {
#   source = "../../modules/datadog"
#   count  = var.datadog_api_key != "" ? 1 : 0
#
#   datadog_api_key = var.datadog_api_key
#   datadog_app_key = var.datadog_app_key
# }
