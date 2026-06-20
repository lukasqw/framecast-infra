# Backend Configuration
terraform {
  backend "s3" {
    key = "framecast/infra/terraform.tfstate"
    # bucket e region fornecidos em tempo de execução via -backend-config
    # Configure TF_STATE_BUCKET como variável do repositório no GitHub Actions
  }
}
