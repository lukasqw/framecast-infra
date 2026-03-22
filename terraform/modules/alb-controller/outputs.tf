output "controller_release_name" {
  description = "Nome do Helm release do controller"
  value       = helm_release.aws_load_balancer_controller.name
}

output "controller_namespace" {
  description = "Namespace do controller"
  value       = helm_release.aws_load_balancer_controller.namespace
}

output "cert_manager_release_name" {
  description = "Nome do Helm release do cert-manager"
  value       = helm_release.cert_manager.name
}
