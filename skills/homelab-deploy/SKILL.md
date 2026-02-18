---
name: homelab-deploy
description: "Use when the user asks to deploy, check, or troubleshoot the homelab Kubernetes cluster. Covers Flux GitOps, k3s nodes, and workstation VMs."
allowed-tools: Bash Read Grep Glob
---

# Homelab Deploy & Troubleshoot

Manage the k3s homelab cluster running on NixOS hosts.

## Architecture

- **Control plane**: `lenovo-21CB001PMX` (192.168.10.154) — k3s server + Flux GitOps
- **Workers**: `acer-swift`, `msi-ms7758` (GPU node with NVIDIA)
- **GitOps repo**: `sammasak/homelab-gitops` (Flux watches `clusters/homelab/`)
- **Registry**: Harbor at `registry.sammasak.dev`
- **DNS**: AdGuard Home on lenovo, rewrites `*.sammasak.dev` to MetalLB VIP (192.168.10.200)

## Common Operations

### Check cluster health
```bash
kubectl get nodes -o wide
kubectl get pods -A --field-selector status.phase!=Running
flux get all -A
```

### Force Flux reconciliation
```bash
flux reconcile source git flux-system
flux reconcile kustomization flux-system
```

### Check workstation VMs
```bash
kubectl get workspaceclaims -n workstations
kubectl get vmi -n workstations
```

### Rebuild and publish workstation image
```bash
cd ~/nixos-config && just release
```

## Troubleshooting

1. **Node NotReady**: Check `systemctl status k3s` on the affected host
2. **Flux errors**: `flux logs --all-namespaces --level=error`
3. **DNS issues**: Check AdGuard Home at `http://192.168.10.154:3000`
4. **GPU workloads**: Verify CDI specs with `ls /etc/cdi/` on msi-ms7758
