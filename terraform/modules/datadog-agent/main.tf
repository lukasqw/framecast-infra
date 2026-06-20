# Datadog Agent — DaemonSet no EKS
# Recebe OTLP gRPC (porta 4317) da api e do worker (delta temporality)

resource "helm_release" "datadog_agent" {
  name             = "datadog"
  repository       = "https://helm.datadoghq.com"
  chart            = "datadog"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  set_sensitive {
    name  = "datadog.apiKey"
    value = var.datadog_api_key
  }

  set {
    name  = "datadog.site"
    value = var.datadog_site
  }

  set {
    name  = "datadog.clusterName"
    value = var.cluster_name
  }

  # OTLP gRPC — recebe traces/metrics dos serviços Go via OTel SDK
  set {
    name  = "datadog.otlp.receiver.protocols.grpc.enabled"
    value = "true"
  }

  set {
    name  = "datadog.otlp.receiver.protocols.grpc.endpoint"
    value = "0.0.0.0:${var.otlp_grpc_port}"
  }

  # APM + logs habilitados
  set {
    name  = "datadog.apm.portEnabled"
    value = "true"
  }

  set {
    name  = "datadog.logs.enabled"
    value = "true"
  }

  set {
    name  = "datadog.logs.containerCollectAll"
    value = "true"
  }

  timeout = 600
}
