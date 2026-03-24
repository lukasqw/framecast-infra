resource "datadog_dashboard" "service_orders" {
  title       = "Oficina Tech - Service Orders"
  description = "Volume diário e tempo médio por status das ordens de serviço"
  layout_type = "ordered"

  # ----------------------------------------------------------------
  # Widget 1: Volume diário de ordens de serviço
  # ----------------------------------------------------------------
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

  # ----------------------------------------------------------------
  # Widget 2: Tempo médio por status (heatmap de distribuição)
  # ----------------------------------------------------------------
  widget {
    timeseries_definition {
      title       = "Tempo médio em cada status (segundos)"
      show_legend = true

      request {
        formula {
          formula_expression = "avg_duration"
          alias              = "Duração média (s)"
        }
        query {
          metric_query {
            name  = "avg_duration"
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

  # ----------------------------------------------------------------
  # Widget 3: Distribuição p50/p95 por status (tabela de referência)
  # ----------------------------------------------------------------
  widget {
    query_table_definition {
      title = "Percentis de duração por status"

      request {
        formula {
          formula_expression = "p50"
          alias              = "p50 (s)"
          cell_display_mode  = "number"
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

  # ----------------------------------------------------------------
  # Widget 4: Volume de transições por status (funil visual)
  # ----------------------------------------------------------------
  widget {
    timeseries_definition {
      title       = "Transições de status"
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
