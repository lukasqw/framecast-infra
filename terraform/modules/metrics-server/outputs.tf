output "release_name" {
  description = "Nome do Helm release do metrics-server"
  value       = helm_release.metrics_server.name
}

output "namespace" {
  description = "Namespace onde o metrics-server foi instalado"
  value       = helm_release.metrics_server.namespace
}
