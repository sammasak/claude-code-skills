---
name: pcap-evidence-analysis
description: "Use when analysing an 802.11 capture offline — identifying beacons, management-frame breakdown, and deauth/disassoc reason codes — without transmitting anything or touching a device."
allowed-tools: Bash
---

# PCAP Evidence Analysis

Offline, evidence-first analysis of a captured `.pcap` (e.g. from the naked-pi
rf-lab kit). Read-only: it never transmits, associates, or touches a radio — it
reads a file. Use it to recognise what happened in a trace (who was beaconing,
whether a disconnect was an AP-managed deauth vs a channel problem) and to turn a
capture into a sanitized, reproducible finding.

Distinguish **observed** (what the pcap contains) from **inferred** (what you
conclude). A single signal — one deauth frame, one RSSI dip — is evidence, not
proof; state the confidence.

## Management-frame breakdown

```bash
tshark -r "$pcap" -Y 'wlan.fc.type==0' -T fields -e wlan.fc.type_subtype \
  | sort | uniq -c | sort -rn
```

Subtypes worth naming: `0x08` beacon, `0x04` probe-req, `0x05` probe-resp,
`0x00/0x01` assoc req/resp, `0x0b` auth, `0x0a` disassoc, `0x0c` deauth.

## Deauth / disassoc with reason codes (how a disconnect looks)

```bash
tshark -r "$pcap" -Y 'wlan.fc.type_subtype==0x0c || wlan.fc.type_subtype==0x0a' \
  -T fields -e wlan.sa -e wlan.da -e wlan.fixed.reason_code \
  | sort | uniq -c | sort -rn
```

A deauth/disassoc frame in the trace with a reason code (e.g. 1 unspecified,
7 class-3-from-nonassociated, 15 4-way-timeout) is how an AP-managed disconnect
appears. Absence of such frames alongside an RSSI collapse points at channel
degradation instead — compare, don't assume.

## AP inventory (beacons → SSID/channel/signal)

```bash
tshark -r "$pcap" -Y 'wlan.fc.type_subtype==0x08' \
  -T fields -e wlan.bssid -e wlan.ssid -e wlan_radio.channel -e wlan_radio.signal_dbm
```

SSIDs come out hex; decode with a small awk `strtonum("0x"..)` loop per byte.

## In the homelab

`devenv tasks run rf:analyze` (nixos-config) wraps this over the newest capture
in `~/rf-lab-captures` (set `RF_PCAP` for a specific file). Capture with the
rf-lab kit's `rf:beacons` / `rf:capture`; analyse here. Never present a simulated
or crafted fixture as a hardware observation.

## Provenance

The evidence-first / observed-vs-inferred / record-versions discipline is adapted
from [morluto/rea](https://github.com/morluto/rea) (MIT) — design patterns only,
no code. See `docs/rea-wireless-re-comparison.md`.
