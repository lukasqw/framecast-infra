# KEDA — Kubernetes Event-Driven Autoscaling
# Escala o framecast-worker com base no comprimento da fila SQS

resource "helm_release" "keda" {
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  set {
    name  = "watchNamespace"
    value = ""
  }

  timeout = 600
}
