# Monitors específicos do pipeline de vídeo — framecast-worker
# Métricas registradas pelo worker (PLAN_WORKER §10):
#   video.processing.duration  histogram  status: done|error
#   video.processed.total      counter    status: done|error
#   video.frame_count          histogram
#   ffmpeg.duration            histogram

# ------------------------------------------------------------
# Monitor VP-1: Taxa de sucesso do processamento caiu
# Alerta se menos de 80% dos vídeos processados estão com status done
# ------------------------------------------------------------
resource "datadog_monitor" "video_success_rate_low" {
  name    = "[framecast] Video Processing Success Rate Low"
  type    = "metric alert"
  message = <<-EOT
    Taxa de sucesso no processamento de vídeos está abaixo de 80% nos últimos 15 minutos.
    Verifique logs do framecast-worker: erros de FFmpeg, S3 ou banco de dados.
    @slack-oncall
  EOT

  query = "sum(last_15m):(sum:video.processed.total{service:framecast-worker,status:done}.as_count() / (sum:video.processed.total{service:framecast-worker,status:done}.as_count() + sum:video.processed.total{service:framecast-worker,status:error}.as_count())) * 100 < 80"

  monitor_thresholds {
    critical          = 80
    critical_recovery = 90
    warning           = 90
    warning_recovery  = 95
  }

  notify_no_data    = false
  renotify_interval = 30

  tags = ["service:framecast-worker", "env:production", "team:backend"]
}

# ------------------------------------------------------------
# Monitor VP-2: FFmpeg demora muito (p95 > 15min)
# Pode indicar vídeos muito grandes ou recursos insuficientes
# ------------------------------------------------------------
resource "datadog_monitor" "ffmpeg_duration_high" {
  name    = "[framecast] FFmpeg Execution Duration High (p95)"
  type    = "metric alert"
  message = <<-EOT
    P95 de duração do FFmpeg excedeu 15 minutos nos últimos 30 minutos.
    Verifique se os vídeos estão muito grandes ou se os pods do worker têm CPU suficiente.
    @slack-oncall
  EOT

  query = "percentile(last_30m):p95:ffmpeg.duration{service:framecast-worker} > 900"

  monitor_thresholds {
    critical          = 900   # 15 min
    critical_recovery = 600
    warning           = 480   # 8 min
    warning_recovery  = 360
  }

  notify_no_data    = false
  renotify_interval = 60

  tags = ["service:framecast-worker", "env:production", "team:backend"]
}

# ------------------------------------------------------------
# Monitor VP-3: Nenhum vídeo processado (inatividade total)
# Detecta se o worker parou de processar completamente
# ------------------------------------------------------------
resource "datadog_monitor" "video_processing_stalled" {
  name    = "[framecast] Video Processing Stalled"
  type    = "metric alert"
  message = <<-EOT
    Nenhum vídeo foi processado nos últimos 30 minutos.
    Verifique se os pods do framecast-worker estão rodando e consumindo a fila SQS.
    @slack-oncall
  EOT

  query = "sum(last_30m):sum:video.processed.total{service:framecast-worker}.as_count() < 1"

  monitor_thresholds {
    critical          = 1
    critical_recovery = 2
  }

  notify_no_data    = true
  no_data_timeframe = 30
  renotify_interval = 60

  tags = ["service:framecast-worker", "env:production", "team:backend"]
}
