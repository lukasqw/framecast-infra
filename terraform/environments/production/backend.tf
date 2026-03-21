# Backend Configuration
terraform {
  backend "s3" {
    bucket = "fiap-soat-tf-backend-bispo-730335587750"
    key    = "fiap/infra/terraform.tfstate"
    region = "us-east-1"
  }
}
