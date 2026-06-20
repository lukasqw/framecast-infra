# Local Values
locals {
  # FinOps Tags — AWS Tagging Best Practices
  finops_tags = {
    Environment  = var.environment
    Project      = var.project_name
    Application  = var.application
    Microservice = var.microservice

    CostCenter   = var.cost_center
    BusinessUnit = var.business_unit
    BudgetCode   = var.budget_code != "" ? var.budget_code : "not-set"

    Owner     = var.owner
    ManagedBy = "Terraform"
    IaC       = "true"

    CreatedDate    = formatdate("YYYY-MM-DD", timestamp())
    ExpirationDate = var.expiration_date != "" ? var.expiration_date : "permanent"

    DataClassification = "internal"
    Compliance         = "required"
  }

  common_tags = local.finops_tags

  # LabRole ARN (AWS Academy)
  lab_role_arn = var.lab_role != "" ? var.lab_role : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"

  # Caller identity (aws-auth / EKS Access Entries)
  raw_caller_arn    = data.aws_caller_identity.current.arn
  is_assumed_role   = can(regex(":assumed-role/", local.raw_caller_arn))
  assumed_role_name = local.is_assumed_role ? element(split("/", local.raw_caller_arn), length(split("/", local.raw_caller_arn)) - 2) : ""
  caller_arn        = local.is_assumed_role ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.assumed_role_name}" : local.raw_caller_arn
  caller_username   = element(split("/", local.caller_arn), length(split("/", local.caller_arn)) - 1)
  is_user           = can(regex(":user/", local.caller_arn))
  is_role           = can(regex(":role/", local.caller_arn)) || local.is_assumed_role
  account_id        = data.aws_caller_identity.current.account_id

  # Subnets em us-east-1a e us-east-1b (mínimo 2 AZs para EKS)
  filtered_subnet_ids = [
    for subnet in data.aws_subnet.selected : subnet.id
    if contains(["${var.aws_region}a", "${var.aws_region}b"], subnet.availability_zone)
  ]

  primary_subnet_id = [
    for subnet in data.aws_subnet.selected : subnet.id
    if subnet.availability_zone == "${var.aws_region}a"
  ][0]
}
