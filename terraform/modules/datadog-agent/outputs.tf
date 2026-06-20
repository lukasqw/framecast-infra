output "release_name" {
  description = "Nome do Helm release do Datadog Agent"
  value       = helm_release.datadog_agent.name
}

output "namespace" {
  description = "Namespace onde o Datadog Agent foi instalado"
  value       = helm_release.datadog_agent.namespace
}
