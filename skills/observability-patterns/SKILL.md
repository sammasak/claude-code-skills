---
name: observability-patterns
description: "Use when adding metrics, logs, dashboards, or alerts to a homelab service, or when deciding whether to add tracing. Not for language-specific logger setup; route that to the language skill."
allowed-tools: Bash, Read, Grep, Glob
injectable: true
---

# Observability (homelab stack)

The full standard lives in `~/homelab-gitops/docs/observability-standard.md`; this is the strip that changes decisions.

| Component | What is deployed |
|---|---|
| Metrics | kube-prometheus-stack (Prometheus Operator, Grafana, Alertmanager); scrape via `ServiceMonitor`/`PodMonitor` |
| Logs | Loki + Grafana Alloy DaemonSet (Promtail is gone); 30-day retention; query with LogQL in Grafana Explore |
| Traces | **None.** No Tempo/Jaeger/OTLP collector. Do not add OTel exporters expecting a backend; propagate a `trace_id`/request-id into logs and correlate metrics and logs by namespace, pod, and timestamp |
| Alerting | Alertmanager -> `alertmanager-ntfy-bridge` -> ntfy topic `homelab-alerts` (see `ntfy-notifications`) |
| Dashboards | Grafana at https://grafana.sammasak.dev; dashboard ConfigMaps and `PrometheusRule` alerts live in `~/homelab-gitops/apps/monitoring-dashboards/`; "Universal App Health" is the first stop in an incident |
| Python | `structlog` JSON + `prometheus_client` |
| Rust | `tracing` + `tracing-subscriber` (JSON) + `metrics-exporter-prometheus` |

## Service checklist

- JSON logs to stdout (Alloy tails `/var/log/pods/`), with request-id.
- `/metrics` plus a `ServiceMonitor`; RED metrics on HTTP handlers; no user IDs or other unbounded values as labels.
- A health endpoint for probes (`apps/_template` points both probes at `/health`; adjust to the app's real path).
- Scale-to-zero apps (KEDA HTTP add-on) show zero pods when idle; write alerts on request error rate, not on pod absence.
