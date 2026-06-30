resource "datadog_dashboard" "video_pipeline" {
  title       = "Framecast - Video Processing Pipeline"
  description = "Pipeline de processamento de video Framecast: visao end-to-end do fluxo desde o upload na API ate a geracao de frames pelo worker. Inclui metricas de fila SQS, FFmpeg, throughput e erros."
  layout_type = "ordered"
  reflow_type = "auto"

  tags = ["team:backend", "ai:modified_with_ai"]

  template_variable {
    name             = "env"
    prefix           = "env"
    available_values = ["production"]
    defaults         = ["production"]
  }

  template_variable {
    name             = "version"
    prefix           = "version"
    available_values = []
    defaults         = ["*"]
  }

  template_variable {
    name             = "kube_node"
    prefix           = "kube_node"
    available_values = ["ip-172-31-10-82.ec2.internal", "ip-172-31-33-239.ec2.internal"]
    defaults         = ["*"]
  }

  # ================================================================
  # GRUPO 1 — Overview
  # ================================================================
  widget {
    group_definition {
      title            = "Overview"
      background_color = "vivid_blue"
      show_title       = true
      layout_type      = "ordered"

      widget {
        query_value_definition {
          title     = "Videos Processados (total)"
          autoscale = true
          precision = 0

          request {
            formula { formula_expression = "total" }
            query {
              metric_query {
                name       = "total"
                query      = "sum:framecast.video.processed.total{status:done}.as_count()"
                aggregator = "sum"
              }
            }
            response_format = "scalar"
            conditional_formats {
              comparator = ">"
              value      = 0
              palette    = "white_on_green"
            }
          }
        }
      }

      widget {
        query_value_definition {
          title     = "Taxa de Processamento/min"
          autoscale = true
          precision = 1

          request {
            formula { formula_expression = "per_minute(rate)" }
            query {
              metric_query {
                name  = "rate"
                query = "sum:framecast.video.processed.total{$env,$version,$kube_node,status:done}.as_rate()"
              }
            }
            response_format = "scalar"
          }
        }
      }

      widget {
        query_value_definition {
          title     = "Duracao p50 (processamento)"
          autoscale = true
          precision = 2

          request {
            formula { formula_expression = "dur" }
            query {
              metric_query {
                name  = "dur"
                query = "p50:framecast.video.processing.duration{$env,$version,$kube_node,status:done}"
              }
            }
            response_format = "scalar"
          }
        }
      }

      widget {
        query_value_definition {
          title     = "Mensagens SQS Recebidas"
          autoscale = true
          precision = 0

          request {
            formula { formula_expression = "msgs" }
            query {
              metric_query {
                name       = "msgs"
                query      = "sum:framecast.worker.sqs.messages.received{$env,$version,$kube_node}.as_count()"
                aggregator = "sum"
              }
            }
            response_format = "scalar"
            conditional_formats {
              comparator = ">"
              value      = 0
              palette    = "white_on_green"
            }
          }
        }
      }
    }
  }

  # ================================================================
  # GRUPO 2 — API Ingestion
  # ================================================================
  widget {
    group_definition {
      title            = "API - Ingestion"
      background_color = "vivid_purple"
      show_title       = true
      layout_type      = "ordered"

      widget {
        timeseries_definition {
          title         = "SQS Publish (API -> Fila)"
          show_legend   = true
          legend_layout = "auto"

          request {
            formula {
              alias              = "Mensagens publicadas"
              formula_expression = "pub"
            }
            query {
              metric_query {
                name  = "pub"
                query = "sum:trace.aws_sqs.publish.hits{service:framecast-api,$env}.as_count()"
              }
            }
            response_format = "timeseries"
            display_type    = "bars"
            style { palette = "orange" }
          }
        }
      }

      widget {
        timeseries_definition {
          title         = "API Error Rate"
          show_legend   = true
          legend_layout = "auto"

          request {
            formula {
              alias              = "Error Rate %"
              formula_expression = "errs"
            }
            query {
              apm_resource_stats_query {
                name        = "errs"
                data_source = "apm_resource_stats"
                service     = "framecast-api"
                stat        = "error_rate"
                env         = "$env"
                span_kind   = "server"
              }
            }
            response_format = "timeseries"
            display_type    = "line"
            style { palette = "red" }
          }

          marker {
            label        = "5% threshold"
            value        = "y = 0.05"
            display_type = "warning dashed"
          }
        }
      }
    }
  }

  # ================================================================
  # GRUPO 3 — Worker Processamento
  # ================================================================
  widget {
    group_definition {
      title            = "Worker - Processamento"
      background_color = "vivid_green"
      show_title       = true
      layout_type      = "ordered"

      widget {
        timeseries_definition {
          title         = "Videos Processados com Sucesso"
          show_legend   = true
          legend_layout = "auto"

          request {
            formula {
              alias              = "Videos concluidos"
              formula_expression = "done"
            }
            query {
              metric_query {
                name  = "done"
                query = "sum:framecast.video.processed.total{$env,$version,$kube_node,status:done}.as_count()"
              }
            }
            response_format = "timeseries"
            display_type    = "bars"
            style { palette = "green" }
          }
        }
      }

      widget {
        timeseries_definition {
          title         = "Mensagens SQS Recebidas pelo Worker (rate/min)"
          show_legend   = true
          legend_layout = "auto"

          request {
            formula {
              alias              = "Mensagens/min"
              formula_expression = "per_minute(msgs)"
            }
            query {
              metric_query {
                name  = "msgs"
                query = "sum:framecast.worker.sqs.messages.received{$env,$version,$kube_node}.as_rate()"
              }
            }
            response_format = "timeseries"
            display_type    = "bars"
            style { palette = "orange" }
          }
        }
      }

      widget {
        timeseries_definition {
          title         = "Frames Gerados por Video (media)"
          show_legend   = true
          legend_layout = "auto"

          request {
            formula {
              alias              = "Media de frames"
              formula_expression = "frames"
            }
            query {
              metric_query {
                name  = "frames"
                query = "avg:framecast.video.frame_count{$env,$version,$kube_node}"
              }
            }
            response_format = "timeseries"
            display_type    = "line"
            style { palette = "purple" }
          }
        }
      }

      widget {
        timeseries_definition {
          title         = "Videos Processados by Node"
          show_legend   = true
          legend_layout = "auto"

          request {
            formula { formula_expression = "bynode" }
            query {
              metric_query {
                name  = "bynode"
                query = "sum:framecast.video.processed.total{$env,$version,$kube_node,status:done} by {kube_node}.as_count()"
              }
            }
            response_format = "timeseries"
            display_type    = "bars"
            style { palette = "semantic" }
          }
        }
      }
    }
  }

  # ================================================================
  # GRUPO 4 — Performance / Latencia
  # ================================================================
  widget {
    group_definition {
      title            = "Performance / Latencia"
      background_color = "vivid_orange"
      show_title       = true
      layout_type      = "ordered"

      widget {
        timeseries_definition {
          title          = "Duracao Total vs FFmpeg (p50 e p95)"
          show_legend    = true
          legend_layout  = "auto"
          legend_columns = ["avg", "min", "max", "value"]

          request {
            formula {
              alias              = "Total p50"
              formula_expression = "total_p50"
            }
            formula {
              alias              = "Total p95"
              formula_expression = "total_p95"
            }
            formula {
              alias              = "FFmpeg p50"
              formula_expression = "ffmpeg_p50"
            }
            formula {
              alias              = "FFmpeg p95"
              formula_expression = "ffmpeg_p95"
            }
            query {
              metric_query {
                name  = "total_p50"
                query = "p50:framecast.video.processing.duration{$env,$version,$kube_node,status:done}"
              }
            }
            query {
              metric_query {
                name  = "total_p95"
                query = "p95:framecast.video.processing.duration{$env,$version,$kube_node,status:done}"
              }
            }
            query {
              metric_query {
                name  = "ffmpeg_p50"
                query = "p50:framecast.ffmpeg.duration{$env,$version,$kube_node}"
              }
            }
            query {
              metric_query {
                name  = "ffmpeg_p95"
                query = "p95:framecast.ffmpeg.duration{$env,$version,$kube_node}"
              }
            }
            response_format = "timeseries"
            display_type    = "line"
          }

          yaxis {
            include_zero = true
            min          = "0"
          }
        }
      }

      widget {
        timeseries_definition {
          title         = "Overhead: Tempo Total - FFmpeg (p50)"
          show_legend   = true
          legend_layout = "auto"

          request {
            formula {
              alias              = "Overhead (S3 + ZIP + DB)"
              formula_expression = "total - ffmpeg"
            }
            query {
              metric_query {
                name  = "total"
                query = "p50:framecast.video.processing.duration{$env,$version,$kube_node,status:done}"
              }
            }
            query {
              metric_query {
                name  = "ffmpeg"
                query = "p50:framecast.ffmpeg.duration{$env,$version,$kube_node}"
              }
            }
            response_format = "timeseries"
            display_type    = "area"
            style { palette = "warm" }
          }

          yaxis {
            include_zero = true
            min          = "0"
          }
        }
      }

      widget {
        timeseries_definition {
          title         = "Worker Latencia p95 by Operation"
          show_legend   = true
          legend_layout = "auto"

          request {
            formula { formula_expression = "wlat" }
            query {
              apm_resource_stats_query {
                name        = "wlat"
                data_source = "apm_resource_stats"
                service     = "framecast-worker"
                stat        = "latency_p95"
                env         = "$env"
                group_by    = ["resource_name"]
                span_kind   = "internal"
              }
            }
            response_format = "timeseries"
            display_type    = "line"
            style { palette = "semantic" }
          }
        }
      }
    }
  }

  # ================================================================
  # GRUPO 5 — Erros e Logs
  # ================================================================
  widget {
    group_definition {
      title            = "Erros e Logs"
      background_color = "vivid_pink"
      show_title       = true
      layout_type      = "ordered"

      widget {
        timeseries_definition {
          title         = "Error Logs ao Longo do Tempo (framecast-worker)"
          show_legend   = true
          legend_layout = "auto"

          request {
            formula {
              alias              = "Erros"
              formula_expression = "errs"
            }
            query {
              event_query {
                data_source = "logs"
                name        = "errs"
                indexes     = ["*"]
                search { query = "service:framecast-worker status:error $env $version $kube_node" }
                compute { aggregation = "count" }
              }
            }
            response_format = "timeseries"
            display_type    = "bars"
            style { palette = "red" }
          }
        }
      }

      widget {
        timeseries_definition {
          title         = "Error Logs ao Longo do Tempo (framecast-api)"
          show_legend   = true
          legend_layout = "auto"

          request {
            formula {
              alias              = "Erros API"
              formula_expression = "api_errs"
            }
            query {
              event_query {
                data_source = "logs"
                name        = "api_errs"
                indexes     = ["*"]
                search { query = "service:framecast-api status:error $env $version $kube_node" }
                compute { aggregation = "count" }
              }
            }
            response_format = "timeseries"
            display_type    = "bars"
            style { palette = "orange" }
          }
        }
      }

      widget {
        list_stream_definition {
          title = "Log Stream - Erros do Pipeline"

          request {
            query {
              data_source  = "logs_stream"
              query_string = "(service:framecast-worker OR service:framecast-api) status:error $env $version $kube_node"
              indexes      = ["*"]
              sort {
                column = "timestamp"
                order  = "desc"
              }
            }
            columns { field = "status_line"; width = "auto" }
            columns { field = "timestamp";   width = "auto" }
            columns { field = "service";     width = "auto" }
            columns { field = "host";        width = "auto" }
            columns { field = "content";     width = "full" }
            response_format = "event_list"
          }
        }
      }
    }
  }
}
