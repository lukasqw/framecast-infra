# metrics-server — habilita HPA baseado em CPU/memória para a framecast-api

resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = false

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  timeout = 300
}
