# Terraform 1.7+ — import blocks são idempotentes:
# se o recurso já está no state, o bloco é ignorado.
# Necessário para recuperar o state após um destroy que não deletou
# os monitors no Datadog (ex.: credenciais ausentes durante o destroy).

import {
  to = datadog_monitor.high_api_latency
  id = "283667600"
}

import {
  to = datadog_monitor.service_order_failures
  id = "283667611"
}

import {
  to = datadog_monitor.pod_restarts
  id = "283667608"
}

import {
  to = datadog_monitor.high_error_rate
  id = "283667601"
}

import {
  to = datadog_monitor.high_cpu
  id = "283667604"
}

import {
  to = datadog_monitor.high_memory
  id = "283667602"
}

import {
  to = datadog_monitor.service_order_processing_errors
  id = "283667606"
}

import {
  to = datadog_monitor.service_order_failure_rate
  id = "283667603"
}

import {
  to = datadog_monitor.service_order_stuck
  id = "283667605"
}

import {
  to = datadog_monitor.service_order_creation_drop
  id = "283667599"
}
