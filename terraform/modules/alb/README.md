# ALB Module

Módulo Terraform para provisionar um Application Load Balancer.

## Recursos Criados

- Application Load Balancer
- Target Group
- HTTP Listener

## Uso

```hcl
module "alb" {
  source = "../../modules/alb"

  name            = "my-alb"
  security_groups = [module.security_groups.alb_security_group_id]
  subnets         = module.vpc.public_subnet_ids
  vpc_id          = module.vpc.vpc_id

  target_group_port     = 80
  target_group_protocol = "HTTP"
  target_type           = "ip"

  health_check_path = "/health"

  tags = {
    Environment = "production"
    Project     = "my-project"
  }
}
```

## Variáveis

Ver `variables.tf` para lista completa de variáveis configuráveis.

## Outputs

Ver `outputs.tf` para lista completa de outputs disponíveis.
