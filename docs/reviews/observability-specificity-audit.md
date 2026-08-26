# Specificity Audit: observability-patterns/SKILL.md

## Summary

This skill is remarkably clean compared to many domain skill files. The observability-patterns SKILL.md is overwhelmingly generic and industry-standard. Most of the content (RED/USE methods, three pillars, structured logging, anti-patterns) is textbook material that any team could adopt. However, there are a handful of places where the file crosses from "useful opinionated defaults" into "one team's specific stack presented as universal truth."

## Findings

### Finding 1: Grafana-only stack presented as the universal pattern

**Lines:** 95-108
**Exact text:**
```
**Cluster monitoring:** kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
**Log aggregation:** Loki + Grafana Alloy. Query with LogQL.
**Tracing:** OpenTelemetry SDK in application code, OTLP exporter to a collector, collector forwards to backend.
**Dashboards:** One Grafana dashboard per service.
```

**Assessment:** User-specific stack choice presented as universal.

The entire "Patterns We Use" section prescribes an all-Grafana/Prometheus stack as if it were the only viable option. While this is a popular open-source stack, many organizations use:
- Datadog, New Relic, Splunk, Elastic, or Honeycomb for unified observability
- AWS CloudWatch, GCP Cloud Monitoring, or Azure Monitor for cloud-native stacks
- Jaeger or Zipkin as tracing backends (not just "a backend")
- Elasticsearch/OpenSearch instead of Loki for log aggregation
- VictoriaMetrics or Mimir instead of raw Prometheus

The section heading "Patterns We Use" honestly signals this is a team preference, which is good. But a skill consumed by an LLM will treat this as prescriptive guidance for all projects.

**Suggested fix:** Either (a) rename the section to "Recommended Open-Source Stack" and add a brief note that these are defaults for greenfield projects, not requirements, or (b) restructure as a table of options with the Grafana stack marked as the default:

```markdown
## Default Stack (Open-Source)

The patterns below assume an open-source Grafana/Prometheus stack. Adapt to your
organization's platform (Datadog, Elastic, cloud-native monitoring, etc.) --
the instrumentation principles above are stack-agnostic.

- **Cluster monitoring:** kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
- **Log aggregation:** Loki + Grafana Alloy (LogQL). Alternative: Elasticsearch/OpenSearch.
- **Tracing backend:** Any OTLP-compatible backend (Tempo, Jaeger, vendor-hosted).
- **Dashboards:** One dashboard per service with RED metrics.
```

---

### Finding 2: Language table limited to exactly Python + Rust

**Lines:** 101-107
**Exact text:**
```
| Language | Logging              | Tracing                                      | Metrics                            |
|----------|----------------------|----------------------------------------------|------------------------------------|
| Python   | `structlog` (JSON)   | `opentelemetry-instrumentation-fastapi`       | Prometheus client                  |
| Rust     | `tracing` + `tracing-subscriber` (JSON layer) | `tracing-opentelemetry`       | `metrics` + `metrics-exporter-prometheus` |
```

**Assessment:** User-specific language/framework selection.

Choosing exactly Python and Rust (and no other languages) reflects one team's technology choices, not a universal observability guide. Additionally, the Python tracing column specifies `opentelemetry-instrumentation-fastapi` -- this is a FastAPI-specific auto-instrumentation package, revealing that this team uses FastAPI specifically. A generic skill would either cover more languages or present this as an example rather than a complete table.

**Suggested fix:** Either (a) broaden to cover common languages (Go, Java/Kotlin, TypeScript/Node are all very common in microservice environments) or (b) frame the table as extensible examples:

```markdown
**Language-specific examples** (extend for your stack):

| Language   | Logging                      | Tracing                          | Metrics                              |
|------------|------------------------------|----------------------------------|--------------------------------------|
| Python     | `structlog`                  | `opentelemetry-instrumentation-*` | `prometheus-client`                  |
| Rust       | `tracing` + JSON subscriber  | `tracing-opentelemetry`          | `metrics` + prometheus exporter      |
| Go         | `slog` (stdlib, JSON mode)   | `go.opentelemetry.io/otel`       | `prometheus/client_golang`           |
| TypeScript | `pino` (JSON)               | `@opentelemetry/auto-instrumentations-node` | `prom-client`         |
```

Note: changing `opentelemetry-instrumentation-fastapi` to `opentelemetry-instrumentation-*` removes the FastAPI-specific assumption and lets the guidance apply to Flask, Django, or any Python web framework.

---

### Finding 3: Kubernetes assumed as the only deployment target

**Lines:** 76-79, 83, 90-91, 95
**Exact text:**
```
- `/livez` -- Liveness probe (is the process alive?) -- note: `/healthz` is deprecated since Kubernetes v1.16
- `/readyz` -- Readiness probe (can it serve traffic?)
...
This is the checklist before a service goes to staging:
...
- [ ] Liveness (`/livez`) and readiness (`/readyz`) endpoints
...
**Cluster monitoring:** kube-prometheus-stack
```

**Assessment:** Mildly user-specific but defensible.

The `/livez` and `/readyz` endpoints and kube-prometheus-stack both assume Kubernetes. This is a reasonable default for a skill that also references a kubernetes-gitops companion skill, but it is still an assumption. Services deployed on bare metal, ECS, Lambda, Cloud Run, or Nomad would not need Kubernetes-specific health endpoints or kube-prometheus-stack.

**Suggested fix:** This is borderline acceptable given the skill suite context. A minimal fix would be a parenthetical:

```markdown
- `/livez` -- Liveness probe (is the process alive?) -- Kubernetes convention since v1.16; useful as a general health pattern regardless of platform
```

And for kube-prometheus-stack:
```markdown
**Cluster monitoring (Kubernetes):** kube-prometheus-stack ...
```

---

### Finding 4: "payment failed" example log line

**Line:** 33
**Exact text:**
```json
{"timestamp":"2026-01-15T08:12:03Z","level":"error","msg":"payment failed","trace_id":"abc123","user_id":"u-789","error":"timeout"}
```

**Assessment:** Reasonable example, not user-specific.

This is a well-constructed example. The "payment failed" message, "u-789" user ID, and "abc123" trace ID are clearly illustrative placeholders. The field names (`trace_id`, `user_id`, `error`, `msg`) follow common structured logging conventions. No real hostnames, real service names, or real identifiers are present.

No fix needed.

---

### Finding 5: Grafana dashboard as checklist requirement

**Line:** 91
**Exact text:**
```
- [ ] Grafana dashboard created with RED metrics for the service
```

**Assessment:** User-specific tool choice in a "required" checklist.

This checklist item mandates Grafana specifically, not "a dashboard" generically. The checklist is framed as a gate ("before a service goes to staging"), so this effectively makes Grafana a deployment prerequisite rather than one option among many.

**Suggested fix:**
```markdown
- [ ] Dashboard created with RED metrics for the service (e.g., Grafana, Datadog, or your platform's equivalent)
```

---

### Finding 6: "kube-prometheus-stack" as the only monitoring option

**Line:** 95
**Exact text:**
```
**Cluster monitoring:** kube-prometheus-stack (Prometheus + Grafana + Alertmanager) -- batteries-included for Kubernetes.
```

**Assessment:** User-specific but labeled honestly.

The "batteries-included for Kubernetes" qualifier is helpful and honest. The issue is that this is stated as a flat declaration rather than a recommendation. Combined with the rest of the section, it builds a picture of one specific stack.

**Suggested fix:** Already covered in Finding 1's broader restructuring suggestion.

---

### Finding 7: Prometheus-specific `/metrics` endpoint as universal requirement

**Lines:** 77, 86
**Exact text:**
```
- `/metrics` -- Prometheus scrape target (Prometheus 3.x also supports OTLP push ...)
...
- [ ] Prometheus metrics endpoint exposed at `/metrics`
```

**Assessment:** Mildly user-specific.

The `/metrics` Prometheus scrape endpoint is presented as a universal requirement for "every service." This is only relevant if you run Prometheus. Teams using Datadog, CloudWatch, or OTLP-only pipelines would not expose `/metrics`. The parenthetical about OTLP push partially addresses this, but the framing is still "Prometheus first."

**Suggested fix:**
```markdown
- `/metrics` -- Prometheus scrape target (if using Prometheus); alternatively, push metrics via OTLP to a collector
...
- [ ] Metrics endpoint exposed (`/metrics` for Prometheus, or OTLP exporter configured)
```

---

## Severity Summary

| # | Line(s) | Issue | Severity |
|---|---------|-------|----------|
| 1 | 95-108 | All-Grafana stack presented as universal pattern | HIGH -- shapes every recommendation the LLM will make |
| 2 | 101-107 | Language table limited to Python + Rust; FastAPI-specific package | HIGH -- reveals one team's language choices |
| 3 | 76-79, 95 | Kubernetes assumed as only deployment platform | MEDIUM -- defensible given skill suite, but limits applicability |
| 4 | 91 | Grafana dashboard as deployment gate | MEDIUM -- tool-specific requirement in generic checklist |
| 5 | 77, 86 | Prometheus `/metrics` as universal requirement | LOW -- Prometheus is dominant enough that this is a reasonable default |
| 6 | 33 | "payment failed" example log line | NONE -- good generic example |

## Overall Assessment

The skill is well-written and mostly generic. The core principles (three pillars, RED/USE, structured logging, trace context, alert on symptoms) are industry-standard and tool-agnostic. The specificity issues are concentrated in two areas:

1. **The "Patterns We Use" section** (lines 93-108) -- this is where the team's specific stack choices live. The fix is straightforward: frame these as recommended defaults rather than universal requirements, and acknowledge alternatives exist.

2. **The language table** (lines 101-107) -- the Python + Rust + FastAPI combination is a fingerprint of one team's choices. Broadening or explicitly framing as "examples" would fix this.

Everything above line 93 is essentially textbook observability content with no specificity concerns.
