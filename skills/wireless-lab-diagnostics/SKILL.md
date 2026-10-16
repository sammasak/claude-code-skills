---
name: wireless-lab-diagnostics
description: "Use when establishing what a Wi-Fi adapter you own can actually do — chipset/driver/firmware, supported modes and interface combinations, regulatory domain, and an explicit monitor-mode pass/fail — before planning any wireless work. Read-only capability discovery, not a transmit or attack tool."
allowed-tools: Bash
---

# Wireless Lab Diagnostics

Capability discovery for a Wi-Fi adapter **you own or are authorised to operate**
(e.g. the rf-lab kit's USB adapter). It answers "what can this radio actually
do?" from the driver and firmware — never from the box, the chipset datasheet,
or a vendor's "supports monitor mode & injection" marketing. Those are claims;
`iw` is evidence.

Read-only and passive: it enumerates and queries. It does not associate,
transmit, inject, or switch a live interface out from under anything. Scope every
run to equipment you own; if you cannot name the owner, stop.

Several queries below read fine as a user, but mode changes and a monitor-mode
probe need root. `sudo` cannot prompt in this session — hand the exact `sudo`
line to the operator for a real terminal and continue with the unprivileged
discovery.

## 1. Chipset, driver, firmware

```bash
lsusb                                   # vendor:product of the USB radio
ethtool -i wlan0                        # driver + driver/firmware version
```

Record the `idVendor:idProduct`, the bound driver (e.g. `mt7601u`, `rtl8812au`),
and the firmware version string verbatim. These three, not the product name, are
what determine capability and what makes a finding reproducible.

## 2. Supported modes and interface combinations

```bash
iw list                                 # or: iw phy phy0 info
```

Read two blocks:

- **Supported interface modes** — `monitor` and `AP` appearing here is necessary
  but not sufficient; it says the driver *advertises* the mode, not that this
  firmware will enter it cleanly.
- **valid interface combinations** — the real ceiling on concurrency (e.g.
  "`managed` + `AP` up to 2"). Marketing that promises simultaneous roles is only
  true if a combination line permits it.

Note TX/RX chains and supported bands here too; a "dual-band" sticker means
nothing if only 2.4 GHz channels are listed.

## 3. Regulatory domain

```bash
iw reg get                              # active regulatory domain
```

The domain gates which channels and power levels are legal. A channel absent or
no-IR (passive-scan only) here is off-limits even if the hardware can tune it.
Treat the regulatory domain as a hard constraint on any later plan, and record it
alongside the capability findings.

## 4. Monitor-mode pass/fail (explicit determination)

Advertising `monitor` in step 2 is not proof. Make an explicit determination:

```bash
sudo ip link set wlan0 down
sudo iw dev wlan0 set type monitor
sudo ip link set wlan0 up
iw dev wlan0 info                       # confirm: type monitor
# restore:
sudo ip link set wlan0 down
sudo iw dev wlan0 set type managed
sudo ip link set wlan0 up
```

State the outcome as **PASS** (interface reports `type monitor` and comes up) or
**FAIL** (set-type error, or it will not come up), and always restore the
interface to `managed`. "Driver lists monitor" + "set-type succeeded" are two
separate facts; report both. Do not infer injection capability from a monitor
PASS — injection is a further, separately-tested claim, not demonstrated here.

## Reporting

Produce a short capability record: chipset/driver/firmware (verbatim), advertised
modes, valid interface combinations, regulatory domain, and the monitor-mode
PASS/FAIL with the exact command output that decided it. Mark anything you did
not test as untested — never fill a gap with a datasheet claim.

In the homelab, `iw`/`ethtool` discovery like this is the first step before any
rf-lab capture; the `pcap-evidence-analysis` skill then handles traces offline.

## Provenance

The evidence-first / observed-vs-inferred / record-versions discipline is adapted
from [morluto/rea](https://github.com/morluto/rea) (MIT) — design patterns only,
no code. See `docs/rea-wireless-re-comparison.md`.
