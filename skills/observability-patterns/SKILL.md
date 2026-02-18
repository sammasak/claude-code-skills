---
name: observability-patterns
description: "Use when adding metrics, logging, tracing, or alerting to services. Guides the three pillars of observability, structured logging standards, and instrumentation patterns."
allowed-tools: Bash Read Grep Glob
---

# Observability Patterns

Guide instrumentation so services are observable from day one — never bolt it on after an incident.

## Principles

- **Observe, don't guess.** Every production question should be answerable from telemetry, not from reading code or adding print statements.
- **Three pillars, three questions:**

| Pillar  | Question           | Shape                              |
|---------|--------------------|-------------------------------------|
| Metrics | WHAT is happening? | Counters, gauges, histograms        |
| Logs    | WHY it happened?   | Contextual structured events        |
| Traces  | WHERE it happened? | Request flow across service boundaries |

- **Instrument at system boundaries** (HTTP handlers, queue consumers, DB calls) — not deep internals.
- **Alert on symptoms, not causes.** Alert on error rate crossing a threshold, not on a specific error message.

## Standards

### Structured Logging

Always JSON. Never unstructured text lines.

```json
{"timestamp":"2025-01-15T08:12:03Z","level":"error","msg":"payment failed","trace_id":"abc123","user_id":"u-789","error":"timeout"}
```

#### Log Levels

| Level | Meaning                              | Production? |
|-------|--------------------------------------|-------------|
| ERROR | Requires human action now            | Yes         |
| WARN  | Degraded but self-healing            | Yes         |
| INFO  | Business-significant events only     | Yes         |
| DEBUG | Development diagnostics              | Never       |

### Metrics

**RED method** for services:

| Signal   | Metric                  | Example                          |
|----------|-------------------------|----------------------------------|
| Rate     | Requests per second     | `http_requests_total`            |
| Errors   | Error rate %            | `http_errors_total / http_requests_total` |
| Duration | Latency histograms      | `http_request_duration_seconds`  |

**USE method** for infrastructure resources:

| Signal      | Metric       | Example                    |
|-------------|--------------|----------------------------|
| Utilization | % busy       | CPU usage, memory usage    |
| Saturation  | Queue depth  | Thread pool queue length   |
| Errors      | Error count  | Disk I/O errors            |

### Trace Context

- Propagate trace IDs across ALL service boundaries — HTTP headers, message queues, async jobs.
- Use W3C Trace Context (`traceparent` header) as the standard propagation format.

### Required Endpoints

Every service exposes:
- `/metrics` — Prometheus scrape target
- `/healthz` — Liveness probe (is the process alive?)
- `/readyz` — Readiness probe (can it serve traffic?)

## Workflow

Instrument at service creation. This is the checklist before a service goes to staging:

- [ ] Structured logger configured (JSON output, correlation IDs)
- [ ] Prometheus metrics endpoint exposed at `/metrics`
- [ ] OpenTelemetry tracer initialized with OTLP exporter
- [ ] HTTP middleware adds request duration + status code metrics
- [ ] Trace context propagated to all outbound calls (HTTP, gRPC, queues)
- [ ] Health (`/healthz`) and readiness (`/readyz`) endpoints
- [ ] Grafana dashboard created with RED metrics for the service

## Patterns We Use

**Cluster monitoring:** kube-prometheus-stack (Prometheus + Grafana + Alertmanager) — batteries-included for Kubernetes.

**Log aggregation:** Loki + Promtail. Query with LogQL. Logs stay in the same Grafana as metrics.

**Tracing:** OpenTelemetry SDK in application code, OTLP exporter to a collector, collector forwards to backend.

**Language-specific:**

| Language | Logging              | Tracing                                      | Metrics                            |
|----------|----------------------|----------------------------------------------|------------------------------------|
| Python   | `structlog` (JSON)   | `opentelemetry-instrumentation-fastapi`       | Prometheus client                  |
| Rust     | `tracing` + `tracing-subscriber` (JSON layer) | `tracing-opentelemetry`       | `metrics` + `metrics-exporter-prometheus` |

**Dashboards:** One Grafana dashboard per service. Four panels minimum: request rate, error rate, p50/p95/p99 latency, active requests.

## Anti-Patterns

| Don't                                          | Why                                              |
|------------------------------------------------|--------------------------------------------------|
| Log PII or secrets                             | Compliance and security risk                     |
| Use unstructured log lines                     | Can't query, can't aggregate, can't alert        |
| Alert on every individual error                | Alert fatigue — alert on rates and trends instead |
| Skip trace context in cross-service calls      | Can't follow requests across boundaries          |
| Keep dashboards nobody looks at                | Review quarterly or delete                       |
| Use high-cardinality labels (e.g., user IDs)   | Prometheus OOM, index explosion                  |
| Log full request/response bodies in production | Storage cost + PII risk                          |

## References

- [Google SRE Book — Ch. 6: Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Grafana Loki Documentation](https://grafana.com/docs/loki/latest/)
- "Observability Engineering" — Majors, Fong-Jones, Miranda (O'Reilly)
