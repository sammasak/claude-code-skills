# Re-Review: observability-patterns (Round 4)

## Previous Score: 9/10
## New Score: 9/10

The R4 fixes address two of the three gaps identified in R3 (exemplars and sampling strategy). Both additions are technically accurate, well-placed, and appropriately concise. The third R3 gap (`scrape_native_histograms` opt-in note) was not addressed. No regressions introduced. The file remains factually accurate and structurally sound, but the remaining omission prevents a perfect score.

---

## R3 Gap Fixes: Verification

### FIXED: Exemplar linkage (was gap #2 in R3)

**R3 assessment:** "The file teaches metrics, logs, and traces as separate pillars but does not mention exemplars (the mechanism that links a specific metric sample to a trace ID). This is the 'glue' between pillars."

**Fix applied (line 71):**
```
- Attach exemplars to histograms to link metric samples to specific trace IDs — the glue between metrics and traces.
```

**Verification:**

- Exemplars are a Prometheus/OpenMetrics feature that attach key-value pairs (typically `trace_id`) to individual histogram or counter observations. This allows jumping from a metric spike directly to a representative trace. The description "glue between metrics and traces" is accurate.
- Placement in the "Trace Context" section is correct -- exemplars are a trace-context-adjacent concern, attaching trace IDs to metric samples.
- The instruction to "attach exemplars to histograms" is the right scope. Counter exemplars exist but histogram exemplars are the primary use case (linking latency outliers to traces).
- Compatible with the existing Native Histograms guidance on line 55. Native Histograms support exemplars in Prometheus 3.x.

**Verdict:** Fully fixed. Accurate, well-placed, fills the gap identified in R3.

### FIXED: Sampling strategy (was gap #3 in R3)

**R3 assessment:** "The file says 'propagate trace IDs' but does not mention head vs. tail sampling. For high-traffic services, this is a practical concern that teams encounter early."

**Fix applied (line 72):**
```
- Configure head-based sampling (e.g., 10%) for high-traffic services; use tail-based sampling to always capture errors.
```

**Verification:**

- **Head-based sampling** makes the keep/drop decision at trace creation (before any spans are recorded). The 10% example is a reasonable default for high-traffic services and matches common OTel SDK configurations.
- **Tail-based sampling** makes the decision after the trace completes, allowing retention of traces based on outcome (errors, high latency, etc.). The guidance to "always capture errors" via tail sampling is the standard recommendation.
- The two strategies are correctly presented as complementary, not mutually exclusive. In practice, most production deployments use head-based sampling as a baseline with tail-based sampling to retain interesting traces that head sampling would otherwise drop.
- This belongs in the "Trace Context" section, which is where it was placed.

**Verdict:** Fully fixed. Accurate, practical, appropriately concise for a skill file.

### NOT FIXED: `scrape_native_histograms` config opt-in (was gap #1 in R3)

**R3 assessment:** "The current Native Histograms mention is good, but a reader might not know that scraping them requires explicit opt-in via config (it is not enabled by default even in 3.8+). One sentence would suffice."

Line 55 remains unchanged:
```
> Prometheus 3.8+ Native Histograms (stable) give better latency distribution resolution at lower storage cost than classic histograms — prefer them for new instrumentation.
```

No mention that scraping native histograms requires setting `scrape_native_histograms: true` in the scrape config (or the global `scrape_config_defaults`). A reader following this advice ("prefer them for new instrumentation") would instrument their code correctly but might not see native histograms in Prometheus because the scrape config was not updated.

**Impact on score:** Minor but real. This is the one remaining actionable gap -- it affects whether a reader can successfully follow the guidance without external research. It is the kind of operational detail that a skill file should include because it is non-obvious and causes silent failure (metrics fall back to classic histograms without error).

---

## Structural Integrity Check

| Check | Result |
|-------|--------|
| YAML frontmatter valid | Yes. `allowed-tools: Bash, Read, Grep, Glob` -- comma-separated, consistent with other skills. |
| All markdown tables render | Yes. Six tables, all have correct header/separator/row structure. |
| Code blocks closed | Yes. One JSON block (lines 32-34), properly fenced. |
| No broken links | All five reference URLs checked in R3 and confirmed valid. |
| Checklist syntax | Yes. Seven `- [ ]` items, all valid GitHub-flavored markdown. |
| No orphaned references | All tools, standards, and projects mentioned are either explained in context or linked in References. |
| Line count | 129 lines. Reasonable for scope. |
| No regressions from R3 | Confirmed. The two new lines (71, 72) do not break surrounding content. The diff shows clean insertions. |

---

## Full Content Assessment

The file now covers:

- Three pillars with clear question/shape mapping (table, lines 16-20)
- Profiling as fourth signal with OTLP version (line 22)
- Structured logging with JSON example and log level table (lines 30-43)
- RED method with metric examples (lines 47-53)
- Native Histograms recommendation (line 55)
- USE method for infrastructure (lines 57-63)
- Four Golden Signals cross-reference (line 65)
- Trace context propagation with W3C standard (lines 69-70)
- **NEW:** Exemplar linkage between metrics and traces (line 71)
- **NEW:** Head-based and tail-based sampling guidance (line 72)
- Required endpoints with modern paths and alternatives (lines 76-79)
- Pre-staging checklist (lines 84-91)
- Tooling stack: kube-prometheus-stack, Loki + Alloy, OTel (lines 95-99)
- Language-specific library table for Python and Rust (lines 103-106)
- Dashboard guidance (line 108)
- Anti-patterns table with seven entries (lines 112-119)
- Six references including book (lines 122-129)

This is comprehensive for an application-level instrumentation guide.

---

## Scoring Breakdown

| Category | R3 Score | R4 Score | Notes |
|----------|----------|----------|-------|
| Technical accuracy | 10/10 | 10/10 | All statements verified across R3 and R4. Zero errors. New additions (exemplars, sampling) are accurate. |
| Completeness | 8/10 | 9/10 | Exemplars and sampling strategy now covered. The only remaining actionable gap is the `scrape_native_histograms` opt-in note. |
| Currency (up-to-date) | 9/10 | 9/10 | Unchanged. All major developments through early 2026 reflected. |
| Clarity and usability | 9/10 | 9/10 | Unchanged. The two new bullet points in Trace Context read naturally and maintain the section's flow. |
| References | 9/10 | 9/10 | Unchanged. All valid and current. |

**Weighted average: 9/10**

---

## Why Not 10/10

The file is one sentence away from a perfect score. The single remaining gap:

1. **`scrape_native_histograms` opt-in** -- Line 55 recommends native histograms but does not mention the required scrape config change. This creates a "silent failure" scenario: a developer instruments correctly, deploys, and sees classic histograms instead of native ones because the Prometheus scrape config was not updated. A parenthetical such as "(requires `scrape_native_histograms: true` in scrape config)" would close this gap.

This is not a factual error. It is an omission of a non-obvious operational step that directly follows from existing guidance. For a skill file that otherwise excels at practical, actionable advice, this last-mile gap is the single thing preventing a perfect score.

---

## Final Verdict

The R4 fixes are well-executed. Exemplars and sampling strategy are accurately described and correctly placed in the Trace Context section, filling two of the three gaps identified in R3. The file has improved steadily across four rounds: 6/10 -> 8/10 -> 9/10 -> 9/10. The score holds at 9/10 because the one remaining gap (`scrape_native_histograms` opt-in) was not addressed. Fix that single line and the file reaches 10/10.

**Score: 9/10**
