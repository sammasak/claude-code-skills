# Self-Improving Agentic System: OTel + User Feedback Design

**Date:** 2026-03-12
**Status:** Research / Design
**Scope:** claude-worker + doable.sammasak.dev
**Not covered:** Implementation plan (pending separate writing-plans phase)

---

## Problem Statement

Every insight from the doable UX research (sessions ending 2026-03-12) required a human researcher to observe, reason, and score manually. The 4/10 → ~8.5/10 journey improvement across 6 iterations represents expensive researcher effort. The eval harness (67 synthetic trigger cases, 92.5% accuracy) runs on demand rather than continuously.

**Goal:** Instrument the system so that production signal — OTel traces + user interaction feedback — closes the improvement loop without requiring a researcher to observe every run.

---

## Grounding Observations from Doable Research

| Observation | Current State | Target State |
|-------------|--------------|--------------|
| Journey scoring was manual (4/10 scale) | Researcher assigns score post-session | Composite quality_score computed from 4 automated signals |
| Activity noise required hand-crafted regex | Static filter rules tuned manually | `noise_ratio` metric per skill — noisy skills flagged automatically |
| Real success signal = "deployed URL works" | Binary `status=done`, URL stored but not verified | `deploy.verify` span checks URL liveness; this becomes the primary success metric |
| Trigger failures identified by running evals | 67 synthetic cases, run manually | Production goal traces compared against expected routing; drift triggers GEPA |
| UX improvement required 6 manual iterations | Researcher identifies friction, fixes manually | Revision detection identifies dissatisfaction; quality score feeds eval expansion |

---

## Architecture: Three Feedback Loops

The system needs three closed loops, not one. Each has a distinct signal source, threshold, and action:

```
┌─────────────────────────────────────────────────────────────────┐
│  Loop 1: Routing Quality → GEPA                                  │
│  Signal:  production (goal_text, skill_routed) pairs            │
│  Measure: rolling trigger accuracy on real traffic              │
│  Threshold: drops >2pp below baseline over 50 goals             │
│  Action:  queue GEPA run → human approves write-back            │
├─────────────────────────────────────────────────────────────────┤
│  Loop 2: Output Quality → Eval Expansion                         │
│  Signal:  composite quality_score from 4 user signals           │
│  Measure: quality_score < 0.4 AND failure_type classified       │
│  Threshold: 3+ low-quality goals in same failure category       │
│  Action:  propose new eval cases → human approves → add harness │
├─────────────────────────────────────────────────────────────────┤
│  Loop 3: Infrastructure Health → Alert                           │
│  Signal:  bash exit codes, deploy.verify HTTP status            │
│  Measure: tool_call_error_rate, deployment_success_rate         │
│  Threshold: error_rate > 20% OR deployment_success_rate < 80%  │
│  Action:  Grafana alert + Slack notification (no auto-fix)      │
└─────────────────────────────────────────────────────────────────┘
```

---

## OTel Instrumentation

### Signal Types and Fit

| OTel Signal | Use for | Not for |
|-------------|---------|---------|
| **Traces (spans)** | Causal chain per goal: which skills → which tools → outcome | Aggregation (use metrics for that) |
| **Metrics (Prometheus)** | Rolling rates, SLAs, regression detection | Debugging individual runs (use traces) |
| **Logs (Loki)** | Activity stream with `goal_id` + `filtered` attributes | The source of truth on outcome (use metrics) |

### Key Spans

| Span Name | Attributes | Derived Metric |
|-----------|-----------|----------------|
| `goal.execute` | goal_id, goal_text_hash, skill_routed | Root span — anchors all child spans |
| `skill.dispatch` | skill_name, confidence, alternatives[] | feeds `skill_routing_accuracy` |
| `tool.call` | type (bash/read/write/search), exit_code, retry_count | feeds `tool_call_error_rate` |
| `activity.line` | text, filtered=true/false | feeds `noise_ratio` |
| `deploy.verify` | url, http_status, ttfb_ms | **primary success signal** |
| `goal.complete` | outcome, failure_type, token_count | goal-level outcome record |

### Instrumentation Points in claude-worker

The existing PostToolUse/Bash and Stop hooks are the ideal instrumentation surface — they fire on every tool call and goal completion without touching the Rust service. Shell scripts can emit spans via `otelcli`.

```
PostToolUse/Bash hook → emit tool.call span (exit_code, command_length)
PostToolUse/Write|Edit hook → emit tool.call span (type=write, bytes_written)
Stop hook → emit goal.complete span (outcome, skills_invoked[])
claude-worker Rust service → goal.execute root span (wrap the claude -p subprocess)
```

### Key Metrics

```prometheus
# Goal outcomes
goal_success_total{skill_routed, failure_type}       # counter
goal_duration_seconds{skill_routed}                  # histogram (p50, p95, p99)
deployment_success_rate                              # gauge, rolling 50 goals

# Routing
skill_routing_accuracy                               # gauge, from periodic eval runs
skill_dispatch_total{skill_name, correct=true/false} # counter (needs labelling)

# Execution health
tool_call_error_rate{tool_type}                     # gauge
activity_noise_ratio{skill_routed}                  # gauge (filtered/total)
context_window_pct_used                             # histogram

# User feedback
goal_reviewed_total                                  # counter
goal_quality_score                                   # histogram
goal_revision_rate                                   # gauge (revisions / total goals)
deployed_url_click_through_rate                      # gauge
```

---

## User Interaction Signals

### The Four Signals and Their Reliability

| Signal | Reliability | Latency | Notes |
|--------|------------|---------|-------|
| `reviewed` status | High (binary, no ambiguity) | Minutes–hours | Already exists. Enrich with `seconds_to_review`. |
| Revision request | High (strongest dissatisfaction signal) | Hours | Detect via keyword match on follow-up goals + `parent_goal_id` linkage |
| Explicit rating (thumbs/stars) | High precision, low frequency | Seconds | Requires UI change. Most direct quality signal. |
| Deployed URL click-through | Behavioral (hardest to fake) | Minutes | Instrument "Open ↗" click in doable UI |

### Composite Quality Score

```
quality_score(goal) =
  0.4 × (explicit_rating / max_rating)           # most direct signal
  + 0.3 × (1 - revision_within_24h)             # strong implicit dissatisfaction
  + 0.2 × url_opened                             # behavioral acceptance
  + 0.1 × sigmoid(1 / seconds_to_review)        # speed proxy for confidence

Range: [0.0, 1.0]
Threshold for "low quality": < 0.4
```

**Calibration requirement (from eval framework research):** Before trusting this score to trigger any automated action, correlate against 20-30 human spot-checks. If goals with explicit thumbs-up have composite scores > 0.7 and thumbs-down goals score < 0.4, the formula is well-calibrated. If not, revise weights.

### Enriched Goal Outcome Record

Extend `goals.json` (or a companion `goal-outcomes.jsonl` for append-only telemetry):

```json
{
  "id": "goal-abc123",
  "goal_text_hash": "sha256:...",
  "outcome": {
    "status": "done",
    "deployed_url": "https://app.sammasak.dev",
    "url_verified": true,
    "url_http_status": 200,
    "skills_invoked": ["kubernetes-gitops", "container-workflows"],
    "failure_type": null,
    "token_count": 45000,
    "tool_call_counts": {"bash": 23, "read": 15, "write": 8},
    "activity_noise_ratio": 0.38,
    "duration_seconds": 847
  },
  "feedback": {
    "reviewed": true,
    "seconds_to_review": 312,
    "explicit_rating": 4,
    "revision_goal_id": null,
    "url_opened": true,
    "url_open_count": 2
  },
  "quality_score": 0.82,
  "trace_id": "otel-trace-id-abc"
}
```

---

## Failure Classification

Low-quality goals (quality_score < 0.4) are classified automatically from trace attributes:

| Failure Type | Detection Signal | Loop Triggered |
|-------------|-----------------|----------------|
| **Infra failure** | bash exit codes ≠ 0 for >40% of tool calls | Loop 3: alert |
| **Routing failure** | skill dispatched ≠ expected category (heuristic or human label) | Loop 1: add to trigger harness |
| **Quality failure** | Completed + URL exists + user rated low / revised | Loop 2: propose solving eval case |
| **Scope failure** | activity_noise_ratio > 0.5 AND goal completion time > 2× p95 | Loop 2: flag skill description for review |

---

## Human Gates (Non-Negotiable)

These steps must remain human-approved regardless of automation level:

1. **GEPA write-back** — a bad skill description misroutes every future goal. Asymmetric downside risk. Human reviews the proposed description diff before apply.

2. **Eval case approval** — low-quality eval cases degrade the harness. Human spot-checks proposed cases (2 min/case) before they enter the test set.

3. **Quality score calibration** — the composite score is a hypothesis until validated. Run calibration against 20-30 human-rated goals before the score triggers anything automated.

---

## Novel Value: Production Trajectory Dataset

The highest-leverage long-term outcome of this instrumentation is not GEPA re-runs. It is a **production trajectory dataset**: full OTel traces + user-rated outcomes for real goals submitted by real users.

Current state: 67 synthetic trigger cases, zero production cases.
Target state: production cases accumulate at the rate of real usage, automatically annotated with quality signals.

This addresses the central weakness of the current eval harness: it tests synthetic goals in isolated conditions. A system with production trajectories can detect **distribution shift** — when the types of goals users submit change over time, moving the eval harness further from reality. Synthetic cases cannot detect this.

---

## What This Is Not

- Not replacing the human eval approval step
- Not running GEPA continuously (too expensive, diminishing returns)
- Not building a neural net on top of this data
- Not fully autonomous — the system detects and proposes; humans decide and apply

The "self-improving" claim is bounded but honest: the system detects its own degradation, classifies failure modes, and proposes targeted improvements. Humans approve the proposals. This is the correct balance given: (a) GEPA cost per run, (b) bad descriptions cause real user harm, (c) feedback signal quality is unvalidated until calibrated.

---

## Dependencies

| Component | What's Needed | Status |
|-----------|--------------|--------|
| otelcli | Shell-scriptable OTel span emitter | Not installed |
| Prometheus | Already deployed in observability stack | ✓ Ready |
| Grafana + Loki | Already deployed | ✓ Ready |
| Tempo (optional) | Full trace storage; Loki can store traces too | Not deployed |
| doable UI | Thumbs rating + click tracking on "Open ↗" | Requires UI change |
| goals API | New `/goals/:id/feedback` endpoint | Requires API change |
| goal-outcomes.jsonl | Enriched outcome record storage | Requires service change |

---

## References

- Doable UX research notes: `/home/lukas/.claude/projects/-home-lukas/memory/MEMORY.md` (session 2026-03-12)
- Eval framework: `~/claude-code-skills/evals/README.md`
- Trigger eval results: 92.5% (62/67), March 2026
- GEPA: arXiv:2507.19457, ICLR 2026 Oral
- τ-bench pass^k methodology: arXiv:2406.12045
- SWE-bench contamination: arXiv:2506.12286
