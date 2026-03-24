# ------------------------------------------------------------
# Monitor 1: High API Latency (p95 > 2s)
# ------------------------------------------------------------
resource "datadog_monitor" "high_api_latency" {
  name    = "[oficina-tech] High API Latency (p95)"
  type    = "metric alert"
  message = "P95 API latency for oficina-tech exceeded 2 seconds. @slack-oncall"

  query = "percentile(last_5m):p95:http.server.request.duration{service:oficina-tech} > 2"

  monitor_thresholds {
    critical          = 2
    critical_recovery = 1.5
    warning           = 1
    warning_recovery  = 0.8
  }

  notify_no_data    = false
  renotify_interval = 60

  tags = ["service:oficina-tech", "env:production", "team:backend"]
}

# ------------------------------------------------------------
# Monitor 2: Service Order Processing Failures
# ------------------------------------------------------------
resource "datadog_monitor" "service_order_failures" {
  name    = "[oficina-tech] Service Order Processing Failures"
  type    = "metric alert"
  message = "More than 5 service order status transition failures in the last 5 minutes. @slack-oncall"

  query = "sum(last_5m):sum:service_order.status_transition{service:oficina-tech,result:failure}.as_count() > 5"

  monitor_thresholds {
    critical          = 5
    critical_recovery = 2
    warning           = 2
    warning_recovery  = 0
  }

  notify_no_data    = false
  renotify_interval = 30

  tags = ["service:oficina-tech", "env:production", "team:backend"]
}

# ------------------------------------------------------------
# Monitor 3: Pod Restarts
# ------------------------------------------------------------
resource "datadog_monitor" "pod_restarts" {
  name    = "[oficina-tech] High Pod Restart Rate"
  type    = "metric alert"
  message = "oficina-tech deployment has had more than 2 container restarts in the last 5 minutes. @slack-oncall"

  query = "change(sum(last_5m),last_5m):sum:kubernetes.containers.restarts{kube_deployment:oficina-tech-deployment} > 2"

  monitor_thresholds {
    critical          = 2
    critical_recovery = 0
    warning           = 1
    warning_recovery  = 0
  }

  notify_no_data    = false
  renotify_interval = 30

  tags = ["service:oficina-tech", "env:production", "team:backend"]
}

# ------------------------------------------------------------
# Monitor 4: High 5xx Error Rate
# ------------------------------------------------------------
resource "datadog_monitor" "high_error_rate" {
  name    = "[oficina-tech] High 5xx Error Rate"
  type    = "metric alert"
  message = "5xx error rate for oficina-tech exceeded 5% in the last 5 minutes. @slack-oncall"

  query = "sum(last_5m):(sum:http.server.request.count{service:oficina-tech,status_code:5*}.as_rate() / sum:http.server.request.count{service:oficina-tech}.as_rate()) * 100 > 5"

  monitor_thresholds {
    critical          = 5
    critical_recovery = 2
    warning           = 2
    warning_recovery  = 1
  }

  notify_no_data    = false
  renotify_interval = 30

  tags = ["service:oficina-tech", "env:production", "team:backend"]
}

# ------------------------------------------------------------
# Monitor 5: High CPU Usage
# ------------------------------------------------------------
resource "datadog_monitor" "high_cpu" {
  name    = "[oficina-tech] High CPU Usage"
  type    = "metric alert"
  message = "oficina-tech CPU usage exceeded 85% of limits. @slack-oncall"

  query = "avg(last_10m):(avg:kubernetes.cpu.usage.total{kube_deployment:oficina-tech-deployment} / avg:kubernetes.cpu.limits{kube_deployment:oficina-tech-deployment}) * 100 > 85"

  monitor_thresholds {
    critical          = 85
    critical_recovery = 75
    warning           = 70
    warning_recovery  = 60
  }

  notify_no_data    = false
  renotify_interval = 60

  tags = ["service:oficina-tech", "env:production", "team:backend"]
}

# ------------------------------------------------------------
# Monitor 6: High Memory Usage
# ------------------------------------------------------------
resource "datadog_monitor" "high_memory" {
  name    = "[oficina-tech] High Memory Usage"
  type    = "metric alert"
  message = "oficina-tech memory usage exceeded 85% of limits. @slack-oncall"

  query = "avg(last_10m):(avg:kubernetes.memory.usage{kube_deployment:oficina-tech-deployment} / avg:kubernetes.memory.limits{kube_deployment:oficina-tech-deployment}) * 100 > 85"

  monitor_thresholds {
    critical          = 85
    critical_recovery = 75
    warning           = 70
    warning_recovery  = 60
  }

  notify_no_data    = false
  renotify_interval = 60

  tags = ["service:oficina-tech", "env:production", "team:backend"]
}
