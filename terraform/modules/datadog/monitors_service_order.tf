# ------------------------------------------------------------
# Monitor SO-1: Erros no processamento (service_order.processing_error)
# Métrica gerada em advance_service_order_status quando operações
# de inventário ou regras de negócio falham antes da transição.
# ------------------------------------------------------------
resource "datadog_monitor" "service_order_processing_errors" {
  name    = "[oficina-tech] Service Order Processing Errors"
  type    = "metric alert"
  message = <<-EOT
    Erros de processamento em ordens de serviço detectados nos últimos 5 minutos.
    Verifique os logs do usecase `service_order.advance_status` e o tipo de erro (error_type).
    @slack-oncall
  EOT

  query = "sum(last_5m):sum:service_order.processing_error{service:oficina-tech}.as_count() > 3"

  monitor_thresholds {
    critical          = 3
    critical_recovery = 0
    warning           = 1
    warning_recovery  = 0
  }

  notify_no_data    = false
  renotify_interval = 30

  tags = ["team:backend"]
}

# ------------------------------------------------------------
# Monitor SO-2: Taxa de falhas em transições de status (%)
# Mais útil que contagem absoluta — detecta degradação
# proporcional mesmo em períodos de alto volume.
# ------------------------------------------------------------
resource "datadog_monitor" "service_order_failure_rate" {
  name    = "[oficina-tech] Service Order Failure Rate"
  type    = "metric alert"
  message = <<-EOT
    A taxa de falhas em transições de status de ordens de serviço está elevada nos últimos 15 minutos.
    Verifique se há problemas de inventário, regras de negócio ou dependências externas.
    @slack-oncall
  EOT

  query = "sum(last_15m):(sum:service_order.status_transition{service:oficina-tech,result:failure}.as_count() / sum:service_order.status_transition{service:oficina-tech}.as_count()) * 100 > 40"

  monitor_thresholds {
    critical          = 40
    critical_recovery = 20
    warning           = 20
    warning_recovery  = 10
  }

  notify_no_data    = false
  renotify_interval = 60

  tags = ["team:backend"]
}

# ------------------------------------------------------------
# Monitor SO-3: Ordens travadas em um status (p95 duration)
# Detecta quando ordens ficam paradas sem avançar —
# pode indicar falha silenciosa, dependência bloqueada
# ou processo manual pendente.
# ------------------------------------------------------------
resource "datadog_monitor" "service_order_stuck" {
  name    = "[oficina-tech] Service Order Stuck in Status"
  type    = "metric alert"
  message = <<-EOT
    Ordens de serviço estão demorando mais que o esperado para avançar de status (p95 > threshold).
    Verifique se há ordens presas aguardando autorização, inventário ou ação manual.
    @slack-oncall
  EOT

  query = "percentile(last_30m):p95:service_order.status_duration{service:oficina-tech} by {status} > 3600"

  monitor_thresholds {
    critical          = 3600
    critical_recovery = 2700
    warning           = 1800
    warning_recovery  = 1200
  }

  notify_no_data    = false
  renotify_interval = 60

  tags = ["team:backend"]
}

# ------------------------------------------------------------
# Monitor SO-4: Queda no volume de criação de ordens
# Detecta ausência de novas ordens por um período prolongado —
# pode indicar falha no frontend, API indisponível ou
# problema de autenticação dos clientes.
# ------------------------------------------------------------
resource "datadog_monitor" "service_order_creation_drop" {
  name    = "[oficina-tech] Service Order Creation Drop"
  type    = "metric alert"
  message = <<-EOT
    Nenhuma ordem de serviço foi criada nos últimos 30 minutos.
    Verifique se o endpoint de criação está acessível e se há erros de autenticação ou validação.
    @slack-oncall
  EOT

  query = "sum(last_30m):sum:service_order.created{service:oficina-tech}.as_count() < 1"

  monitor_thresholds {
    critical          = 1
    critical_recovery = 2
  }

  notify_no_data    = true
  no_data_timeframe = 30
  renotify_interval = 60

  tags = ["team:backend"]
}
