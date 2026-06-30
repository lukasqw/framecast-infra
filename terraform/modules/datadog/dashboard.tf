resource "datadog_dashboard" "video_pipeline" {
  title       = "Framecast - Video Processing Pipeline"
  description = "Métricas do pipeline de processamento de vídeo: fila SQS, worker, FFmpeg e frames gerados"
  layout_type = "ordered"

  # ----------------------------------------------------------------
  # Widget 1: Vídeos processados (done vs error)
  # ----------------------------------------------------------------
  widget {
    timeseries_definition {
      title       = "Vídeos processados (done vs error)"
      show_legend = true

      request {
        formula {
          formula_expression = "done"
          alias              = "Done"
        }
        query {
          metric_query {
            name  = "done"
            query = "sum:framecast.video.processed.total{service:framecast-worker,status:done}.as_count()"
          }
        }
        display_type = "bars"
        style {
          palette = "green"
        }
      }

      request {
        formula {
          formula_expression = "err"
          alias              = "Error"
        }
        query {
          metric_query {
            name  = "err"
            query = "sum:framecast.video.processed.total{service:framecast-worker,status:error}.as_count()"
          }
        }
        display_type = "bars"
        style {
          palette = "red"
        }
      }
    }
  }

  # ----------------------------------------------------------------
  # Widget 2: Duração do processamento p50 / p95
  # ----------------------------------------------------------------
  widget {
    timeseries_definition {
      title       = "Duração de processamento (framecast.video.processing.duration)"
      show_legend = true

      request {
        formula {
          formula_expression = "p50_dur"
          alias              = "p50"
        }
        query {
          metric_query {
            name  = "p50_dur"
            query = "p50:framecast.video.processing.duration{service:framecast-worker,status:done}"
          }
        }
        display_type = "line"
        style { palette = "green" }
      }

      request {
        formula {
          formula_expression = "p95_dur"
          alias              = "p95"
        }
        query {
          metric_query {
            name  = "p95_dur"
            query = "p95:framecast.video.processing.duration{service:framecast-worker,status:done}"
          }
        }
        display_type = "line"
        style { palette = "orange" }
      }

      yaxis {
        label        = "Duração (s)"
        min          = "0"
        include_zero = true
      }

      marker {
        value        = "y = 600"
        display_type = "warning dashed"
        label        = "Warning 10min"
      }
      marker {
        value        = "y = 1200"
        display_type = "error dashed"
        label        = "Critical 20min"
      }
    }
  }

  # ----------------------------------------------------------------
  # Widget 3: Duração do FFmpeg p50 / p95
  # ----------------------------------------------------------------
  widget {
    timeseries_definition {
      title       = "Duração do FFmpeg (framecast.ffmpeg.duration)"
      show_legend = true

      request {
        formula {
          formula_expression = "ffmpeg_p50"
          alias              = "p50"
        }
        query {
          metric_query {
            name  = "ffmpeg_p50"
            query = "p50:framecast.ffmpeg.duration{service:framecast-worker}"
          }
        }
        display_type = "line"
        style { palette = "cool" }
      }

      request {
        formula {
          formula_expression = "ffmpeg_p95"
          alias              = "p95"
        }
        query {
          metric_query {
            name  = "ffmpeg_p95"
            query = "p95:framecast.ffmpeg.duration{service:framecast-worker}"
          }
        }
        display_type = "line"
        style { palette = "warm" }
      }

      yaxis {
        label        = "Duração (s)"
        min          = "0"
        include_zero = true
      }
    }
  }

  # ----------------------------------------------------------------
  # Widget 4: Frames gerados por processamento (distribuição)
  # ----------------------------------------------------------------
  widget {
    timeseries_definition {
      title       = "Frames gerados por vídeo (framecast.video.frame_count)"
      show_legend = true

      request {
        formula {
          formula_expression = "avg_frames"
          alias              = "Média de frames"
        }
        query {
          metric_query {
            name  = "avg_frames"
            query = "avg:framecast.video.frame_count{service:framecast-worker}"
          }
        }
        display_type = "line"
        style { palette = "purple" }
      }
    }
  }

  # ----------------------------------------------------------------
  # Widget 5: Throughput de mensagens SQS recebidas pelo worker
  # ----------------------------------------------------------------
  widget {
    timeseries_definition {
      title       = "Mensagens SQS recebidas pelo worker (rate/min)"
      show_legend = true

      request {
        formula {
          formula_expression = "msgs"
          alias              = "Mensagens/min"
        }
        query {
          metric_query {
            name  = "msgs"
            query = "sum:framecast.worker.sqs.messages.received{service:framecast-worker}.as_rate()"
          }
        }
        display_type = "bars"
        style { palette = "orange" }
      }
    }
  }

  tags = ["team:backend"]
}
