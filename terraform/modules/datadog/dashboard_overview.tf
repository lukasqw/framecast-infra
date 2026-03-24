resource "datadog_dashboard" "overview" {
  title       = "Oficina Tech - Overview"
  description = "Visão consolidada: latência, recursos K8s, healthcheck, erros e métricas de negócio"
  layout_type = "ordered"

  # ================================================================
  # SEÇÃO 1 — Latência das APIs
  # ================================================================
  widget {
    group_definition {
      title            = "Latência das APIs"
      layout_type      = "ordered"
      background_color = "vivid_blue"

      # 1.1 — Percentis de latência ao longo do tempo
      widget {
        timeseries_definition {
          title       = "Latência das APIs — p50 / p95 / p99"
          show_legend = true

          request {
            formula {
              formula_expression = "p50_lat"
              alias              = "p50"
            }
            query {
              metric_query {
                name  = "p50_lat"
                query = "p50:http.server.request.duration{service:oficina-tech}"
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
              formula_expression = "p95_lat"
              alias              = "p95"
            }
            query {
              metric_query {
                name  = "p95_lat"
                query = "p95:http.server.request.duration{service:oficina-tech}"
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
              formula_expression = "p99_lat"
              alias              = "p99"
            }
            query {
              metric_query {
                name  = "p99_lat"
                query = "p99:http.server.request.duration{service:oficina-tech}"
              }
            }
            display_type = "line"
            style {
              palette    = "red"
              line_width = "normal"
            }
          }

          yaxis {
            label        = "Latência (s)"
            min          = "0"
            include_zero = true
          }

          marker {
            value        = "y = 1"
            display_type = "warning dashed"
            label        = "Warning 1s"
          }
          marker {
            value        = "y = 2"
            display_type = "error dashed"
            label        = "Critical 2s"
          }
        }
      }

      # 1.2 — Latência p95 por rota (tabela de referência)
      widget {
        query_table_definition {
          title = "Latência p95 por Endpoint"

          request {
            formula {
              formula_expression = "p95_route"
              alias              = "p95 (s)"
              cell_display_mode  = "bar"
            }
            formula {
              formula_expression = "p50_route"
              alias              = "p50 (s)"
              cell_display_mode  = "number"
            }
            query {
              metric_query {
                name  = "p95_route"
                query = "p95:http.server.request.duration{service:oficina-tech} by {http.route}"
              }
            }
            query {
              metric_query {
                name  = "p50_route"
                query = "p50:http.server.request.duration{service:oficina-tech} by {http.route}"
              }
            }
          }
        }
      }

      # 1.3 — Throughput (requisições/s) por rota
      widget {
        timeseries_definition {
          title       = "Throughput das APIs (req/s)"
          show_legend = true

          request {
            formula {
              formula_expression = "req_rate"
              alias              = "Requisições/s"
            }
            query {
              metric_query {
                name  = "req_rate"
                query = "sum:http.server.request.count{service:oficina-tech} by {http.route}.as_rate()"
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

      # 1.4 — p95 latência atual (valor pontual)
      widget {
        query_value_definition {
          title     = "Latência p95 atual"
          autoscale = true
          precision = 3

          request {
            formula {
              formula_expression = "p95_now"
            }
            query {
              metric_query {
                name       = "p95_now"
                query      = "p95:http.server.request.duration{service:oficina-tech}"
                aggregator = "last"
              }
            }

            conditional_formats {
              comparator = "<"
              value      = 1
              palette    = "white_on_green"
            }
            conditional_formats {
              comparator = "<"
              value      = 2
              palette    = "white_on_yellow"
            }
            conditional_formats {
              comparator = ">="
              value      = 2
              palette    = "white_on_red"
            }
          }
        }
      }
    }
  }

  # ================================================================
  # SEÇÃO 2 — Consumo de Recursos do Kubernetes
  # ================================================================
  widget {
    group_definition {
      title            = "Consumo de Recursos — Kubernetes"
      layout_type      = "ordered"
      background_color = "vivid_purple"

      # 2.1 — CPU (% do limite)
      widget {
        timeseries_definition {
          title       = "CPU Usage (% do limite)"
          show_legend = true

          request {
            formula {
              formula_expression = "(cpu_usage / cpu_limit) * 100"
              alias              = "CPU %"
            }
            query {
              metric_query {
                name  = "cpu_usage"
                query = "avg:kubernetes.cpu.usage.total{kube_deployment:oficina-tech-deployment}"
              }
            }
            query {
              metric_query {
                name  = "cpu_limit"
                query = "avg:kubernetes.cpu.limits{kube_deployment:oficina-tech-deployment}"
              }
            }
            display_type = "line"
            style {
              palette    = "warm"
              line_width = "normal"
            }
          }

          yaxis {
            label        = "CPU (%)"
            min          = "0"
            max          = "100"
            include_zero = true
          }

          marker {
            value        = "y = 70"
            display_type = "warning dashed"
            label        = "Warning 70%"
          }
          marker {
            value        = "y = 85"
            display_type = "error dashed"
            label        = "Critical 85%"
          }
        }
      }

      # 2.2 — Memória (% do limite)
      widget {
        timeseries_definition {
          title       = "Memory Usage (% do limite)"
          show_legend = true

          request {
            formula {
              formula_expression = "(mem_usage / mem_limit) * 100"
              alias              = "Memória %"
            }
            query {
              metric_query {
                name  = "mem_usage"
                query = "avg:kubernetes.memory.usage{kube_deployment:oficina-tech-deployment}"
              }
            }
            query {
              metric_query {
                name  = "mem_limit"
                query = "avg:kubernetes.memory.limits{kube_deployment:oficina-tech-deployment}"
              }
            }
            display_type = "line"
            style {
              palette    = "purple"
              line_width = "normal"
            }
          }

          yaxis {
            label        = "Memória (%)"
            min          = "0"
            max          = "100"
            include_zero = true
          }

          marker {
            value        = "y = 70"
            display_type = "warning dashed"
            label        = "Warning 70%"
          }
          marker {
            value        = "y = 85"
            display_type = "error dashed"
            label        = "Critical 85%"
          }
        }
      }

      # 2.3 — Restarts de containers
      widget {
        timeseries_definition {
          title       = "Restarts de Containers"
          show_legend = false

          request {
            formula {
              formula_expression = "restarts"
              alias              = "Restarts"
            }
            query {
              metric_query {
                name  = "restarts"
                query = "sum:kubernetes.containers.restarts{kube_deployment:oficina-tech-deployment}"
              }
            }
            display_type = "bars"
            style {
              palette = "red"
            }
          }

          marker {
            value        = "y = 2"
            display_type = "error dashed"
            label        = "Critical 2 restarts"
          }
        }
      }

      # 2.4 — Pods em execução (valor atual)
      widget {
        query_value_definition {
          title     = "Pods em execução"
          autoscale = true
          precision = 0

          request {
            formula {
              formula_expression = "pods_running"
            }
            query {
              metric_query {
                name       = "pods_running"
                query      = "sum:kubernetes.pods.running{kube_deployment:oficina-tech-deployment}"
                aggregator = "last"
              }
            }

            conditional_formats {
              comparator = ">="
              value      = 1
              palette    = "white_on_green"
            }
            conditional_formats {
              comparator = "<"
              value      = 1
              palette    = "white_on_red"
            }
          }
        }
      }
    }
  }

  # ================================================================
  # SEÇÃO 3 — Healthchecks e Uptime
  # ================================================================
  widget {
    group_definition {
      title            = "Healthchecks e Uptime"
      layout_type      = "ordered"
      background_color = "vivid_green"

      # 3.1 — Availability (% de requisições com 2xx)
      widget {
        query_value_definition {
          title     = "Availability (% 2xx)"
          autoscale = true
          precision = 2

          request {
            formula {
              formula_expression = "(success / total) * 100"
              alias              = "Availability %"
            }
            query {
              metric_query {
                name       = "success"
                query      = "sum:http.server.request.count{service:oficina-tech,status_code:2*}.as_count()"
                aggregator = "sum"
              }
            }
            query {
              metric_query {
                name       = "total"
                query      = "sum:http.server.request.count{service:oficina-tech}.as_count()"
                aggregator = "sum"
              }
            }

            conditional_formats {
              comparator = ">="
              value      = 99
              palette    = "white_on_green"
            }
            conditional_formats {
              comparator = ">="
              value      = 95
              palette    = "white_on_yellow"
            }
            conditional_formats {
              comparator = "<"
              value      = 95
              palette    = "white_on_red"
            }
          }
        }
      }

      # 3.2 — Distribuição de status HTTP ao longo do tempo
      widget {
        timeseries_definition {
          title       = "Distribuição de Status HTTP (2xx / 4xx / 5xx)"
          show_legend = true

          request {
            formula {
              formula_expression = "s2xx"
              alias              = "2xx (sucesso)"
            }
            query {
              metric_query {
                name  = "s2xx"
                query = "sum:http.server.request.count{service:oficina-tech,status_code:2*}.as_rate()"
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
              formula_expression = "s4xx"
              alias              = "4xx (cliente)"
            }
            query {
              metric_query {
                name  = "s4xx"
                query = "sum:http.server.request.count{service:oficina-tech,status_code:4*}.as_rate()"
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
              formula_expression = "s5xx"
              alias              = "5xx (servidor)"
            }
            query {
              metric_query {
                name  = "s5xx"
                query = "sum:http.server.request.count{service:oficina-tech,status_code:5*}.as_rate()"
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

      # 3.3 — Pods disponíveis ao longo do tempo (uptime visual)
      widget {
        timeseries_definition {
          title       = "Pods disponíveis ao longo do tempo"
          show_legend = false

          request {
            formula {
              formula_expression = "pods"
              alias              = "Pods running"
            }
            query {
              metric_query {
                name  = "pods"
                query = "sum:kubernetes.pods.running{kube_deployment:oficina-tech-deployment}"
              }
            }
            display_type = "area"
            style {
              palette    = "green"
              line_width = "thin"
            }
          }

          yaxis {
            min          = "0"
            include_zero = true
          }
        }
      }
    }
  }

  # ================================================================
  # SEÇÃO 4 — Erros e Falhas nas Integrações
  # ================================================================
  widget {
    group_definition {
      title            = "Erros e Falhas nas Integrações"
      layout_type      = "ordered"
      background_color = "vivid_red"

      # 4.1 — Taxa de erros 5xx (%) ao longo do tempo
      widget {
        timeseries_definition {
          title       = "Taxa de Erros 5xx (%)"
          show_legend = false

          request {
            formula {
              formula_expression = "(e5xx / total) * 100"
              alias              = "Error Rate %"
            }
            query {
              metric_query {
                name  = "e5xx"
                query = "sum:http.server.request.count{service:oficina-tech,status_code:5*}.as_rate()"
              }
            }
            query {
              metric_query {
                name  = "total"
                query = "sum:http.server.request.count{service:oficina-tech}.as_rate()"
              }
            }
            display_type = "line"
            style {
              palette    = "red"
              line_width = "normal"
            }
          }

          marker {
            value        = "y = 2"
            display_type = "warning dashed"
            label        = "Warning 2%"
          }
          marker {
            value        = "y = 5"
            display_type = "error dashed"
            label        = "Critical 5%"
          }
        }
      }

      # 4.2 — Taxa de erros 5xx atual (valor pontual)
      widget {
        query_value_definition {
          title     = "Error Rate 5xx (atual)"
          autoscale = true
          precision = 2

          request {
            formula {
              formula_expression = "(e5xx / total) * 100"
            }
            query {
              metric_query {
                name       = "e5xx"
                query      = "sum:http.server.request.count{service:oficina-tech,status_code:5*}.as_rate()"
                aggregator = "avg"
              }
            }
            query {
              metric_query {
                name       = "total"
                query      = "sum:http.server.request.count{service:oficina-tech}.as_rate()"
                aggregator = "avg"
              }
            }

            conditional_formats {
              comparator = "<"
              value      = 2
              palette    = "white_on_green"
            }
            conditional_formats {
              comparator = "<"
              value      = 5
              palette    = "white_on_yellow"
            }
            conditional_formats {
              comparator = ">="
              value      = 5
              palette    = "white_on_red"
            }
          }
        }
      }

      # 4.3 — Erros de processamento de ordens de serviço por tipo
      widget {
        timeseries_definition {
          title       = "Falhas no Processamento de Ordens de Serviço"
          show_legend = true

          request {
            formula {
              formula_expression = "proc_errors"
              alias              = "Erros de processamento"
            }
            query {
              metric_query {
                name  = "proc_errors"
                query = "sum:service_order.processing_error{service:oficina-tech} by {error_type}.as_count()"
              }
            }
            display_type = "bars"
            style {
              palette = "red"
            }
          }
        }
      }

      # 4.4 — Transições de status com resultado de falha
      widget {
        timeseries_definition {
          title       = "Transições de Status com Falha"
          show_legend = true

          request {
            formula {
              formula_expression = "failed_trans"
              alias              = "Transições com falha"
            }
            query {
              metric_query {
                name  = "failed_trans"
                query = "sum:service_order.status_transition{service:oficina-tech,result:failure} by {from_status}.as_count()"
              }
            }
            display_type = "bars"
            style {
              palette = "orange"
            }
          }
        }
      }

      # 4.5 — Tabela de erros por endpoint (top offenders)
      widget {
        query_table_definition {
          title = "Erros 5xx por Endpoint"

          request {
            formula {
              formula_expression = "err_count"
              alias              = "Erros (5xx)"
              cell_display_mode  = "bar"
            }
            formula {
              formula_expression = "(err_count / total_count) * 100"
              alias              = "Error Rate %"
              cell_display_mode  = "number"
            }
            query {
              metric_query {
                name  = "err_count"
                query = "sum:http.server.request.count{service:oficina-tech,status_code:5*} by {http.route}.as_count()"
              }
            }
            query {
              metric_query {
                name  = "total_count"
                query = "sum:http.server.request.count{service:oficina-tech} by {http.route}.as_count()"
              }
            }
          }
        }
      }
    }
  }

  # ================================================================
  # SEÇÃO 5 — Volume Diário de Ordens de Serviço
  # ================================================================
  widget {
    group_definition {
      title            = "Volume de Ordens de Serviço"
      layout_type      = "ordered"
      background_color = "vivid_yellow"

      # 5.1 — Volume diário (barras)
      widget {
        timeseries_definition {
          title       = "Volume diário de ordens de serviço"
          show_legend = true

          request {
            formula {
              formula_expression = "daily_orders"
              alias              = "Ordens criadas"
            }
            query {
              metric_query {
                name  = "daily_orders"
                query = "sum:service_order.created{service:oficina-tech}.as_count().rollup(sum, 86400)"
              }
            }
            display_type = "bars"
            style {
              palette    = "dog_classic"
              line_type  = "solid"
              line_width = "normal"
            }
          }
        }
      }

      # 5.2 — Total de ordens criadas no período
      widget {
        query_value_definition {
          title     = "Ordens criadas no período"
          autoscale = true
          precision = 0

          request {
            formula {
              formula_expression = "total_orders"
            }
            query {
              metric_query {
                name       = "total_orders"
                query      = "sum:service_order.created{service:oficina-tech}.as_count()"
                aggregator = "sum"
              }
            }
          }
        }
      }

      # 5.3 — Funil de transições de status (sucesso)
      widget {
        timeseries_definition {
          title       = "Transições de status (sucesso por destino)"
          show_legend = true

          request {
            formula {
              formula_expression = "transitions"
              alias              = "Transições"
            }
            query {
              metric_query {
                name  = "transitions"
                query = "sum:service_order.status_transition{service:oficina-tech,result:success} by {to_status}.as_count()"
              }
            }
            display_type = "bars"
            style {
              palette = "purple"
            }
          }
        }
      }
    }
  }

  # ================================================================
  # SEÇÃO 6 — Tempo Médio de Execução por Status
  # ================================================================
  widget {
    group_definition {
      title            = "Tempo Médio de Execução por Status"
      layout_type      = "ordered"
      background_color = "vivid_orange"

      # 6.1 — Tempo médio por status ao longo do tempo
      widget {
        timeseries_definition {
          title       = "Tempo médio em cada status (segundos)"
          show_legend = true

          request {
            formula {
              formula_expression = "avg_dur"
              alias              = "Duração média (s)"
            }
            query {
              metric_query {
                name  = "avg_dur"
                query = "avg:service_order.status_duration{service:oficina-tech} by {status}"
              }
            }
            display_type = "line"
            style {
              palette    = "cool"
              line_type  = "solid"
              line_width = "normal"
            }
          }
        }
      }

      # 6.2 — Tabela de percentis p50 / p95 por status
      widget {
        query_table_definition {
          title = "Percentis de duração por status (p50 / p95)"

          request {
            formula {
              formula_expression = "p50"
              alias              = "p50 (s)"
              cell_display_mode  = "bar"
            }
            formula {
              formula_expression = "p95"
              alias              = "p95 (s)"
              cell_display_mode  = "number"
            }
            query {
              metric_query {
                name  = "p50"
                query = "p50:service_order.status_duration{service:oficina-tech} by {status}"
              }
            }
            query {
              metric_query {
                name  = "p95"
                query = "p95:service_order.status_duration{service:oficina-tech} by {status}"
              }
            }
          }
        }
      }

      # 6.3 — Taxa de transições por status de origem → destino
      widget {
        timeseries_definition {
          title       = "Fluxo de transições (origem → destino)"
          show_legend = true

          request {
            formula {
              formula_expression = "flow"
              alias              = "Transições"
            }
            query {
              metric_query {
                name  = "flow"
                query = "sum:service_order.status_transition{service:oficina-tech,result:success} by {from_status,to_status}.as_count()"
              }
            }
            display_type = "bars"
            style {
              palette = "cool"
            }
          }
        }
      }
    }
  }

  tags = ["team:backend"]
}
