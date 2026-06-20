output "release_name" {
  description = "Nome do Helm release do KEDA"
  value       = helm_release.keda.name
}

output "namespace" {
  description = "Namespace onde o KEDA foi instalado"
  value       = helm_release.keda.namespace
}
