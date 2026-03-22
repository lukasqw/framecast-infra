# Local Values
locals {
  # FinOps Tags - Seguindo AWS Tagging Best Practices
  finops_tags = {
    # Identificação
    Environment  = var.environment
    Project      = var.project_name
    Application  = var.application
    Microservice = var.microservice

    # Financeiro
    CostCenter   = var.cost_center
    BusinessUnit = var.business_unit
    BudgetCode   = var.budget_code != "" ? var.budget_code : "not-set"

    # Governança
    Owner     = var.owner
    ManagedBy = "Terraform"
    IaC       = "true"

    # Lifecycle
    CreatedDate    = formatdate("YYYY-MM-DD", timestamp())
    ExpirationDate = var.expiration_date != "" ? var.expiration_date : "permanent"

    # Compliance
    DataClassification = "internal"
    Compliance         = "required"
  }

  # Common tags (mantém compatibilidade)
  common_tags = local.finops_tags

  # Lab role ARN (AWS Academy)
  lab_role_arn = var.lab_role != "" ? var.lab_role : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"

  # Caller identity for aws-auth ConfigMap
  # Converter assumed-role ARN para role ARN (AWS Academy)
  # Exemplo: arn:aws:sts::123:assumed-role/voclabs/user123 -> arn:aws:iam::123:role/voclabs
  raw_caller_arn = data.aws_caller_identity.current.arn

  # Detectar se é assumed-role
  is_assumed_role = can(regex(":assumed-role/", local.raw_caller_arn))

  # Extrair o nome da role do assumed-role ARN
  # arn:aws:sts::123:assumed-role/voclabs/user123 -> voclabs
  assumed_role_name = local.is_assumed_role ? element(split("/", local.raw_caller_arn), length(split("/", local.raw_caller_arn)) - 2) : ""

  # Converter para role ARN se for assumed-role, senão usar o ARN original
  caller_arn = local.is_assumed_role ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.assumed_role_name}" : local.raw_caller_arn

  caller_username = element(split("/", local.caller_arn), length(split("/", local.caller_arn)) - 1)
  is_user         = can(regex(":user/", local.caller_arn))
  is_role         = can(regex(":role/", local.caller_arn)) || local.is_assumed_role
  account_id      = data.aws_caller_identity.current.account_id

  # Multiple subnets across AZs (required by AWS - minimum 2 AZs)
  # AWS requires at least 2 AZs for EKS, RDS, and ALB
  filtered_subnet_ids = [
    for subnet in data.aws_subnet.selected : subnet.id
    if contains(["${var.aws_region}a", "${var.aws_region}b"], subnet.availability_zone)
  ]

  # Primary subnet for single-AZ resources (cost optimization)
  primary_subnet_id = [
    for subnet in data.aws_subnet.selected : subnet.id
    if subnet.availability_zone == "${var.aws_region}a"
  ][0]

  # Database configuration
  db_name     = replace(lower(var.project_name), "-", "_")
  db_username = "postgres"
}
