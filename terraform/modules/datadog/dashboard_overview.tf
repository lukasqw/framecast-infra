resource "datadog_dashboard" "overview" {
  title       = "Framecast - Overview"
  description = "Visão consolidada: latência da API, processamento de vídeo, recursos K8s e saúde do sistema"
  layout_type = "ordered"

  # ================================================================
  # SEÇÃO 1 — Latência da framecast-api
  # ================================================================
  widget {
    group_definition {
      title            = "Latência — framecast-api"
      layout_type      = "ordered"
      background_color = "vivid_blue"

      widget {
        timeseries_definition {
          title       = "Latência HTTP p50 / p95 / p99"
          show_legend = true

          request {
            formula { formula_expression = "p50_lat"; alias = "p50" }
            query {
              metric_query {
                name  = "p50_lat"
                query = "p50:http.server.request.duration{service:framecast-api,!http.route:/health}"
              }
            }
            display_type = "line"
            style { palette = "green"; line_width = "normal" }
          }

          request {
            formula { formula_expression = "p95_lat"; alias = "p95" }
            query {
              metric_query {
                name  = "p95_lat"
                query = "p95:http.server.request.duration{service:framecast-api,!http.route:/health}"
              }
            }
            display_type = "line"
            style { palette = "orange"; line_width = "normal" }
          }

          request {
            formula { formula_expression = "p99_lat"; alias = "p99" }
            query {
              metric_query {
                name  = "p99_lat"
                query = "p99:http.server.request.duration{service:framecast-api,!http.route:/health}"
              }
            }
            display_type = "line"
            style { palette = "red"; line_width = "normal" }
          }

          yaxis { label = "Latência (s)"; min = "0"; include_zero = true }
          marker { value = "y = 1"; display_type = "warning dashed"; label = "Warning 1s" }
          marker { value = "y = 2"; display_type = "error dashed"; label = "Critical 2s" }
        }
      }

      widget {
        query_value_definition {
          title     = "Latência p95 atual"
          autoscale = true
          precision = 3

          request {
            formula { formula_expression = "p95_now" }
            query {
              metric_query {
                name       = "p95_now"
                query      = "p95:http.server.request.duration{service:framecast-api}"
                aggregator = "last"
              }
            }
            conditional_formats { comparator = "<";  value = 1; palette = "white_on_green" }
            conditional_formats { comparator = "<";  value = 2; palette = "white_on_yellow" }
            conditional_formats { comparator = ">="; value = 2; palette = "white_on_red" }
          }
        }
      }

      widget {
        timeseries_definition {
          title       = "Throughput (req/s) por rota"
          show_legend = true

          request {
            formula { formula_expression = "req_rate"; alias = "Req/s" }
            query {
              metric_query {
                name  = "req_rate"
                query = "sum:http.server.request.count{service:framecast-api,!http.route:/health} by {http.route}.as_rate()"
              }
            }
            display_type = "line"
            style { palette = "cool"; line_width = "normal" }
          }
        }
      }
    }
  }

  # ================================================================
  # SEÇÃO 2 — Pipeline de Vídeo (framecast-worker)
  # ================================================================
  widget {
    group_definition {
      title            = "Pipeline de Vídeo — framecast-worker"
      layout_type      = "ordered"
      background_color = "vivid_green"

      widget {
        timeseries_definition {
          title       = "Vídeos processados (done vs error)"
          show_legend = true

          request {
            formula { formula_expression = "done"; alias = "Done" }
            query {
              metric_query {
                name  = "done"
                query = "sum:video.processed.total{service:framecast-worker,status:done}.as_count()"
              }
            }
            display_type = "bars"
            style { palette = "green" }
          }

          request {
            formula { formula_expression = "err"; alias = "Error" }
            query {
              metric_query {
                name  = "err"
                query = "sum:video.processed.total{service:framecast-worker,status:error}.as_count()"
              }
            }
            display_type = "bars"
            style { palette = "red" }
          }
        }
      }

      widget {
        query_value_definition {
          title     = "Mensagens na DLQ"
          autoscale = true
          precision = 0

          request {
            formula { formula_expression = "dlq" }
            query {
              metric_query {
                name       = "dlq"
                query      = "avg:aws.sqs.approximate_number_of_messages_visible{queuename:framecast-processing-dlq}"
                aggregator = "last"
              }
            }
            conditional_formats { comparator = "<="; value = 0; palette = "white_on_green" }
            conditional_formats { comparator = ">";  value = 0; palette = "white_on_red" }
          }
        }
      }

      widget {
        timeseries_definition {
          title       = "Duração do processamento p95 (segundos)"
          show_legend = false

          request {
            formula { formula_expression = "p95_proc"; alias = "p95 processamento" }
            query {
              metric_query {
                name  = "p95_proc"
                query = "p95:video.processing.duration{service:framecast-worker,status:done}"
              }
            }
            display_type = "line"
            style { palette = "orange" }
          }

          marker { value = "y = 1200"; display_type = "error dashed"; label = "Critical 20min" }
        }
      }
    }
  }

  # ================================================================
  # SEÇÃO 3 — Recursos Kubernetes
  # ================================================================
  widget {
    group_definition {
      title            = "Recursos Kubernetes — namespace framecast"
      layout_type      = "ordered"
      background_color = "vivid_purple"

      widget {
        timeseries_definition {
          title       = "CPU Usage (% do limite)"
          show_legend = true

          request {
            formula { formula_expression = "(cpu_usage / cpu_limit) * 100"; alias = "CPU %" }
            query {
              metric_query {
                name  = "cpu_usage"
                query = "avg:kubernetes.cpu.usage.total{kube_namespace:framecast} by {kube_deployment}"
              }
            }
            query {
              metric_query {
                name  = "cpu_limit"
                query = "avg:kubernetes.cpu.limits{kube_namespace:framecast} by {kube_deployment}"
              }
            }
            display_type = "line"
            style { palette = "warm"; line_width = "normal" }
          }

          yaxis { label = "CPU (%)"; min = "0"; max = "100"; include_zero = true }
          marker { value = "y = 70"; display_type = "warning dashed"; label = "Warning 70%" }
          marker { value = "y = 85"; display_type = "error dashed"; label = "Critical 85%" }
        }
      }

      widget {
        timeseries_definition {
          title       = "Pods em execução por deployment"
          show_legend = true

          request {
            formula { formula_expression = "pods"; alias = "Pods" }
            query {
              metric_query {
                name  = "pods"
                query = "sum:kubernetes.pods.running{kube_namespace:framecast} by {kube_deployment}"
              }
            }
            display_type = "area"
            style { palette = "green"; line_width = "thin" }
          }

          yaxis { min = "0"; include_zero = true }
        }
      }

      widget {
        timeseries_definition {
          title       = "Restarts de containers"
          show_legend = true

          request {
            formula { formula_expression = "restarts"; alias = "Restarts" }
            query {
              metric_query {
                name  = "restarts"
                query = "sum:kubernetes.containers.restarts{kube_namespace:framecast} by {kube_deployment}"
              }
            }
            display_type = "bars"
            style { palette = "red" }
          }

          marker { value = "y = 2"; display_type = "error dashed"; label = "Critical 2 restarts" }
        }
      }
    }
  }

  # ================================================================
  # SEÇÃO 4 — Erros e Disponibilidade
  # ================================================================
  widget {
    group_definition {
      title            = "Erros e Disponibilidade"
      layout_type      = "ordered"
      background_color = "vivid_red"

      widget {
        query_value_definition {
          title     = "Availability (% 2xx)"
          autoscale = true
          precision = 2

          request {
            formula { formula_expression = "(success / total) * 100"; alias = "Availability %" }
            query {
              metric_query {
                name       = "success"
                query      = "sum:http.server.request.count{service:framecast-api,status_code:2*,!http.route:/health}.as_count()"
                aggregator = "sum"
              }
            }
            query {
              metric_query {
                name       = "total"
                query      = "sum:http.server.request.count{service:framecast-api,!http.route:/health}.as_count()"
                aggregator = "sum"
              }
            }
            conditional_formats { comparator = ">="; value = 99; palette = "white_on_green" }
            conditional_formats { comparator = ">="; value = 95; palette = "white_on_yellow" }
            conditional_formats { comparator = "<";  value = 95; palette = "white_on_red" }
          }
        }
      }

      widget {
        timeseries_definition {
          title       = "Taxa de erros 5xx (%)"
          show_legend = false

          request {
            formula { formula_expression = "(e5xx / total) * 100"; alias = "Error Rate %" }
            query {
              metric_query {
                name  = "e5xx"
                query = "sum:http.server.request.count{service:framecast-api,status_code:5*}.as_rate()"
              }
            }
            query {
              metric_query {
                name  = "total"
                query = "sum:http.server.request.count{service:framecast-api}.as_rate()"
              }
            }
            display_type = "line"
            style { palette = "red"; line_width = "normal" }
          }

          marker { value = "y = 2"; display_type = "warning dashed"; label = "Warning 2%" }
          marker { value = "y = 5"; display_type = "error dashed";   label = "Critical 5%" }
        }
      }
    }
  }

  tags = ["team:backend", "project:framecast"]
}
