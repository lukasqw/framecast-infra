resource "datadog_dashboard" "overview" {
  title       = "Framecast - Overview"
  description = "Visão consolidada: latência da API, processamento de vídeo, recursos K8s e saúde do sistema"
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
    name             = "kube_deployment"
    prefix           = "kube_deployment"
    available_values = ["framecast-api", "framecast-worker"]
    defaults         = ["framecast-api", "framecast-worker"]
  }

  # ================================================================
  # GRUPO 1 — Latência da framecast-api
  # ================================================================
  widget {
    group_definition {
      title            = "Latência — framecast-api"
      background_color = "vivid_blue"
      show_title       = true
      layout_type      = "ordered"

      widget {
        timeseries_definition {
          title          = "Latencia HTTP p50 / p95 / p99"
          show_legend    = true
          legend_layout  = "auto"
          legend_columns = ["avg", "min", "max", "value", "sum"]

          request {
            formula {
              alias              = "p50"
              formula_expression = "p50_lat"
            }
            query {
              metric_query {
                name  = "p50_lat"
                query = "p50:trace.http.server.request{service:framecast-api,$env}"
              }
            }
            display_type = "line"
            style {
              palette    = "green"
              line_width = "normal"
            }
          }

          request {
            formula {
              alias              = "p95"
              formula_expression = "p95_lat"
            }
            query {
              metric_query {
                name  = "p95_lat"
                query = "p95:trace.http.server.request{service:framecast-api,$env}"
              }
            }
            display_type = "line"
            style {
              palette    = "orange"
              line_width = "normal"
            }
          }

          request {
            formula {
              alias              = "p99"
              formula_expression = "p99_lat"
            }
            query {
              metric_query {
                name  = "p99_lat"
                query = "p99:trace.http.server.request{service:framecast-api,$env}"
              }
            }
            display_type = "line"
            style {
              palette    = "red"
              line_width = "normal"
            }
          }

          yaxis {
            include_zero = true
            label        = ""
            min          = "0"
          }
        }
      }

      widget {
        query_value_definition {
          title     = "Latencia p95 atual"
          autoscale = true
          precision = 3

          request {
            formula { formula_expression = "p95_now" }
            query {
              metric_query {
                name       = "p95_now"
                query      = "p95:trace.http.server.request{service:framecast-api,$env}"
                aggregator = "last"
              }
            }
            conditional_formats {
              comparator = "<"
              hide_value = false
              palette    = "white_on_green"
              value      = 1
            }
            conditional_formats {
              comparator = "<"
              hide_value = false
              palette    = "white_on_yellow"
              value      = 2
            }
            conditional_formats {
              comparator = ">="
              hide_value = false
              palette    = "white_on_red"
              value      = 2
            }
          }
        }
      }

      widget {
        timeseries_definition {
          title         = "Throughput (req/s) por rota"
          show_legend   = true
          legend_layout = "auto"

          request {
            formula {
              alias              = "Req/s"
              formula_expression = "req_rate"
            }
            query {
              metric_query {
                name  = "req_rate"
                query = "sum:trace.http.server.request.hits{service:framecast-api,$env} by {resource_name}.as_rate()"
              }
            }
            display_type = "line"
            style {
              palette    = "cool"
              line_width = "normal"
            }
          }
        }
      }
    }
  }

  # ================================================================
  # GRUPO 2 — Pipeline de Vídeo (framecast-worker)
  # ================================================================
  widget {
    group_definition {
      title            = "Pipeline de Vídeo — framecast-worker"
      background_color = "vivid_green"
      show_title       = true
      layout_type      = "ordered"

      widget {
        timeseries_definition {
          title         = "Videos processados (total)"
          show_legend   = true
          legend_layout = "auto"

          request {
            formula {
              alias              = "Processados"
              formula_expression = "done"
            }
            query {
              metric_query {
                name  = "done"
                query = "sum:framecast.video.processed.total{service:framecast-worker,$env}.as_count()"
              }
            }
            display_type = "bars"
            style { palette = "green" }
          }
        }
      }

      widget {
        query_value_definition {
          title     = "Mensagens SQS Recebidas"
          autoscale = true
          precision = 0

          request {
            formula { formula_expression = "dlq" }
            query {
              metric_query {
                name       = "dlq"
                query      = "sum:framecast.worker.sqs.messages.received{service:framecast-worker,$env}.as_count()"
                aggregator = "sum"
              }
            }
            conditional_formats {
              comparator = "<="
              hide_value = false
              palette    = "white_on_green"
              value      = 0
            }
            conditional_formats {
              comparator = ">"
              hide_value = false
              palette    = "white_on_red"
              value      = 0
            }
          }
        }
      }

      widget {
        timeseries_definition {
          title          = "Duração do processamento p95 (segundos)"
          show_legend    = true
          legend_layout  = "auto"
          legend_columns = ["avg", "min", "max", "value", "sum"]

          request {
            formula {
              alias              = "p95 processamento"
              formula_expression = "p95_proc"
            }
            query {
              metric_query {
                name  = "p95_proc"
                query = "p95:framecast.video.processing.duration{service:framecast-worker,status:done}"
              }
            }
            display_type = "line"
            style { palette = "orange" }
          }
        }
      }

      widget {
        timeseries_definition {
          title          = "FFmpeg encoding p50 / p95 (segundos)"
          show_legend    = true
          legend_layout  = "auto"
          legend_columns = ["avg", "min", "max", "value"]

          request {
            formula {
              alias              = "p50"
              formula_expression = "p50_ffmpeg"
            }
            formula {
              alias              = "p95"
              formula_expression = "p95_ffmpeg"
            }
            query {
              metric_query {
                name  = "p50_ffmpeg"
                query = "p50:framecast.ffmpeg.duration{service:framecast-worker,$env}"
              }
            }
            query {
              metric_query {
                name  = "p95_ffmpeg"
                query = "p95:framecast.ffmpeg.duration{service:framecast-worker,$env}"
              }
            }
            display_type = "line"
            style {
              palette    = "purple"
              line_width = "normal"
            }
          }
        }
      }
    }
  }

  # ================================================================
  # GRUPO 3 — Recursos Kubernetes
  # ================================================================
  widget {
    group_definition {
      title            = "Recursos Kubernetes — namespace framecast"
      background_color = "vivid_purple"
      show_title       = true
      layout_type      = "ordered"

      widget {
        timeseries_definition {
          title          = "CPU Usage (% do limite) por deployment"
          show_legend    = true
          legend_layout  = "auto"
          legend_columns = ["avg", "min", "max", "value", "sum"]

          request {
            formula {
              alias              = "CPU %"
              formula_expression = "(cpu_usage / cpu_limit) * 100"
            }
            query {
              metric_query {
                name  = "cpu_usage"
                query = "avg:kubernetes.cpu.usage.total{kube_namespace:framecast,$kube_deployment} by {kube_deployment}"
              }
            }
            query {
              metric_query {
                name  = "cpu_limit"
                query = "avg:kubernetes.cpu.limits{kube_namespace:framecast,$kube_deployment} by {kube_deployment}"
              }
            }
            display_type = "line"
            style {
              palette    = "warm"
              line_width = "normal"
            }
          }

          yaxis {
            include_zero = true
            scale        = "linear"
            min          = "auto"
            max          = "auto"
          }
        }
      }

      widget {
        timeseries_definition {
          title         = "Pods em execucao por deployment"
          show_legend   = true
          legend_layout = "auto"

          request {
            formula {
              alias              = "Pods"
              formula_expression = "pods"
            }
            query {
              metric_query {
                name  = "pods"
                query = "sum:kubernetes.pods.running{kube_namespace:framecast,$kube_deployment} by {kube_deployment}"
              }
            }
            display_type = "area"
            style {
              palette    = "green"
              line_width = "thin"
            }
          }

          yaxis {
            include_zero = true
            min          = "0"
          }
        }
      }

      widget {
        timeseries_definition {
          title          = "Restarts de containers por deployment"
          show_legend    = true
          legend_layout  = "auto"
          legend_columns = ["avg", "min", "max", "value", "sum"]

          request {
            formula {
              alias              = "Restarts"
              formula_expression = "restarts"
            }
            query {
              metric_query {
                name  = "restarts"
                query = "sum:kubernetes.containers.restarts{kube_namespace:framecast,$kube_deployment} by {kube_deployment}"
              }
            }
            display_type = "bars"
            style { palette = "red" }
          }
        }
      }

      widget {
        timeseries_definition {
          title          = "Memory Usage (% do limite) por deployment"
          show_legend    = true
          legend_layout  = "auto"
          legend_columns = ["avg", "min", "max", "value", "sum"]

          request {
            formula {
              alias              = "Memory %"
              formula_expression = "(mem_usage / mem_limit) * 100"
            }
            query {
              metric_query {
                name  = "mem_usage"
                query = "avg:kubernetes.memory.usage{kube_namespace:framecast,$kube_deployment} by {kube_deployment}"
              }
            }
            query {
              metric_query {
                name  = "mem_limit"
                query = "avg:kubernetes.memory.limits{kube_namespace:framecast,$kube_deployment} by {kube_deployment}"
              }
            }
            display_type = "line"
            style {
              palette    = "cool"
              line_width = "normal"
            }
          }

          yaxis {
            include_zero = true
            min          = "0"
            max          = "100"
          }
        }
      }
    }
  }

  # ================================================================
  # GRUPO 4 — Erros e Disponibilidade
  # ================================================================
  widget {
    group_definition {
      title            = "Erros e Disponibilidade"
      background_color = "vivid_red"
      show_title       = true
      layout_type      = "ordered"

      widget {
        query_value_definition {
          title       = "Availability (% 2xx)"
          autoscale   = false
          custom_unit = "%"
          precision   = 2

          request {
            formula {
              alias              = "Availability %"
              formula_expression = "(success / total) * 100"
            }
            query {
              metric_query {
                name       = "success"
                query      = "sum:trace.http.server.request.hits.by_http_status{service:framecast-api,http.status_class:2xx,$env}.as_count()"
                aggregator = "sum"
              }
            }
            query {
              metric_query {
                name       = "total"
                query      = "sum:trace.http.server.request.hits{service:framecast-api,$env}.as_count()"
                aggregator = "sum"
              }
            }
            conditional_formats {
              comparator = ">="
              hide_value = false
              palette    = "white_on_green"
              value      = 99
            }
            conditional_formats {
              comparator = ">="
              hide_value = false
              palette    = "white_on_yellow"
              value      = 95
            }
            conditional_formats {
              comparator = "<"
              hide_value = false
              palette    = "white_on_red"
              value      = 95
            }
          }
        }
      }

      widget {
        timeseries_definition {
          title          = "Taxa de erros 4xx + 5xx (%)"
          show_legend    = true
          legend_layout  = "auto"
          legend_columns = ["avg", "min", "max", "value", "sum"]

          request {
            formula {
              alias              = "Error Rate %"
              formula_expression = "(errors / total) * 100"
            }
            query {
              metric_query {
                name  = "errors"
                query = "sum:trace.http.server.request.hits.by_http_status{service:framecast-api,http.status_class:4xx,$env}.as_count()"
              }
            }
            query {
              metric_query {
                name  = "total"
                query = "sum:trace.http.server.request.hits{service:framecast-api,$env}.as_count()"
              }
            }
            display_type = "line"
            style {
              palette    = "red"
              line_width = "normal"
            }
          }
        }
      }
    }
  }
}
