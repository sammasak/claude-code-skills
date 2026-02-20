# Review: observability-patterns

## Score: 6/10

The skill file provides a solid foundational overview of observability patterns, but contains several outdated recommendations and is missing important developments from 2025-2026 that meaningfully affect day-to-day practice. The most critical issue is the recommendation of Promtail, which reaches end-of-life on March 2, 2026 and has been superseded by Grafana Alloy. Additionally, the file omits Prometheus 3.x's native OTLP ingestion, the emerging profiling signal, and the deprecation of `/healthz` in favor of `/livez`.

## Findings

### Accurate

- **Three pillars table (Metrics, Logs, Traces):** The framing of "WHAT / WHY / WHERE" mapped to the three pillars is clear and still a well-accepted mental model.
- **Structured logging as JSON:** Still universally recommended. The example log line includes `trace_id`, `level`, `timestamp`, and contextual fields -- all correct.
- **Log levels table:** The four levels and their meanings are conventional and appropriate. The guidance to never run DEBUG in production is sound.
- **RED method table:** Rate, Errors, Duration with Prometheus metric name examples (`http_requests_total`, `http_request_duration_seconds`) follows Prometheus naming conventions correctly.
- **USE method table:** Utilization, Saturation, Errors for infrastructure resources is correctly described and attributed.
- **W3C Trace Context (`traceparent` header):** Still the standard propagation format. The W3C Trace Context Level 1 is a W3C Recommendation and Level 2 is in Candidate Recommendation. OpenTelemetry SDKs default to W3C propagation. This recommendation is correct.
- **"Alert on symptoms, not causes":** This is canonical SRE guidance from the Google SRE Book and remains best practice.
- **"Instrument at system boundaries":** Correct guidance. HTTP handlers, queue consumers, and DB calls are the right places to instrument.
- **kube-prometheus-stack:** Still the standard batteries-included monitoring stack for Kubernetes. The latest Helm chart version is 82.x as of early 2026.
- **OpenTelemetry SDK with OTLP exporter:** OTLP remains the recommended protocol. OTLP spec is at v1.9.0. The collector-based architecture (app -> OTLP -> collector -> backend) is still the canonical pattern.
- **structlog for Python:** Still the recommended structured logging library. Latest version is 25.5.0 (October 2025). Actively maintained and healthy.
- **Rust `tracing` + `tracing-subscriber`:** Still the de facto standard for Rust instrumentation. Latest version is 0.1.44 (December 2025). `tracing-opentelemetry` is still the correct bridge crate.
- **Anti-patterns table:** All six anti-patterns listed are accurate and important. High-cardinality label warnings, PII logging risks, and alert fatigue guidance are all current best practices.
- **Grafana dashboard per service with four panels:** Request rate, error rate, p50/p95/p99 latency, and active requests is a well-accepted minimum dashboard layout.
- **YAML frontmatter:** Follows Claude Code skill format correctly with `name`, `description`, and `allowed-tools` fields.

### Issues

#### 1. Promtail is deprecated -- recommend Grafana Alloy instead (CRITICAL)

**What it currently says (line 90):**
> Log aggregation: Loki + Promtail. Query with LogQL.

**What it should say:**
> Log aggregation: Loki + Grafana Alloy. Query with LogQL.

Promtail was deprecated by Grafana Labs in early 2025. Its Long-Term Support period ends February 28, 2026, and it reaches End-of-Life on March 2, 2026. Grafana Alloy is the official successor -- it is an open-source distribution of the OpenTelemetry Collector that handles logs, metrics, traces, and profiles in a single agent. Grafana provides a migration command (`alloy convert --source-format=promtail`) to ease the transition.

**Sources:**
- [Grafana Alloy migration from Promtail](https://grafana.com/docs/alloy/latest/set-up/migrate/from-promtail/)
- [Loki docs: Migrate to Alloy](https://grafana.com/docs/loki/latest/setup/migrate/migrate-to-alloy/)
- [Big Bang ADR: Alloy replacing Promtail](https://docs-bigbang.dso.mil/latest/docs/adrs/0004-alloy-replacing-promtail/)

#### 2. `/healthz` is deprecated in Kubernetes -- should mention `/livez` (MODERATE)

**What it currently says (lines 70-72):**
> - `/healthz` -- Liveness probe (is the process alive?)
> - `/readyz` -- Readiness probe (can it serve traffic?)

**What it should say:**
> - `/livez` -- Liveness probe (is the process alive?)
> - `/readyz` -- Readiness probe (can it serve traffic?)
> - `/healthz` -- Deprecated alias for liveness (still widely used, but `/livez` is preferred since Kubernetes v1.16)

The `/healthz` endpoint was deprecated in Kubernetes v1.16 in favor of the more specific `/livez` and `/readyz` endpoints. As of Kubernetes 1.35 (December 2025), the z-page convention is expanding further with structured, machine-parseable responses. While `/healthz` is still broadly recognized in application code, the skill should reflect the current Kubernetes convention of `/livez` + `/readyz`.

**Sources:**
- [Kubernetes API health endpoints](https://kubernetes.io/docs/reference/using-api/health-checks/)
- [Kubernetes 1.35: Enhanced z-pages](https://kubernetes.io/blog/2025/12/31/kubernetes-v1-35-structured-zpages/)

#### 3. Missing Prometheus 3.x native OTLP ingestion (MODERATE)

**What it currently says (line 79):**
> Prometheus metrics endpoint exposed at `/metrics`

The file does not mention that Prometheus 3.0 (released late 2024) now supports native OTLP metric ingestion via `--web.enable-otlp-receiver`, accepting pushes at `/api/v1/otlp/v1/metrics`. This is a significant architectural option because it means services can push metrics via OTLP directly to Prometheus, potentially simplifying the stack by eliminating the need for a separate OTel Collector for metrics in some topologies. The `/metrics` scrape endpoint is still valid and widely used, but the skill should mention the OTLP push option as an alternative.

**Sources:**
- [Prometheus: Using Prometheus as your OTel backend](https://prometheus.io/docs/guides/opentelemetry/)
- [Grafana: Prometheus 3.0 and OpenTelemetry](https://grafana.com/blog/2024/11/06/prometheus-3.0-and-opentelemetry-a-practical-guide-to-storing-and-querying-otel-data/)

#### 4. Timestamp in example log line uses 2025 date (MINOR)

**What it currently says (line 32):**
> `"timestamp":"2025-01-15T08:12:03Z"`

This is not technically wrong, but using a date in the past makes the example feel dated. A trivial update to a more neutral or current date would keep the document feeling fresh. Alternatively, using a clearly placeholder date is fine.

#### 5. Checklist item wording could note the OTel Collector exporter rename (MINOR)

**What it currently says (line 80):**
> OpenTelemetry tracer initialized with OTLP exporter

The OpenTelemetry Collector has renamed its exporters: `otlp` is now `otlp_grpc` and `otlphttp` is now `otlp_http` (with deprecated aliases for the old names). While the skill is describing application-side SDK configuration (where the terminology has not changed), it would be helpful to add a brief note about the collector-side rename if users are also configuring collectors based on this skill.

**Source:**
- [OpenTelemetry Collector releases](https://github.com/open-telemetry/opentelemetry-collector/releases)

### Missing

#### 1. Profiling as an emerging signal (HIGH)

OpenTelemetry officially announced support for profiling as a new signal type, added to OTLP in v1.3.0. Continuous profiling answers "WHY is the code slow at the function level?" and complements the existing three pillars. Elastic has donated their eBPF-based profiling agent, and Splunk their .NET profiler to the OpenTelemetry project. Major vendors (Datadog, Grafana via Pyroscope, Elastic) are promoting continuous profiling as a production practice. The skill should at minimum acknowledge profiling as an emerging fourth signal.

**Sources:**
- [OpenTelemetry: State of Profiling](https://opentelemetry.io/blog/2024/state-profiling/)
- [OpenTelemetry announces support for profiling](https://opentelemetry.io/blog/2024/profiling/)

#### 2. Grafana Alloy as the unified telemetry agent (HIGH)

Beyond just replacing Promtail for log collection, Grafana Alloy is positioned as a unified agent for logs, metrics, traces, and profiles. It is 100% OTLP compatible and is an open-source distribution of the OpenTelemetry Collector. The "Patterns We Use" section should mention Alloy as the single-agent approach, not just as a Promtail replacement.

**Source:**
- [Grafana: From Agent to Alloy FAQ](https://grafana.com/blog/2024/04/09/grafana-agent-to-grafana-alloy-opentelemetry-collector-faq/)

#### 3. eBPF-based zero-instrumentation observability (MODERATE)

Tools like Cilium Hubble (network observability), Pixie (application observability), and Odigos (zero-code distributed tracing) use eBPF to automatically capture telemetry without code changes. This is a significant trend in 2025-2026. A brief mention in the "Patterns We Use" or a new section on emerging patterns would be valuable.

**Sources:**
- [Cilium: eBPF-based Networking, Security, and Observability](https://cilium.io/)
- [eBPF Applications Landscape](https://ebpf.io/applications/)

#### 4. Google SRE "Four Golden Signals" (MODERATE)

The skill references the RED and USE methods but does not mention Google's Four Golden Signals (latency, traffic, errors, saturation) from the SRE Book Chapter 6, which is linked in the references. The Golden Signals predate and overlap with RED, and many teams use them as their primary framework. A brief note on how RED relates to the Golden Signals would strengthen the document.

**Source:**
- [Google SRE Book Ch. 6](https://sre.google/sre-book/monitoring-distributed-systems/)

#### 5. Native Histograms in Prometheus 3.8+ (LOW)

Prometheus 3.8.0 (November 2025) made Native Histograms a stable feature. Native Histograms provide much better resolution for latency distributions with lower storage cost compared to classic histograms. For teams using Prometheus for RED-method duration metrics, this is a meaningful improvement worth mentioning.

**Source:**
- [Prometheus 3.8.0 release](https://github.com/prometheus/prometheus/releases/tag/v3.8.0)

#### 6. Observability Engineering 2nd edition (LOW)

The referenced book "Observability Engineering" by Majors, Fong-Jones, Miranda has a 2nd edition coming in 2026 with 32 new chapters and a new co-author (Austin Parker). The skill should note that the 2nd edition exists or is forthcoming.

**Source:**
- [O'Reilly: Observability Engineering, 2nd Edition](https://www.oreilly.com/library/view/observability-engineering-2nd/9781098179915/)

#### 7. W3C Trace Context Level 2 (LOW)

The skill correctly recommends W3C Trace Context but does not mention Level 2, which is in Candidate Recommendation status and adds the "random trace ID" flag. OpenTelemetry SDKs are adopting Level 2. This is a minor addition but keeps the document forward-looking.

**Source:**
- [W3C Trace Context Level 2](https://www.w3.org/TR/trace-context-2/)

### References Check

| # | Reference | Status | Notes |
|---|-----------|--------|-------|
| 1 | [Google SRE Book -- Ch. 6](https://sre.google/sre-book/monitoring-distributed-systems/) | VALID | Page is live. Content covers the Four Golden Signals, symptom vs. cause alerting, and white-box vs. black-box monitoring. Still widely regarded as foundational. |
| 2 | [OpenTelemetry Documentation](https://opentelemetry.io/docs/) | VALID | Page is live. Documents OTel Specification v1.54.0, OTLP v1.9.0, Semantic Conventions v1.39.0. Actively maintained (last update August 2025). |
| 3 | [Prometheus Best Practices](https://prometheus.io/docs/practices/) | VALID | Page is live. Covers metric naming conventions, label best practices, and base unit recommendations. Still current. |
| 4 | [Grafana Loki Documentation](https://grafana.com/docs/loki/latest/) | VALID | Page is live. Documents Loki v3.6.x (latest). |
| 5 | "Observability Engineering" -- Majors, Fong-Jones, Miranda (O'Reilly) | VALID | Book is still available and well-regarded. Note: a 2nd edition with Austin Parker as co-author is forthcoming in 2026. The reference should ideally be updated when the 2nd edition ships. |

All five references are valid and relevant.

### Recommendations

#### Priority 1 (Should fix before using in production)

1. **Replace Promtail with Grafana Alloy.** Change line 90 from "Loki + Promtail" to "Loki + Grafana Alloy" and note the `alloy convert` migration tool. Promtail reaches EOL on March 2, 2026.

2. **Update health endpoints to include `/livez`.** Change the required endpoints section to list `/livez` (liveness) and `/readyz` (readiness), with a note that `/healthz` is a deprecated alias still seen in legacy services.

#### Priority 2 (Should fix to stay current)

3. **Add a note about Prometheus 3.x native OTLP ingestion.** Mention that Prometheus can now accept OTLP metric pushes directly, in addition to the traditional `/metrics` scrape model. This affects architecture decisions.

4. **Add profiling as an emerging signal.** Even a single line in the principles or patterns section acknowledging continuous profiling as an emerging fourth signal in OpenTelemetry would keep the document forward-looking.

5. **Mention Grafana Alloy as the unified telemetry agent** in the "Patterns We Use" section, noting it replaces both Promtail and the deprecated Grafana Agent.

#### Priority 3 (Nice to have)

6. **Add a brief mention of the Four Golden Signals** and how RED/USE relate to them, since the Google SRE Book is already referenced.

7. **Note the Observability Engineering 2nd edition** when it becomes available.

8. **Consider adding a brief "Emerging Patterns" section** covering eBPF-based observability (Cilium Hubble, Pixie), zero-instrumentation tracing (Odigos), and continuous profiling (Grafana Pyroscope, Parca).

9. **Update the example timestamp** from 2025 to a current or clearly placeholder date.

10. **Add Prometheus Native Histograms** as a recommended histogram type for new deployments on Prometheus 3.8+, given their stability and storage efficiency advantages.
