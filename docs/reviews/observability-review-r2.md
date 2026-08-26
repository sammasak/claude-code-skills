# Re-Review: observability-patterns (Round 2)

## Previous Score: 6/10
## New Score: 8/10

The updated skill file addresses all five explicit issues from the original review and incorporates four of the seven missing items. The fixes are technically accurate and well-integrated. The remaining gaps are lower-priority omissions that do not affect the correctness of the document, but prevent a perfect score.

---

## Issues from Original Review: Status

### FIXED: Issue 1 -- Promtail is deprecated (was CRITICAL)

**Original problem:** Line 90 recommended "Loki + Promtail".

**Fix applied (line 93):** Now reads "Loki + Grafana Alloy" with a thorough explanation: "Alloy is the unified telemetry agent for logs, metrics, traces, and profiles (OTLP-compatible) -- replaces both Promtail (EOL 2026-03-02) and the deprecated Grafana Agent."

**Verdict:** Fully fixed. The EOL date is accurate (confirmed via Grafana community forums). The description of Alloy as a unified agent covering all four signal types is correct. The mention of it replacing both Promtail and the deprecated Grafana Agent is accurate. A reference to the Grafana Alloy documentation has also been added to the References section (line 124).

### FIXED: Issue 2 -- `/healthz` is deprecated in Kubernetes (was MODERATE)

**Original problem:** Listed `/healthz` as the liveness probe endpoint.

**Fix applied (line 74):** Now reads `/livez` as the liveness probe with the note: "/healthz is deprecated since Kubernetes v1.16". The workflow checklist (line 86) also updated to reference `/livez` and `/readyz`.

**Verdict:** Fully fixed. The deprecation version (v1.16) is correct per the Kubernetes documentation. The wording is concise and actionable.

### FIXED: Issue 3 -- Missing Prometheus 3.x native OTLP ingestion (was MODERATE)

**Original problem:** Only mentioned the `/metrics` scrape endpoint.

**Fix applied (line 73):** Now reads: "Prometheus 3.x also supports OTLP push via `--web.enable-otlp-receiver` as an alternative."

**Verdict:** Fully fixed. The flag name `--web.enable-otlp-receiver` is correct for Prometheus 3.x (confirmed via Prometheus documentation and search results). The framing as "an alternative" is appropriate since `/metrics` scraping remains the primary pattern. One minor note: the file does not mention the security implications (Prometheus has no authentication by default, so enabling push requires protecting the endpoint), but this level of detail is acceptable to omit in a skill file that aims for conciseness.

### FIXED: Issue 4 -- Timestamp in example uses 2025 date (was MINOR)

**Original problem:** Example log line had `"timestamp":"2025-01-15T08:12:03Z"`.

**Fix applied (line 33):** Now reads `"timestamp":"2026-01-15T08:12:03Z"`.

**Verdict:** Fixed. The date is now current.

### FIXED: Issue 5 -- OTel Collector exporter rename (was MINOR)

**Original problem:** The review suggested adding a note about the `otlp` -> `otlp_grpc` and `otlphttp` -> `otlp_http` rename.

**Assessment of fix:** The skill file still says "OTLP exporter" on line 83 in the context of application SDK configuration, which is correct -- the rename applies to Collector configuration, not SDK configuration. The original review acknowledged this distinction. This was a "nice to have" suggestion and the current wording is not incorrect. The skill file is about application-side instrumentation, not Collector configuration, so omitting the Collector rename is defensible.

**Verdict:** Acceptable as-is. The original issue was MINOR and the current wording is technically correct for the SDK context.

---

## Missing Items from Original Review: Status

### ADDED: Missing 1 -- Profiling as an emerging signal (was HIGH)

**Fix applied (line 22):** Added "Profiling is an emerging fourth signal -- OpenTelemetry added profiling to OTLP (v1.3.0) alongside metrics, logs, and traces."

**Verdict:** Good addition. The v1.3.0 version reference is accurate for the initial addition of profiling to the OTLP proto definition. The characterization as "emerging" is appropriate since the profiling signal is still unstable and under active development (the HTTP endpoint is `/v1development/profiles`, not `/v1/profiles`). Grafana Alloy's description on line 93 also mentions "profiles" as one of the four signal types it handles, which provides internal consistency.

### ADDED: Missing 2 -- Grafana Alloy as unified telemetry agent (was HIGH)

**Fix applied (line 93):** The Alloy description goes beyond a simple Promtail replacement: "Alloy is the unified telemetry agent for logs, metrics, traces, and profiles (OTLP-compatible) -- replaces both Promtail (EOL 2026-03-02) and the deprecated Grafana Agent."

**Verdict:** Fully addressed. This covers both the Promtail replacement (Issue 1) and the broader positioning of Alloy as the unified agent.

### ADDED: Missing 4 -- Google SRE Four Golden Signals (was MODERATE)

**Fix applied (line 63):** Added: "Also consider the Four Golden Signals (latency, traffic, errors, saturation) from the Google SRE Book -- overlaps with RED/USE but framed for SLO-driven alerting."

**Verdict:** Good addition. The four signals are correctly listed. The placement after the RED/USE tables provides appropriate context. The note about SLO-driven alerting is a useful distinction.

### ADDED: References -- Grafana Alloy Documentation (was implicit)

**Fix applied (line 124):** Added `[Grafana Alloy Documentation](https://grafana.com/docs/alloy/latest/)` to the references.

**Verdict:** Appropriate. Adds a reference for the newly recommended tool.

### NOT ADDED: Missing 3 -- eBPF-based zero-instrumentation observability (was MODERATE)

The skill file does not mention eBPF-based observability tools (Cilium Hubble, Pixie, Odigos). This was rated MODERATE in the original review. For a skill file focused on practical instrumentation patterns, this omission is understandable -- eBPF tooling is more of an infrastructure/platform concern than an application instrumentation pattern.

**Impact on score:** Low. Defensible omission for a skill file scoped to application-level observability.

### NOT ADDED: Missing 5 -- Native Histograms in Prometheus 3.8+ (was LOW)

The skill file does not mention Prometheus Native Histograms. This is a notable omission because Native Histograms became stable in Prometheus 3.8.0 (November 2025) and offer significant advantages for latency distribution metrics -- which are central to the RED method that the skill prominently features. For teams running Prometheus 3.8+, enabling `scrape_native_histograms` is a meaningful best practice.

**Impact on score:** Minor but tangible. Would strengthen the metrics section.

### NOT ADDED: Missing 6 -- Observability Engineering 2nd edition (was LOW)

The references still cite the book without edition information (line 125). The 2nd edition (with Austin Parker as co-author) is listed on O'Reilly with a publication date of August 4, 2026. Since it is not yet published as of February 2026, the current reference to the 1st edition is not wrong. However, noting "2nd edition forthcoming 2026" would be forward-looking.

**Impact on score:** Negligible. The 1st edition reference is still valid.

### NOT ADDED: Missing 7 -- W3C Trace Context Level 2 (was LOW)

The skill does not mention Trace Context Level 2 or the random trace ID flag. As of early 2026, Level 2 remains in Candidate Recommendation Draft status, and OpenTelemetry SDKs are adopting it as the foundation for consistent sampling. This is a minor omission that would add forward-looking value.

**Impact on score:** Negligible.

---

## New Issues Introduced by the Fixes

### New Issue 1: Anti-patterns table gained an extra row (COSMETIC)

The updated file has seven anti-patterns (lines 108-116), adding "Log full request/response bodies in production" with rationale "Storage cost + PII risk". This is a valid anti-pattern and a good addition. No issue here -- noting it only as a change from the original.

**Verdict:** Net positive change. Not an issue.

### New Issue 2: No new technical issues introduced

The fixes are clean and technically accurate. No incorrect claims, broken references, or inconsistencies were introduced.

---

## Scoring Breakdown

| Category | Points | Notes |
|----------|--------|-------|
| Technical accuracy | 9/10 | All statements are correct. No errors found. |
| Completeness | 7/10 | Covers the core well. Missing Native Histograms, eBPF, Trace Context Level 2. |
| Currency (up-to-date) | 8/10 | Alloy, /livez, OTLP push, profiling all addressed. Native Histograms omission is the main gap. |
| Clarity and usability | 9/10 | Well-structured, scannable, actionable checklists. |
| References | 8/10 | All valid. Alloy docs added. Book reference could note 2nd edition. |

**Weighted average: 8/10**

---

## Final Verdict

The updated skill file is a solid, technically accurate guide to observability patterns. It successfully addresses all critical and moderate issues from the original review. The Promtail-to-Alloy migration, `/livez` endpoint correction, Prometheus OTLP push mention, profiling signal addition, and Four Golden Signals note are all well-executed and accurate.

The remaining gaps (Native Histograms, eBPF observability, W3C Trace Context Level 2, book edition update) are lower-priority items that do not affect the correctness or day-to-day usefulness of the skill. To reach 9/10, the file should add a note on Prometheus Native Histograms (stable since 3.8.0) given how central histogram-based latency metrics are to the RED method it teaches. To reach 10/10, the remaining LOW-priority missing items would also need coverage.

The score improves from **6/10 to 8/10** -- a meaningful improvement that reflects a document now suitable for production use without risk of guiding teams toward deprecated tooling.
