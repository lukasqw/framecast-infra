# Provider Configuration

provider "aws" {
  region = var.aws_region
}

# Helm e Kubernetes providers apontam para o cluster EKS.
# Usa exec em vez de token estático: gera um token STS fresco a cada chamada,
# evitando expiração durante applies longos (ex: NLB leva ~3min para criar).
# ATENÇÃO: requerem que o cluster já exista — ver README §Deploy em dois passos
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.project_name, "--region", var.aws_region]
    }
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.project_name, "--region", var.aws_region]
  }
}

provider "datadog" {
  api_key  = var.datadog_api_key
  app_key  = var.datadog_app_key
  api_url  = var.datadog_api_url
  validate = false
}
