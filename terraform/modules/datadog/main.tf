# Datadog Monitors — framecast
# Métricas emitidas via OTel SDK (delta temporality) → Datadog Agent OTLP gRPC

# ------------------------------------------------------------
# Monitor 1: Alta latência HTTP na api (p95 > 2s)
# ------------------------------------------------------------
resource "datadog_monitor" "high_api_latency" {
  name    = "[framecast] High API Latency (p95)"
  type    = "metric alert"
  message = "P95 de latência HTTP da framecast-api excedeu 2 segundos. @slack-oncall"

  query = "percentile(last_5m):p95:http.server.request.duration{service:framecast-api} > 2"

  monitor_thresholds {
    critical          = 2
    critical_recovery = 1.5
    warning           = 1
    warning_recovery  = 0.8
  }

  notify_no_data    = false
  renotify_interval = 60

  tags = ["service:framecast-api", "env:production", "team:backend"]
}

# ------------------------------------------------------------
# Monitor 2: Alta taxa de erros 5xx na api
# ------------------------------------------------------------
resource "datadog_monitor" "high_error_rate" {
  name    = "[framecast] High 5xx Error Rate"
  type    = "metric alert"
  message = "Taxa de erros 5xx da framecast-api excedeu 5% nos últimos 5 minutos. @slack-oncall"

  query = "sum(last_5m):(sum:http.server.request.count{service:framecast-api,status_code:5*}.as_rate() / sum:http.server.request.count{service:framecast-api}.as_rate()) * 100 > 5"

  monitor_thresholds {
    critical          = 5
    critical_recovery = 2
    warning           = 2
    warning_recovery  = 1
  }

  notify_no_data    = false
  renotify_interval = 30

  tags = ["service:framecast-api", "env:production", "team:backend"]
}

# ------------------------------------------------------------
# Monitor 3: Falhas no processamento de vídeo (worker)
# Métrica: video.processed.total{status:error}
# ------------------------------------------------------------
resource "datadog_monitor" "video_processing_errors" {
  name    = "[framecast] Video Processing Errors"
  type    = "metric alert"
  message = "Mais de 3 vídeos falharam no processamento nos últimos 5 minutos. Verifique logs do framecast-worker. @slack-oncall"

  query = "sum(last_5m):sum:video.processed.total{service:framecast-worker,status:error}.as_count() > 3"

  monitor_thresholds {
    critical          = 3
    critical_recovery = 0
    warning           = 1
    warning_recovery  = 0
  }

  notify_no_data    = false
  renotify_interval = 30

  tags = ["service:framecast-worker", "env:production", "team:backend"]
}

# ------------------------------------------------------------
# Monitor 4: Tempo de processamento de vídeo elevado (p95 > 20min)
# Métrica: video.processing.duration{status:done}
# ------------------------------------------------------------
resource "datadog_monitor" "video_processing_duration" {
  name    = "[framecast] Video Processing Duration High (p95)"
  type    = "metric alert"
  message = "P95 de duração de processamento de vídeo excedeu 20 minutos. Pode indicar fila represada ou problema de recursos. @slack-oncall"

  query = "percentile(last_15m):p95:video.processing.duration{service:framecast-worker} > 1200"

  monitor_thresholds {
    critical          = 1200  # 20 min
    critical_recovery = 900
    warning           = 600   # 10 min
    warning_recovery  = 480
  }

  notify_no_data    = false
  renotify_interval = 60

  tags = ["service:framecast-worker", "env:production", "team:backend"]
}

# ------------------------------------------------------------
# Monitor 5: Fila SQS crescendo (mensagens visíveis)
# Indica worker não está consumindo — pode estar travado
# ------------------------------------------------------------
resource "datadog_monitor" "sqs_queue_depth" {
  name    = "[framecast] SQS Queue Depth High"
  type    = "metric alert"
  message = "Fila framecast-processing com mais de 50 mensagens visíveis. Worker pode estar travado ou sem réplicas suficientes. @slack-oncall"

  query = "avg(last_5m):avg:aws.sqs.approximate_number_of_messages_visible{queuename:framecast-processing} > 50"

  monitor_thresholds {
    critical          = 50
    critical_recovery = 20
    warning           = 20
    warning_recovery  = 10
  }

  notify_no_data    = false
  renotify_interval = 60

  tags = ["service:framecast-worker", "env:production", "team:backend"]
}

# ------------------------------------------------------------
# Monitor 6: Mensagens na DLQ (indica falhas não-retentáveis)
# ------------------------------------------------------------
resource "datadog_monitor" "sqs_dlq_messages" {
  name    = "[framecast] Messages in DLQ"
  type    = "metric alert"
  message = "Mensagens detectadas na framecast-processing-dlq. Vídeos falharam após 3 tentativas — investigar. @slack-oncall"

  query = "avg(last_5m):avg:aws.sqs.approximate_number_of_messages_visible{queuename:framecast-processing-dlq} > 0"

  monitor_thresholds {
    critical = 0
  }

  notify_no_data    = false
  renotify_interval = 30

  tags = ["service:framecast-worker", "env:production", "team:backend"]
}

# ------------------------------------------------------------
# Monitor 7: Pods com alta taxa de restart
# ------------------------------------------------------------
resource "datadog_monitor" "pod_restarts" {
  name    = "[framecast] High Pod Restart Rate"
  type    = "metric alert"
  message = "Deployment framecast teve mais de 2 restarts de container nos últimos 5 minutos. @slack-oncall"

  query = "change(sum(last_5m),last_5m):sum:kubernetes.containers.restarts{kube_namespace:framecast} > 2"

  monitor_thresholds {
    critical          = 2
    critical_recovery = 0
    warning           = 1
    warning_recovery  = 0
  }

  notify_no_data    = false
  renotify_interval = 30

  tags = ["env:production", "namespace:framecast", "team:backend"]
}

# ------------------------------------------------------------
# Monitor 8: Alto uso de CPU
# ------------------------------------------------------------
resource "datadog_monitor" "high_cpu" {
  name    = "[framecast] High CPU Usage"
  type    = "metric alert"
  message = "Namespace framecast com uso de CPU acima de 85% dos limites. @slack-oncall"

  query = "avg(last_10m):(avg:kubernetes.cpu.usage.total{kube_namespace:framecast} / avg:kubernetes.cpu.limits{kube_namespace:framecast}) * 100 > 85"

  monitor_thresholds {
    critical          = 85
    critical_recovery = 75
    warning           = 70
    warning_recovery  = 60
  }

  notify_no_data    = false
  renotify_interval = 60

  tags = ["env:production", "namespace:framecast", "team:backend"]
}
