# Provider Configuration

provider "aws" {
  region = var.aws_region
}

# Helm e Kubernetes providers apontam para o cluster EKS
# ATENÇÃO: requerem que o cluster já exista — ver README §Deploy em dois passos
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "datadog" {
  api_key  = var.datadog_api_key
  app_key  = var.datadog_app_key
  api_url  = var.datadog_api_url
  validate = false
}
