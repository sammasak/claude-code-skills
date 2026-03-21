# ICM Blog Post — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build and deploy an animated, interactive ICM blog post at icm.sammasak.dev — a single HTML file served by nginx-unprivileged in Kubernetes, explaining Jake Van Clief's ICM pattern with scroll-triggered animations and our concrete workspace implementation.

**Architecture:** Single `index.html` (all CSS/JS inline, zero external deps) embedded in a Kubernetes ConfigMap. Served by `nginxinc/nginx-unprivileged:alpine` (port 8080, runs as uid 101 — no root needed). Ingress at `icm.sammasak.dev` using existing `wildcard-sammasak-dev-tls` secret. Flux auto-reconciles on git push to homelab-gitops.

**Tech Stack:** HTML/CSS/JS (Intersection Observer, requestAnimationFrame, CSS keyframes), Kubernetes (Deployment + ConfigMap + Service + Ingress), Flux GitOps.

---

## TASK 1: Create Kubernetes infrastructure manifests

**Files:**
- Create: `~/homelab-gitops/apps/icm/namespace.yaml`
- Create: `~/homelab-gitops/apps/icm/deployment.yaml`
- Create: `~/homelab-gitops/apps/icm/service.yaml`
- Create: `~/homelab-gitops/apps/icm/ingress.yaml`
- Create: `~/homelab-gitops/apps/icm/kustomization.yaml`

**Step 1: Create the directory**

```bash
mkdir -p ~/homelab-gitops/apps/icm
```

**Step 2: Create namespace.yaml**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: icm
  labels:
    pod-security.kubernetes.io/enforce: baseline
```

**Step 3: Create deployment.yaml**

Note: `nginxinc/nginx-unprivileged:alpine` runs on port 8080 as uid 101 (nginx) — no root required, satisfies `runAsNonRoot: true`. ConfigMap is mounted at the nginx docroot via subPath.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: icm
  namespace: icm
spec:
  replicas: 1
  selector:
    matchLabels:
      app: icm
  template:
    metadata:
      labels:
        app: icm
    spec:
      securityContext:
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: icm
        image: nginxinc/nginx-unprivileged:alpine
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
        securityContext:
          runAsNonRoot: true
          runAsUser: 101
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          capabilities:
            drop: [ALL]
        resources:
          requests:
            cpu: 10m
            memory: 32Mi
          limits:
            cpu: 200m
            memory: 64Mi
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
      volumes:
      - name: html
        configMap:
          name: icm-html
```

**Step 4: Create service.yaml**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: icm
  namespace: icm
spec:
  selector:
    app: icm
  ports:
  - port: 80
    targetPort: 8080
```

**Step 5: Create ingress.yaml**

Uses existing wildcard TLS secret — no cert-manager annotation needed.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: icm
  namespace: icm
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - icm.sammasak.dev
    secretName: wildcard-sammasak-dev-tls
  rules:
  - host: icm.sammasak.dev
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: icm
            port:
              number: 80
```

**Step 6: Create kustomization.yaml**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - configmap.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml
```

**Step 7: Verify files created**

```bash
ls ~/homelab-gitops/apps/icm/
```

Expected: 5 files (configmap.yaml missing — that's Task 2).

---

## TASK 2: Write the ICM blog post HTML and create ConfigMap

**Files:**
- Create: `~/homelab-gitops/apps/icm/configmap.yaml`

This is the main creative task. The ConfigMap embeds the complete `index.html`. All CSS and JS are inline — zero external dependencies.

**Step 1: Create configmap.yaml with the full HTML**

Create `~/homelab-gitops/apps/icm/configmap.yaml` with the following content. The HTML is the complete blog post — do not truncate or summarize it.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: icm-html
  namespace: icm
data:
  index.html: |
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Interpreted Context Methodology — sammasak.dev</title>
    <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    :root {
      --bg: #080808;
      --bg-card: #0d0d1a;
      --bg-code: #0a0a14;
      --text: #e4e4f0;
      --text-muted: #6b7280;
      --accent: #6366f1;
      --accent-2: #a78bfa;
      --accent-glow: rgba(99,102,241,0.12);
      --green: #34d399;
      --red: #f87171;
      --border: rgba(99,102,241,0.15);
    }
    html { scroll-behavior: smooth; }
    body {
      background: var(--bg);
      color: var(--text);
      font-family: system-ui, -apple-system, 'Segoe UI', sans-serif;
      font-size: 18px;
      line-height: 1.75;
      overflow-x: hidden;
    }
    h1 { font-size: clamp(2.4rem, 6vw, 4.2rem); font-weight: 900; line-height: 1.05; letter-spacing: -0.03em; }
    h2 { font-size: clamp(1.5rem, 3.5vw, 2.2rem); font-weight: 800; line-height: 1.15; letter-spacing: -0.02em; }
    h3 { font-size: 1.1rem; font-weight: 700; }
    p { max-width: 65ch; }
    a { color: var(--accent-2); text-decoration: none; }
    a:hover { text-decoration: underline; }
    code, pre, .mono { font-family: 'JetBrains Mono', 'Fira Code', ui-monospace, monospace; font-size: 0.875em; }
    .container { max-width: 800px; margin: 0 auto; padding: 0 24px; }
    section { padding: 100px 0; border-bottom: 1px solid var(--border); }

    /* REVEAL */
    .reveal { opacity: 0; transform: translateY(28px); transition: opacity 0.65s ease, transform 0.65s ease; }
    .reveal.visible { opacity: 1; transform: translateY(0); }
    .d1 { transition-delay: 0.1s; } .d2 { transition-delay: 0.2s; }
    .d3 { transition-delay: 0.3s; } .d4 { transition-delay: 0.4s; }

    /* HERO */
    #hero {
      min-height: 100vh; display: flex; flex-direction: column;
      align-items: center; justify-content: center; text-align: center;
      position: relative; overflow: hidden; padding: 80px 24px;
      border-bottom: 1px solid var(--border);
    }
    .rings { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; pointer-events: none; }
    .ring { position: absolute; border-radius: 50%; border: 1px solid var(--accent); animation: rpulse 5s ease-in-out infinite; }
    .r1 { width: 280px; height: 280px; opacity: 0.18; animation-delay: 0s; }
    .r2 { width: 480px; height: 480px; opacity: 0.09; animation-delay: -1.8s; }
    .r3 { width: 700px; height: 700px; opacity: 0.04; animation-delay: -3.5s; }
    @keyframes rpulse { 0%,100% { transform: scale(1); } 50% { transform: scale(1.04); } }
    .hero-inner { position: relative; z-index: 1; }
    .eyebrow {
      display: inline-block; background: var(--accent-glow);
      border: 1px solid rgba(99,102,241,0.3); color: var(--accent-2);
      font-size: 0.7rem; font-weight: 700; letter-spacing: 0.14em;
      text-transform: uppercase; padding: 5px 14px; border-radius: 100px; margin-bottom: 28px;
    }
    .hero-title {
      background: linear-gradient(135deg, #fff 0%, var(--accent-2) 100%);
      -webkit-background-clip: text; -webkit-text-fill-color: transparent;
      background-clip: text; margin-bottom: 20px;
    }
    .hero-sub { font-size: clamp(1rem, 2.2vw, 1.2rem); color: var(--text-muted); max-width: 52ch; margin: 0 auto 40px; }
    .hero-meta { display: flex; gap: 20px; justify-content: center; color: var(--text-muted); font-size: 0.85rem; flex-wrap: wrap; }
    .scroll-hint {
      position: absolute; bottom: 36px; left: 50%; transform: translateX(-50%);
      color: var(--text-muted); font-size: 0.7rem; letter-spacing: 0.1em;
      text-transform: uppercase; display: flex; flex-direction: column; align-items: center; gap: 8px;
      animation: sbounce 2.2s ease-in-out infinite;
    }
    .scroll-hint::after { content: ''; width: 1px; height: 36px; background: linear-gradient(to bottom, var(--accent), transparent); }
    @keyframes sbounce { 0%,100% { transform: translateX(-50%) translateY(0); } 50% { transform: translateX(-50%) translateY(7px); } }

    /* SECTION LABELS */
    .label { font-size: 0.68rem; font-weight: 700; letter-spacing: 0.16em; text-transform: uppercase; color: var(--accent); margin-bottom: 14px; }
    .lead { color: var(--text-muted); font-size: 1.05rem; margin: 12px 0 56px; max-width: 60ch; }

    /* TOKEN BLOAT */
    .token-card {
      background: var(--bg-card); border: 1px solid var(--border);
      border-radius: 14px; padding: 36px; margin: 44px 0;
    }
    .tok-num { font-size: clamp(2.2rem, 5vw, 3.5rem); font-weight: 900; font-family: 'JetBrains Mono', monospace; margin-bottom: 14px; transition: color 0.4s; }
    .tok-num.danger { color: var(--red); }
    .bar-track { height: 6px; background: rgba(255,255,255,0.06); border-radius: 3px; overflow: hidden; margin-bottom: 10px; }
    .bar-fill { height: 100%; width: 0; background: linear-gradient(90deg, var(--accent), var(--accent-2)); border-radius: 3px; transition: width 3s cubic-bezier(0.4,0,0.2,1), background 0.4s; }
    .bar-fill.danger { background: linear-gradient(90deg, var(--accent), var(--red)); }
    .bar-labels { font-size: 0.8rem; color: var(--text-muted); display: flex; justify-content: space-between; }
    .tok-warn { font-size: 0.85rem; color: var(--red); margin-top: 14px; opacity: 0; transition: opacity 0.5s; }
    .tok-warn.show { opacity: 1; }
    .two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-top: 44px; }
    @media (max-width: 580px) { .two-col { grid-template-columns: 1fr; } }
    .mini-card { background: var(--bg-card); border: 1px solid var(--border); border-radius: 12px; padding: 24px; }
    .mini-card h3 { font-size: 0.85rem; margin-bottom: 14px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.08em; }
    .mini-card ul { list-style: none; }
    .mini-card li { padding: 5px 0; font-size: 0.85rem; color: var(--text-muted); display: flex; gap: 9px; align-items: flex-start; }
    .mini-card li::before { content: '—'; color: var(--border); flex-shrink: 0; }
    .mini-card.good li::before { content: '✓'; color: var(--green); }

    /* LAYERS */
    .layers { display: flex; flex-direction: column; gap: 14px; margin: 44px 0; }
    .lcard {
      background: var(--bg-card); border: 1px solid var(--border); border-radius: 12px;
      padding: 24px 28px; display: flex; align-items: center; gap: 20px;
      transform: translateX(-36px); opacity: 0; transition: transform 0.55s ease, opacity 0.55s ease, border-color 0.3s;
      position: relative; overflow: hidden;
    }
    .lcard.visible { transform: translateX(0); opacity: 1; }
    .lcard:hover { border-color: rgba(99,102,241,0.4); }
    .lcard::before { content: ''; position: absolute; inset: 0; background: linear-gradient(135deg, var(--accent-glow) 0%, transparent 60%); opacity: 0; transition: opacity 0.3s; }
    .lcard:hover::before { opacity: 1; }
    .lnum { width: 44px; height: 44px; border-radius: 10px; background: var(--accent-glow); border: 1px solid rgba(99,102,241,0.3); display: flex; align-items: center; justify-content: center; font-weight: 900; color: var(--accent); flex-shrink: 0; }
    .linfo { flex: 1; }
    .lfile { font-family: 'JetBrains Mono', monospace; font-size: 0.82rem; color: var(--accent-2); margin-bottom: 4px; }
    .ldesc { color: var(--text-muted); font-size: 0.9rem; line-height: 1.55; }
    .ltok { font-family: 'JetBrains Mono', monospace; font-size: 0.72rem; color: var(--text-muted); background: rgba(255,255,255,0.04); border: 1px solid var(--border); padding: 3px 9px; border-radius: 5px; white-space: nowrap; }
    .lconn { width: 1px; height: 14px; background: linear-gradient(to bottom, var(--accent), transparent); margin: 0 auto; opacity: 0.35; }

    /* ROUTING TABLE */
    .tbl-wrap { margin: 44px 0; border-radius: 12px; overflow: hidden; border: 1px solid var(--border); }
    table { width: 100%; border-collapse: collapse; font-size: 0.88rem; }
    thead tr { background: var(--bg-card); border-bottom: 1px solid var(--border); }
    thead th { padding: 12px 18px; text-align: left; font-size: 0.68rem; font-weight: 700; letter-spacing: 0.1em; text-transform: uppercase; color: var(--text-muted); }
    tbody tr { border-bottom: 1px solid var(--border); transition: background 0.2s; }
    tbody tr:last-child { border-bottom: none; }
    tbody tr:hover { background: var(--accent-glow); }
    tbody td { padding: 12px 18px; vertical-align: middle; }
    td:nth-child(2) { font-family: 'JetBrains Mono', monospace; font-size: 0.78rem; color: var(--accent-2); }
    td:nth-child(3) { font-size: 0.82rem; }
    .badge { display: inline-block; background: var(--accent-glow); border: 1px solid rgba(99,102,241,0.2); color: var(--accent-2); font-size: 0.65rem; font-weight: 600; padding: 2px 7px; border-radius: 4px; font-family: 'JetBrains Mono', monospace; margin: 1px; }
    .info-box { background: var(--bg-card); border: 1px solid var(--border); border-radius: 10px; padding: 18px 22px; font-size: 0.88rem; color: var(--text-muted); margin-top: 20px; }
    .info-box strong { color: var(--accent); }

    /* DIRECTORY TREE */
    .tree { background: var(--bg-card); border: 1px solid var(--border); border-radius: 12px; padding: 28px 32px; font-family: 'JetBrains Mono', monospace; font-size: 0.875rem; margin: 44px 0; }
    .tl { padding: 2px 0; display: flex; align-items: baseline; gap: 6px; opacity: 0; transform: translateX(-6px); transition: opacity 0.28s ease, transform 0.28s ease; color: var(--text-muted); line-height: 1.6; }
    .tl.show { opacity: 1; transform: translateX(0); }
    .tdir { color: var(--accent); font-weight: 700; }
    .thi { color: var(--accent-2); }
    .tcm { color: #374151; font-size: 0.75rem; margin-left: auto; white-space: nowrap; padding-left: 12px; }

    /* WORKFLOW TRACE */
    .trace { background: var(--bg-card); border: 1px solid var(--border); border-radius: 12px; padding: 28px 32px; margin: 44px 0; }
    .trace-prompt { font-family: 'JetBrains Mono', monospace; font-size: 0.9rem; color: var(--accent-2); margin-bottom: 28px; display: flex; align-items: center; gap: 10px; }
    .trace-prompt::before { content: '❯'; color: var(--accent); }
    .steps { display: flex; flex-direction: column; gap: 14px; }
    .step { display: flex; gap: 14px; align-items: flex-start; opacity: 0; transform: translateY(10px); transition: opacity 0.4s ease, transform 0.4s ease; }
    .step.show { opacity: 1; transform: translateY(0); }
    .snum { width: 26px; height: 26px; border-radius: 50%; background: var(--accent-glow); border: 1px solid rgba(99,102,241,0.4); display: flex; align-items: center; justify-content: center; font-size: 0.72rem; font-weight: 700; color: var(--accent); flex-shrink: 0; margin-top: 3px; }
    .sbody {}
    .slabel { font-size: 0.75rem; color: var(--text-muted); margin-bottom: 5px; }
    .scode { font-family: 'JetBrains Mono', monospace; font-size: 0.8rem; background: var(--bg-code); border: 1px solid var(--border); border-radius: 6px; padding: 7px 13px; display: inline-block; color: var(--text); }

    /* CODE BLOCKS */
    .cb { margin: 28px 0; }
    .cbh { background: var(--bg-card); border: 1px solid var(--border); border-bottom: none; border-radius: 10px 10px 0 0; padding: 9px 16px; font-size: 0.72rem; color: var(--text-muted); display: flex; justify-content: space-between; align-items: center; }
    .cpbtn { background: none; border: 1px solid var(--border); color: var(--text-muted); font-size: 0.68rem; padding: 3px 9px; border-radius: 4px; cursor: pointer; font-family: inherit; transition: color 0.2s, border-color 0.2s; }
    .cpbtn:hover { color: var(--text); border-color: var(--accent); }
    .cpbtn.ok { color: var(--green); border-color: var(--green); }
    pre { background: var(--bg-code); border: 1px solid var(--border); border-radius: 0 0 10px 10px; padding: 18px; overflow-x: auto; line-height: 1.6; font-size: 0.82rem; white-space: pre; }
    .cm-s { color: #4b5563; font-style: italic; }
    .kw { color: var(--accent-2); }
    .str { color: var(--green); }
    .hd { color: var(--accent); font-weight: 700; }
    .tblc { color: var(--green); }

    /* SPLIT PANEL */
    .split { display: grid; grid-template-columns: 1fr 1fr; gap: 2px; margin: 44px 0; border-radius: 12px; overflow: hidden; }
    @media (max-width: 600px) { .split { grid-template-columns: 1fr; } }
    .sp { background: var(--bg-card); padding: 28px; }
    .sp.r { background: rgba(99,102,241,0.05); border-left: 1px solid var(--border); }
    .sp h3 { font-size: 0.78rem; letter-spacing: 0.1em; text-transform: uppercase; margin-bottom: 22px; }
    .sp.l h3 { color: var(--text-muted); }
    .sp.r h3 { color: var(--accent); }
    .si { display: flex; gap: 11px; margin-bottom: 12px; font-size: 0.88rem; }
    .si-icon { flex-shrink: 0; margin-top: 1px; }
    .si p { color: var(--text-muted); line-height: 1.5; }
    .sp.r .si p { color: var(--text); }

    /* QUOTE */
    .pullquote { font-style: italic; color: var(--text-muted); font-size: 1.1rem; border-left: 2px solid var(--accent); padding-left: 20px; margin: 44px 0; }

    /* FOOTER */
    footer { padding: 56px 24px; text-align: center; color: var(--text-muted); font-size: 0.85rem; }
    .fdiv { width: 36px; height: 1px; background: var(--border); margin: 0 auto 22px; }
    </style>
    </head>
    <body>

    <!-- ═══════════════════════════════════════ HERO ═══════════════════════════════════════ -->
    <section id="hero">
      <div class="rings">
        <div class="ring r1"></div>
        <div class="ring r2"></div>
        <div class="ring r3"></div>
      </div>
      <div class="hero-inner">
        <div class="eyebrow">Methodology</div>
        <h1 class="hero-title">Interpreted Context<br>Methodology</h1>
        <p class="hero-sub">How a folder structure replaced agent frameworks — and why the filesystem is the best orchestration layer.</p>
        <div class="hero-meta">
          <span>Concept by Jake Van Clief · <a href="https://instagram.com/lostandlucky">@lostandlucky</a></span>
          <span>·</span>
          <span>Implementation by <a href="https://github.com/sammasak/workspace">sammasak</a></span>
        </div>
      </div>
      <div class="scroll-hint">scroll</div>
    </section>

    <!-- ═══════════════════════════════════════ PROBLEM ═══════════════════════════════════════ -->
    <section id="problem">
      <div class="container">
        <div class="label reveal">The Problem</div>
        <h2 class="reveal d1">Loading everything<br>costs everything</h2>
        <p class="lead reveal d2">Most agentic setups load every context file upfront — skills, rules, documentation, all of it, all the time. At 30,000–50,000 tokens, model quality degrades measurably. You are paying for context you don't need.</p>

        <div class="token-card reveal d3">
          <div class="tok-num" id="tokNum">0</div>
          <div class="bar-track"><div class="bar-fill" id="tokBar"></div></div>
          <div class="bar-labels"><span>tokens loaded (monolithic approach)</span><span>50,000</span></div>
          <div class="tok-warn" id="tokWarn">⚠ Model quality degrades past 30,000 tokens in context</div>
        </div>

        <div class="two-col">
          <div class="mini-card reveal">
            <h3>What you load</h3>
            <ul>
              <li>All 16 injectable skills</li>
              <li>All rules and constraints</li>
              <li>All workflow documentation</li>
              <li>All homelab references</li>
              <li>All past decisions</li>
              <li>Full CLAUDE.md</li>
              <li>Example files and templates</li>
            </ul>
          </div>
          <div class="mini-card good reveal d1">
            <h3>What this task needs</h3>
            <ul>
              <li>CLAUDE.md routing table</li>
              <li>One room CONTEXT.md</li>
              <li>2–3 relevant skills</li>
            </ul>
          </div>
        </div>

        <p class="reveal d2" style="margin-top:32px; font-style:italic; color:var(--text-muted);">"The gap between what you load and what you need is where quality dies."</p>
      </div>
    </section>

    <!-- ═══════════════════════════════════════ THREE LAYERS ═══════════════════════════════════════ -->
    <section id="layers">
      <div class="container">
        <div class="label reveal">The Solution</div>
        <h2 class="reveal d1">Three layers.<br>Selective loading.</h2>
        <p class="lead reveal d2">Jake Van Clief's ICM replaces monolithic context with a three-layer hierarchy. Each layer loads only when needed — context stays lean, focus stays sharp.</p>

        <div class="layers">
          <div class="lcard" id="lc1">
            <div class="lnum">1</div>
            <div class="linfo">
              <div class="lfile">~/workspace/CLAUDE.md</div>
              <div class="ldesc">Always loaded. The navigation map — a routing table that tells Claude which room to enter for any task. No implementation details, just a lookup table. Small by design.</div>
            </div>
            <div class="ltok">~800 tokens</div>
          </div>
          <div class="lconn"></div>
          <div class="lcard" id="lc2" style="transition-delay:0.2s">
            <div class="lnum">2</div>
            <div class="linfo">
              <div class="lfile">~/workspace/{room}/CONTEXT.md</div>
              <div class="ldesc">Loaded on demand. Each room covers one domain: homelab, dev, local, workflows. Contains reference knowledge, commands, and conventions for that domain only — nothing else.</div>
            </div>
            <div class="ltok">1–3k tokens</div>
          </div>
          <div class="lconn"></div>
          <div class="lcard" id="lc3" style="transition-delay:0.4s">
            <div class="lnum">3</div>
            <div class="linfo">
              <div class="lfile">~/.claude/skills/{skill}.md</div>
              <div class="ldesc">Injected selectively. Skills carry deep domain knowledge — container workflows, Kubernetes GitOps, SOPS secrets. Claude's description-matching selects only what's relevant to the current task.</div>
            </div>
            <div class="ltok">500–2k tokens each</div>
          </div>
        </div>

        <p class="reveal" style="color:var(--text-muted);">Typical task context: <strong style="color:var(--text)">~4,000–6,000 tokens</strong> instead of 40,000+. That's the difference between a sharp assistant and a confused one.</p>
      </div>
    </section>

    <!-- ═══════════════════════════════════════ ROUTING TABLE ═══════════════════════════════════════ -->
    <section id="routing">
      <div class="container">
        <div class="label reveal">Layer 1</div>
        <h2 class="reveal d1">The routing table</h2>
        <p class="lead reveal d2">CLAUDE.md is never a monolith — it's a map. One routing table, always loaded, tells Claude exactly where to go. No implicit matching. No ambiguity. Hover a row.</p>

        <div class="tbl-wrap reveal d3">
          <table>
            <thead>
              <tr>
                <th>When the task involves</th>
                <th>Read this first</th>
                <th>Also load</th>
              </tr>
            </thead>
            <tbody>
              <tr><td>Fix a homelab service</td><td>homelab/CONTEXT.md</td><td><span class="badge">kubernetes-gitops</span> <span class="badge">credentials</span></td></tr>
              <tr><td>Configure NixOS / flake</td><td>homelab/CONTEXT.md</td><td><span class="badge">nix-flake-development</span></td></tr>
              <tr><td>Add a SOPS secret</td><td>homelab/CONTEXT.md</td><td><span class="badge">secrets-management</span></td></tr>
              <tr><td>Manage the cluster</td><td>homelab/CONTEXT.md</td><td><span class="badge">kubernetes-gitops</span></td></tr>
              <tr><td>Write / run code</td><td>dev/CONTEXT.md</td><td><span class="badge">rust-engineering</span> <span class="badge">python-engineering</span></td></tr>
              <tr><td>Debug an issue</td><td>dev/CONTEXT.md</td><td><span class="badge">systematic-debugging</span></td></tr>
              <tr><td>Explore a codebase</td><td>dev/CONTEXT.md</td><td></td></tr>
              <tr><td>Run a local script</td><td>local/CONTEXT.md</td><td></td></tr>
              <tr><td>Deploy a service</td><td>workflows/CONTEXT.md</td><td><span class="badge">container-workflows</span> <span class="badge">verify-service</span></td></tr>
              <tr><td>Provision a claude-worker VM</td><td>workflows/CONTEXT.md</td><td><span class="badge">claude-ctl</span></td></tr>
              <tr><td>Release NixOS config</td><td>workflows/CONTEXT.md</td><td><span class="badge">nix-flake-development</span></td></tr>
            </tbody>
          </table>
        </div>

        <div class="info-box reveal">
          <strong>ICM vs. Skills routing</strong><br>
          Skills use <em>description matching</em> — Claude's intelligence decides relevance. ICM uses an <em>explicit lookup table</em> — deterministic, zero ambiguity. They are complementary: ICM navigates, skills provide deep domain knowledge.
        </div>
      </div>
    </section>

    <!-- ═══════════════════════════════════════ WORKSPACE TREE ═══════════════════════════════════════ -->
    <section id="tree">
      <div class="container">
        <div class="label reveal">Layer 2</div>
        <h2 class="reveal d1">The workspace rooms</h2>
        <p class="lead reveal d2">Each room is a folder with a single CONTEXT.md. The folder structure <em>is</em> the architecture. No framework, no code, just files a human can read, edit, and understand in five minutes.</p>

        <div class="tree reveal d3">
          <div class="tl" id="tl0"><span class="tdir">~/workspace/</span></div>
          <div class="tl" id="tl1"><span>├── </span><span class="thi">CLAUDE.md</span><span class="tcm">← always loaded · routing map</span></div>
          <div class="tl" id="tl2"><span>│</span></div>
          <div class="tl" id="tl3"><span>├── </span><span class="tdir">homelab/</span></div>
          <div class="tl" id="tl4"><span>│   └── </span><span>CONTEXT.md</span><span class="tcm">← k8s, nixos, sops, flux</span></div>
          <div class="tl" id="tl5"><span>│</span></div>
          <div class="tl" id="tl6"><span>├── </span><span class="tdir">dev/</span></div>
          <div class="tl" id="tl7"><span>│   └── </span><span>CONTEXT.md</span><span class="tcm">← code, repos, build tools</span></div>
          <div class="tl" id="tl8"><span>│</span></div>
          <div class="tl" id="tl9"><span>├── </span><span class="tdir">local/</span></div>
          <div class="tl" id="tl10"><span>│   └── </span><span>CONTEXT.md</span><span class="tcm">← scripts, one-off tasks</span></div>
          <div class="tl" id="tl11"><span>│</span></div>
          <div class="tl" id="tl12"><span>└── </span><span class="tdir">workflows/</span></div>
          <div class="tl" id="tl13"><span>    ├── </span><span>CONTEXT.md</span><span class="tcm">← workflow gateway</span></div>
          <div class="tl" id="tl14"><span>    ├── </span><span class="tdir">deploy-service/</span></div>
          <div class="tl" id="tl15"><span>    │   └── </span><span>CONTEXT.md</span><span class="tcm">← build → push → apply → verify</span></div>
          <div class="tl" id="tl16"><span>    ├── </span><span class="tdir">provision-vm/</span></div>
          <div class="tl" id="tl17"><span>    │   └── </span><span>CONTEXT.md</span><span class="tcm">← claude-worker VM lifecycle</span></div>
          <div class="tl" id="tl18"><span>    └── </span><span class="tdir">release-nixos/</span></div>
          <div class="tl" id="tl19"><span>        └── </span><span>CONTEXT.md</span><span class="tcm">← nixos-rebuild, flake update</span></div>
        </div>

        <p class="reveal" style="color:var(--text-muted)">No agent framework. No orchestration code. A folder you can <code style="font-size:0.9em; color:var(--accent-2); background:var(--bg-card); padding:2px 7px; border-radius:4px">git clone</code> and understand in five minutes.</p>
      </div>
    </section>

    <!-- ═══════════════════════════════════════ WORKFLOW TRACE ═══════════════════════════════════════ -->
    <section id="trace">
      <div class="container">
        <div class="label reveal">In Action</div>
        <h2 class="reveal d1">Tracing a task<br>end-to-end</h2>
        <p class="lead reveal d2">Here is exactly what happens when you ask Claude to deploy a service. Watch the context stack build — only what's needed, loaded only when needed.</p>

        <div class="trace reveal d3">
          <div class="trace-prompt">"Deploy the doable UI service"</div>
          <div class="steps">
            <div class="step" id="ts1">
              <div class="snum">1</div>
              <div class="sbody">
                <div class="slabel">CLAUDE.md scanned — routing table match found</div>
                <div class="scode">Deploy a service → <span style="color:var(--accent-2)">workflows/CONTEXT.md</span></div>
              </div>
            </div>
            <div class="step" id="ts2">
              <div class="snum">2</div>
              <div class="sbody">
                <div class="slabel">Gateway loaded — dispatches to specific workflow</div>
                <div class="scode">workflows/CONTEXT.md → <span style="color:var(--accent-2)">deploy-service/CONTEXT.md</span></div>
              </div>
            </div>
            <div class="step" id="ts3">
              <div class="snum">3</div>
              <div class="sbody">
                <div class="slabel">Stage 1: Build</div>
                <div class="scode">npm run build &amp;&amp; buildah build --isolation=chroot .</div>
              </div>
            </div>
            <div class="step" id="ts4">
              <div class="snum">4</div>
              <div class="sbody">
                <div class="slabel">Stage 2: Push</div>
                <div class="scode">buildah push --authfile ~/.config/containers/auth.json registry.sammasak.dev/lab/doable-ui:latest</div>
              </div>
            </div>
            <div class="step" id="ts5">
              <div class="snum">5</div>
              <div class="sbody">
                <div class="slabel">Stage 3: Apply</div>
                <div class="scode">kubectl rollout restart deployment/doable -n doable</div>
              </div>
            </div>
            <div class="step" id="ts6">
              <div class="snum">6</div>
              <div class="sbody">
                <div class="slabel">Stage 4: Verify — total context loaded</div>
                <div class="scode" style="color:var(--green)">curl -sf https://doable.sammasak.dev/ ✓  ·  ~5,200 tokens used</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ═══════════════════════════════════════ HOW TO ADAPT ═══════════════════════════════════════ -->
    <section id="adapt">
      <div class="container">
        <div class="label reveal">Build Your Own</div>
        <h2 class="reveal d1">Three files to start</h2>
        <p class="lead reveal d2">ICM scales to any project. Here is the minimal setup — a CLAUDE.md, one room, one workflow. Start here and add rooms as your needs grow.</p>

        <div class="reveal d1">
          <p style="font-size:0.78rem; font-weight:700; letter-spacing:0.1em; text-transform:uppercase; color:var(--text-muted); margin-bottom:10px;">Step 1 — Create your CLAUDE.md</p>
          <div class="cb">
            <div class="cbh"><span>~/workspace/CLAUDE.md</span><button class="cpbtn" onclick="cp(this)">Copy</button></div>
            <pre><span class="hd"># Workspace</span>

<span class="cm-s">## Rooms</span>

<span class="tblc">| Room | CONTEXT.md | When to use |
|------|------------|-------------|
| dev | dev/CONTEXT.md | Writing code, debugging |
| infra | infra/CONTEXT.md | Servers, deployments, config |</span>

<span class="cm-s">## Routing Table</span>

<span class="tblc">| Task involves | Read first | Also load |
|---------------|------------|-----------|
| Writing code | dev/CONTEXT.md | rust-engineering |
| Debugging | dev/CONTEXT.md | systematic-debugging |
| Deployments | workflows/CONTEXT.md | container-workflows |</span>

<span class="cm-s">## Rules</span>

- Read the room CONTEXT.md before starting any task
- Invoke listed skills — they carry knowledge this file doesn't duplicate
- Do not load a room unless the task belongs there</pre>
          </div>
        </div>

        <div class="reveal d2" style="margin-top:36px">
          <p style="font-size:0.78rem; font-weight:700; letter-spacing:0.1em; text-transform:uppercase; color:var(--text-muted); margin-bottom:10px;">Step 2 — Create a room</p>
          <div class="cb">
            <div class="cbh"><span>~/workspace/dev/CONTEXT.md</span><button class="cpbtn" onclick="cp(this)">Copy</button></div>
            <pre><span class="hd"># dev</span>

<span class="cm-s">## What this room covers</span>
Code writing, debugging, repo exploration, local builds.

<span class="cm-s">## Key repos</span>

<span class="tblc">| Repo | Path | Stack |
|------|------|-------|
| my-api | ~/my-api | Rust / Axum |
| my-ui | ~/my-ui | SvelteKit |</span>

<span class="cm-s">## Build commands</span>
- <span class="str">my-api:</span> `cargo check` · `cargo test` · `just release`
- <span class="str">my-ui:</span> `npm run dev` · `npm run build`

<span class="cm-s">## Rules</span>
- Run `cargo check` before committing any Rust changes
- Run tests with `cargo test` before marking a task done</pre>
          </div>
        </div>

        <div class="reveal d3" style="margin-top:36px">
          <p style="font-size:0.78rem; font-weight:700; letter-spacing:0.1em; text-transform:uppercase; color:var(--text-muted); margin-bottom:10px;">Step 3 — Create a workflow</p>
          <div class="cb">
            <div class="cbh"><span>~/workspace/workflows/deploy/CONTEXT.md</span><button class="cpbtn" onclick="cp(this)">Copy</button></div>
            <pre><span class="hd"># deploy workflow</span>

<span class="cm-s">## Inputs required</span>
- Service name
- Target environment (staging / production)

<span class="cm-s">## Stage 1: Build</span>
`docker build -t myregistry/myapp:latest .`
Verify: image exists with `docker images | grep myapp`

<span class="cm-s">## Stage 2: Push</span>
`docker push myregistry/myapp:latest`
Verify: push succeeds (no error output)

<span class="cm-s">## Stage 3: Deploy</span>
`kubectl rollout restart deployment/myapp -n production`
Verify: `kubectl rollout status deployment/myapp -n production`

<span class="cm-s">## Rules</span>
- Stop on any stage failure — do not proceed
- Verify each stage output before moving to the next</pre>
          </div>
        </div>
      </div>
    </section>

    <!-- ═══════════════════════════════════════ BEFORE / AFTER ═══════════════════════════════════════ -->
    <section id="compare">
      <div class="container">
        <div class="label reveal">Before &amp; After</div>
        <h2 class="reveal d1">What ICM replaces</h2>
        <p class="lead reveal d2">ICM does not replace skills — it runs alongside them. It replaces the "load everything and hope" approach with a deterministic navigation layer.</p>

        <div class="split reveal d3">
          <div class="sp l">
            <h3>Without ICM</h3>
            <div class="si"><div class="si-icon">⚠</div><p>Skills loaded upfront — description matching is implicit, can miss or over-match</p></div>
            <div class="si"><div class="si-icon">⚠</div><p>No explicit routing — Claude guesses which domain the task belongs to</p></div>
            <div class="si"><div class="si-icon">⚠</div><p>Context bloat — 20k–50k tokens for any task, regardless of scope</p></div>
            <div class="si"><div class="si-icon">⚠</div><p>Knowledge scattered — commands, conventions, paths in many unrelated files</p></div>
          </div>
          <div class="sp r">
            <h3>With ICM</h3>
            <div class="si"><div class="si-icon" style="color:var(--green)">✓</div><p>Routing table is explicit — always deterministic, always the right room</p></div>
            <div class="si"><div class="si-icon" style="color:var(--green)">✓</div><p>Skills still inject — ICM navigates, skills provide domain knowledge</p></div>
            <div class="si"><div class="si-icon" style="color:var(--green)">✓</div><p>Context is lean — 4k–8k tokens per task, focused on what matters</p></div>
            <div class="si"><div class="si-icon" style="color:var(--green)">✓</div><p>Knowledge is discoverable — a human can navigate the workspace too</p></div>
          </div>
        </div>

        <p class="pullquote reveal">"The filesystem is the orchestration layer. No framework required."</p>
      </div>
    </section>

    <!-- ═══════════════════════════════════════ FOOTER ═══════════════════════════════════════ -->
    <footer>
      <div class="fdiv"></div>
      <p>Based on Jake Van Clief's ICM — <a href="https://instagram.com/lostandlucky">@lostandlucky</a></p>
      <p style="margin-top:8px">Implementation: <a href="https://github.com/sammasak/workspace">github.com/sammasak/workspace</a></p>
      <p style="margin-top:16px; font-size:0.75rem; color:#374151">Built with Claude Code · <a href="https://anthropic.com" style="color:#374151">Anthropic</a></p>
    </footer>

    <script>
    // INTERSECTION OBSERVER — reveal
    const obs = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting) e.target.classList.add('visible'); }), { threshold: 0.12 });
    document.querySelectorAll('.reveal').forEach(el => obs.observe(el));

    // LAYER CARDS
    const lobs = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting) e.target.classList.add('visible'); }), { threshold: 0.2 });
    ['lc1','lc2','lc3'].forEach(id => { const el = document.getElementById(id); if (el) lobs.observe(el); });

    // TOKEN COUNTER
    let tokDone = false;
    const tokObs = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting && !tokDone) { tokDone = true; runTok(); } }), { threshold: 0.3 });
    const tokEl = document.querySelector('.token-card');
    if (tokEl) tokObs.observe(tokEl);

    function runTok() {
      const num = document.getElementById('tokNum');
      const bar = document.getElementById('tokBar');
      const warn = document.getElementById('tokWarn');
      const target = 50000, dur = 3200, t0 = performance.now();
      function ease(t) { return 1 - Math.pow(1-t, 3); }
      function tick(now) {
        const p = Math.min((now - t0) / dur, 1);
        const v = Math.floor(ease(p) * target);
        num.textContent = v.toLocaleString();
        bar.style.width = (v / target * 100) + '%';
        if (v > 30000) { num.classList.add('danger'); bar.classList.add('danger'); warn.classList.add('show'); }
        if (p < 1) requestAnimationFrame(tick);
      }
      requestAnimationFrame(tick);
    }

    // DIRECTORY TREE
    let treeDone = false;
    const treeObs = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting && !treeDone) { treeDone = true; runTree(); } }), { threshold: 0.15 });
    const treeEl = document.querySelector('.tree');
    if (treeEl) treeObs.observe(treeEl);

    function runTree() {
      for (let i = 0; i <= 19; i++) {
        const el = document.getElementById('tl' + i);
        if (el) setTimeout(() => el.classList.add('show'), i * 85);
      }
    }

    // WORKFLOW TRACE
    let traceDone = false;
    const traceObs = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting && !traceDone) { traceDone = true; runTrace(); } }), { threshold: 0.2 });
    const traceEl = document.querySelector('.trace');
    if (traceEl) traceObs.observe(traceEl);

    function runTrace() {
      for (let i = 1; i <= 6; i++) {
        const el = document.getElementById('ts' + i);
        if (el) setTimeout(() => el.classList.add('show'), (i-1) * 380 + 250);
      }
    }

    // COPY BUTTONS
    function cp(btn) {
      const pre = btn.closest('.cb').querySelector('pre');
      navigator.clipboard.writeText(pre.innerText || pre.textContent).then(() => {
        btn.textContent = 'Copied!'; btn.classList.add('ok');
        setTimeout(() => { btn.textContent = 'Copy'; btn.classList.remove('ok'); }, 2000);
      });
    }
    </script>
    </body>
    </html>
```

**Step 2: Verify YAML is well-formed**

```bash
python3 -c "import yaml; yaml.safe_load(open('configmap.yaml'))" 2>/dev/null || \
  python3 -c "import sys; print('yaml module not available, skipping')"
```

If python3 unavailable, eyeball the indentation: every HTML line must be indented with exactly 4 spaces (the YAML `data.index.html: |` literal block expects consistent indentation).

**Step 3: Commit**

```bash
cd ~/homelab-gitops
git add apps/icm/
git commit -m "feat: add icm blog post — nginx deployment for icm.sammasak.dev"
```

---

## TASK 3: Register icm in apps/kustomization.yaml and push

**Files:**
- Modify: `~/homelab-gitops/apps/kustomization.yaml`

**Step 1: Check current resources list**

```bash
cat ~/homelab-gitops/apps/kustomization.yaml
```

**Step 2: Add icm to resources**

Add `- icm/` to the resources list. Order doesn't matter, but keep it alphabetical for readability (after `hello-world/`, before `marketing-dashboard/`):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - lab/
  - harbor/
  - external-dns/
  - milano/
  - doable/
  - twitter/
  - slides/
  - notes/
  - portfolio/
  - hello-world/
  - icm/
  - marketing-dashboard/
```

**Step 3: Commit and push**

```bash
cd ~/homelab-gitops
git add apps/kustomization.yaml
git commit -m "feat: register icm in apps kustomization"
git push origin main
```

**Step 4: Watch Flux reconcile**

```bash
kubectl get kustomization -A | grep icm
```

Wait ~30s for Flux to reconcile, then:

```bash
kubectl get pods -n icm
```

Expected: pod running (`1/1 Ready`).

**Step 5: Verify the site is live**

```bash
curl -sf https://icm.sammasak.dev/ | head -5
```

Expected: `<!DOCTYPE html>` response (nginx serves it, TLS from wildcard cert works).

If DNS doesn't resolve immediately, check AdGuard is serving `*.sammasak.dev → 192.168.10.200`:

```bash
kubectl get ingress -n icm
```

---

## Notes for implementer

- **YAML indentation**: The ConfigMap HTML block uses `|` (literal block scalar). Every HTML line needs 4-space indent inside the YAML. If the file is created with the Write tool, check the indentation is consistent.
- **nginx-unprivileged port**: The container runs on 8080, not 80. The Service maps 80 → 8080. The Ingress talks to the Service on port 80.
- **wildcard cert**: The `wildcard-sammasak-dev-tls` secret lives in `default` namespace or is replicated cluster-wide — check if it needs to be in the `icm` namespace. If cert-manager isn't replicating it, add a cert-manager annotation instead: `cert-manager.io/cluster-issuer: letsencrypt-prod`.
- **Flux timing**: After `git push`, Flux reconciles every 60s by default. Force it: `flux reconcile kustomization apps --with-source`.
