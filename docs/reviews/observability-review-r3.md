# Re-Review: observability-patterns (Round 3)

## Previous Score: 8/10
## New Score: 9/10

The R3 update addresses the main remaining issue from R2: the absence of Prometheus Native Histograms. The addition is technically accurate, well-placed, and concise. The skill file is now comprehensive enough for a compact reference document, with only minor omissions remaining that fall outside the reasonable scope of an application-level instrumentation guide.

---

## Primary R2 Issue: Status

### FIXED: Prometheus Native Histograms not mentioned (was the main gap holding the score at 8)

**R2 assessment:** "Native Histograms became stable in Prometheus 3.8.0 (November 2025) and offer significant advantages for latency distribution metrics -- which are central to the RED method that the skill prominently features."

**Fix applied (line 55):** Added a blockquote immediately after the RED method table:

> Prometheus 3.8+ Native Histograms (stable) give better latency distribution resolution at lower storage cost than classic histograms -- prefer them for new instrumentation.

**Verification:**

- Prometheus v3.8.0 was released on November 28, 2025, and is confirmed as the first release with Native Histograms declared stable (source: GitHub release notes and prometheus-announce mailing list).
- The claim of "better latency distribution resolution at lower storage cost" is accurate. Native Histograms use exponential bucketing with configurable resolution, eliminating the need to pre-define bucket boundaries. They store a single histogram sample per scrape rather than one time series per bucket, which dramatically reduces storage and index cardinality.
- The recommendation to "prefer them for new instrumentation" is sound advice. For existing deployments, migration requires enabling `scrape_native_histograms` in scrape configs, but for new instrumentation there is no reason to use classic histograms.
- The placement directly below the RED method's Duration row (which references `http_request_duration_seconds`) is ideal -- this is exactly where a reader would benefit from knowing about the improved histogram type.

**Verdict:** Fully fixed. Technically accurate, well-placed, appropriately concise.

---

## Remaining R2 Gaps: Re-assessment

### NOT ADDED: eBPF-based zero-instrumentation observability (was MODERATE in R2)

Still absent. The R2 review already downgraded the impact of this omission: "For a skill file focused on practical instrumentation patterns, this omission is understandable -- eBPF tooling is more of an infrastructure/platform concern than an application instrumentation pattern."

**Impact on score:** Negligible. This is a platform-team concern, not an application instrumentation pattern. The skill file is correctly scoped to what application developers control.

### NOT ADDED: W3C Trace Context Level 2 (was LOW in R2)

Still absent. As of February 2026, Trace Context Level 2 remains in Candidate Recommendation Draft status at the W3C. It has not yet advanced to full Recommendation. The skill file correctly references W3C Trace Context (Level 1) on line 70, which is the ratified standard. Mentioning Level 2 would be forward-looking but not necessary for current production guidance.

**Impact on score:** Negligible. The current reference to the ratified Level 1 standard is correct and sufficient.

### NOT ADDED: "Observability Engineering" 2nd edition (was LOW in R2)

Still absent. The 2nd edition has a listed publication date of August 4, 2026, which is six months from now. The 1st edition reference on line 127 is valid and current.

**Impact on score:** None. The 1st edition is the published work.

---

## Full Technical Accuracy Audit (R3)

Since this may be the final review round, I performed a line-by-line accuracy check on all factual claims in the skill file.

| Line(s) | Claim | Accurate? |
|----------|-------|-----------|
| 22 | OTel profiling added in OTLP v1.3.0 | Yes |
| 33 | Timestamp 2026-01-15 | Yes (current year) |
| 55 | Native Histograms stable in Prometheus 3.8+ | Yes (v3.8.0, Nov 28 2025) |
| 65 | Four Golden Signals: latency, traffic, errors, saturation | Yes (SRE Book Ch. 6) |
| 70 | W3C Trace Context uses `traceparent` header | Yes |
| 75 | Prometheus 3.x OTLP push via `--web.enable-otlp-receiver` | Yes |
| 76 | `/healthz` deprecated since Kubernetes v1.16 | Yes |
| 95 | Promtail EOL 2026-03-02 | Yes (confirmed via Grafana community forums) |
| 95 | Alloy replaces Promtail and deprecated Grafana Agent | Yes |
| 95 | Alloy covers logs, metrics, traces, and profiles | Yes |
| 122 | SRE Book link | Valid URL |
| 123 | OTel docs link | Valid URL |
| 124 | Prometheus best practices link | Valid URL |
| 125 | Loki docs link | Valid URL |
| 126 | Alloy docs link | Valid URL |

**No factual errors found.**

---

## Scoring Breakdown

| Category | R2 Score | R3 Score | Notes |
|----------|----------|----------|-------|
| Technical accuracy | 9/10 | 10/10 | All statements verified. Zero errors. |
| Completeness | 7/10 | 8/10 | Native Histograms now covered. Remaining gaps (eBPF, Trace Context L2) are out of scope for application-level instrumentation. |
| Currency (up-to-date) | 8/10 | 9/10 | All major developments through early 2026 reflected: Alloy, Native Histograms, OTLP profiling, /livez, OTLP push. |
| Clarity and usability | 9/10 | 9/10 | Unchanged. Well-structured, scannable, actionable. |
| References | 8/10 | 9/10 | All valid. Comprehensive for the scope. Book edition is a non-issue until August 2026. |

**Weighted average: 9/10**

---

## What Would 10/10 Require?

A perfect score for a compact skill file is a high bar. The document would need to leave no meaningful gap for its stated scope. The remaining items that could push it to 10/10:

1. **A one-line note on `scrape_native_histograms` config** -- the current Native Histograms mention is good, but a reader might not know that scraping them requires explicit opt-in via config (it is not enabled by default even in 3.8+). One sentence would suffice.
2. **Exemplar linkage** -- the file teaches metrics, logs, and traces as separate pillars but does not mention exemplars (the mechanism that links a specific metric sample to a trace ID). This is the "glue" between pillars and is a notable omission for a document that emphasizes correlation IDs in logs.
3. **A brief mention of sampling strategy** -- the file says "propagate trace IDs" but does not mention head vs. tail sampling. For high-traffic services, this is a practical concern that teams encounter early.

None of these gaps are errors. They are omissions of useful-but-not-essential content. The document is accurate, current, and actionable as-is.

---

## Final Verdict

The skill file has improved steadily across three review rounds: 6/10 -> 8/10 -> 9/10. The R3 update targeted the single most impactful remaining gap from R2 (Native Histograms) and addressed it with a technically accurate, well-placed addition.

The document is now a reliable, production-ready reference for application-level observability instrumentation. All critical tooling recommendations are current (Alloy over Promtail, /livez over /healthz, OTLP push as an alternative, Native Histograms for new instrumentation). All factual claims have been verified against primary sources.

**Score: 9/10** -- technically accurate, current, well-scoped, and actionable. The remaining distance to 10/10 is three minor content additions (scrape config opt-in, exemplars, sampling strategy) that would enhance completeness but whose absence does not create risk or misguidance.
