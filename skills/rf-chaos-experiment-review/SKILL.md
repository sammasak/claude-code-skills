---
name: rf-chaos-experiment-review
description: "Use when reviewing an RF/Wi-Fi/BT chaos or resilience experiment before or after running it — checking bounded execution, enrolled-scope gating, dry-run, machine-readable metrics, rollback, and simulation-vs-hardware provenance. A review gate, not a runner."
allowed-tools: Read, Grep, Bash
---

# RF Chaos Experiment Review

A review discipline for RF / Wi-Fi / Bluetooth chaos and resilience experiments —
the kind that stress a link to measure how it recovers. It gates the experiment
*before* it runs and audits the results *after*. It does not launch transmitters:
reviewing an experiment and running one are separate acts, and this skill is the
former.

RF chaos is uniquely leaky — radio does not stop at a cable or a namespace. The
whole review turns on one question: **can this experiment affect anything the
operator does not own and has not enrolled?** If yes, it fails review.

## Before the run

- **Enrolled-scope gating.** The target must be your own AP or your own paired
  device, named by BSSID / MAC and enrolled in the experiment spec. Anything that
  can reach a neighbour's network, an unpaired third-party device, or shared
  spectrum beyond your equipment is out of scope — refuse it. Broadcast or
  wildcard targets are an automatic fail.
- **Bounded execution.** Every run has a hard stop: a duration cap, a packet/
  iteration budget, a fixed channel and power ceiling within the regulatory
  domain. An experiment that can run unbounded, escalate power, or sweep channels
  freely is not bounded — send it back.
- **Dry-run first.** The spec must support a no-transmit dry run that prints what
  it *would* do (targets, channels, duration, frame counts) without keying the
  radio. Read that output and confirm scope and bounds before any live run is
  even discussed.
- **Rollback defined up front.** Name how the environment is restored: interface
  back to `managed`, device re-paired, regulatory domain reset, services back up.
  No experiment is approved without a restore path.

## Metrics

Results must be machine-readable — JSON or CSV with the measured link-state
quantities (RSSI, retry/loss rate, disassoc count, reconnect latency), not prose.
A number you can diff across runs is a result; a sentence is an anecdote. Require
a baseline capture before the chaos is injected so "degraded" has something to be
degraded *from*.

## After the run

- Confirm rollback actually happened — re-query state, do not assume the script's
  exit code means the radio and devices are restored.
- Check the metrics are present, parse, and carry the run's bounds and target in
  their metadata, so the result is reproducible and self-describing.

## Provenance: simulation vs hardware

Label every result as **simulated** or **hardware-measured**, and never let one
pass as the other. Virtual-radio runs (`mac80211_hwsim`, `wmediumd`) and crafted
packet fixtures are legitimate and safe for developing the experiment — but their
output is a model, not a measurement. A simulated RSSI curve presented as a
hardware observation is a false finding; reject any report that blurs the two or
omits the label. When a run mixes both, each metric carries its own provenance.

In the homelab, `mac80211_hwsim`/`wmediumd` cover the simulated arm and the rf-lab
kit the hardware arm; keep their outputs in separate, clearly-labelled streams and
analyse captures with the `pcap-evidence-analysis` skill.

## Review verdict

Approve only when all hold: enrolled owned target, bounded, dry-run inspected,
machine-readable metrics with a baseline, rollback defined, and provenance
labelled. A miss on any one is a block, not a suggestion — record which and why.

## Provenance

The evidence-first / dry-run / observed-vs-inferred / record-versions discipline
is adapted from [morluto/rea](https://github.com/morluto/rea) (MIT) — design
patterns only, no code. See `docs/rea-wireless-re-comparison.md`.
