---
name: observability-patterns
description: "Use when adding metrics, logging, tracing, or alerting to services. Guides the three pillars of observability, structured logging standards, and instrumentation patterns. Not for language-specific logging setup (e.g., configuring a logger in Rust/Axum) — route those to the relevant language skill."
allowed-tools: Bash, Read, Grep, Glob
injectable: true
---

# Observability Patterns

Instrument services from day one — never bolt it on after an incident.

## Three Pillars

| Pillar  | Question           | Shape                              |
|---------|--------------------|-------------------------------------|
| Metrics | WHAT is happening? | Counters, gauges, histograms        |
| Logs    | WHY it happened?   | Contextual structured events        |
| Traces  | WHERE it happened? | Request flow across service boundaries |

**Alert on symptoms, not causes.** Alert on error rate crossing a threshold, not on a specific error message. Instrument at system boundaries (HTTP handlers, queue consumers, DB calls) — not deep internals.

## Structured Logging

Always JSON:
```json
{"timestamp":"2026-01-15T08:12:03Z","level":"error","msg":"payment failed","trace_id":"abc123","user_id":"u-789","error":"timeout"}
```

| Level | Meaning | Production? |
|-------|---------|-------------|
| ERROR | Requires human action now | Yes |
| WARN  | Degraded but self-healing | Yes |
| INFO  | Business-significant events only | Yes |
| DEBUG | Development diagnostics | Never |

## Metrics — RED Method

| Signal | Metric | Example |
|--------|--------|---------|
| Rate | Requests per second | `http_requests_total` |
| Errors | Error rate % | `http_errors_total / http_requests_total` |
| Duration | Latency histograms | `http_request_duration_seconds` |

## Trace Context

- Propagate trace IDs across ALL service boundaries (HTTP, queues, async jobs)
- Use W3C Trace Context (`traceparent` header)
- Attach exemplars to histograms to link metrics to trace IDs
- Head-based sampling (10%) for high-traffic; tail-based to always capture errors

## Required Endpoints

Every service exposes:
- `/metrics` — Prometheus scrape target
- `/livez` — Liveness probe (`/healthz` deprecated since K8s 1.16)
- `/readyz` — Readiness probe

## Pre-Staging Checklist

- [ ] Structured logger configured (JSON output, correlation IDs)
- [ ] Prometheus `/metrics` endpoint exposed
- [ ] OpenTelemetry tracer initialized with OTLP exporter
- [ ] HTTP middleware adds duration + status code metrics
- [ ] Trace context propagated to all outbound calls
- [ ] `/livez` and `/readyz` endpoints
- [ ] Grafana dashboard: request rate, error rate, p50/p95/p99 latency, active requests

## Patterns We Use

| Component | Choice |
|-----------|--------|
| Cluster monitoring | kube-prometheus-stack (Prometheus + Grafana + Alertmanager) |
| Log aggregation | Loki + Grafana Alloy (LogQL queries; replaces Promtail EOL 2026-03-02) |
| Tracing | OTel SDK → OTLP collector → backend |
| Python | `structlog` / `opentelemetry-instrumentation-fastapi` / Prometheus client |
| Rust | `tracing` + `tracing-subscriber` (JSON) / `tracing-opentelemetry` / `metrics-exporter-prometheus` |

## Anti-Patterns

| Don't | Why |
|-------|-----|
| Log PII or secrets | Compliance and security risk |
| Use unstructured log lines | Can't query, aggregate, or alert |
| Alert on every individual error | Alert fatigue — alert on rates |
| Skip trace context in cross-service calls | Can't follow requests across boundaries |
| High-cardinality labels (e.g., user IDs) | Prometheus OOM, index explosion |
| Log full request/response bodies | Storage cost + PII risk |
