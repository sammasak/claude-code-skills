---
name: preview
description: Start a live dev server on port 4300 so doable shows an instant preview iframe. Use this whenever you have a working frontend that the user should be able to see before the full deployment cycle completes.
---

# PREVIEW Skill

## When to use this skill

Use this skill when:
- You have a running frontend dev server (Vite, SvelteKit, Next.js, React, etc.)
- You want the user to see the app in the doable preview pane immediately
- You don't want to wait for a full container build + Flux deployment

## What this skill does

Starts your existing dev server on port 4300 with `--host 0.0.0.0` so doable can proxy it through to the user's browser. The doable preview pane automatically activates when port 4300 responds.

## Instructions

### Step 1: Start the dev server on port 4300

Detect the framework and start appropriately:

**Vite / SvelteKit / React (Vite):**
```bash
cd /path/to/your/frontend
npx vite --host 0.0.0.0 --port 4300 &
echo "Preview started (PID $!)"
```

**SvelteKit with adapter-node (production build):**
```bash
cd /path/to/your/frontend
npm run build
PORT=4300 HOST=0.0.0.0 node build &
echo "Preview started (PID $!)"
```

**Next.js:**
```bash
cd /path/to/your/frontend
npx next dev --hostname 0.0.0.0 --port 4300 &
echo "Preview started (PID $!)"
```

**Plain static files:**
```bash
cd /path/to/your/dist-or-build
npx serve -l 4300 --no-clipboard &
echo "Preview started (PID $!)"
```

### Step 2: Verify the server started

```bash
sleep 2 && curl -s -o /dev/null -w "%{http_code}" http://localhost:4300/
```

Expected: `200` (or `304`). If you get `000` or `connection refused`, the server didn't start — check the background process output.

### Step 3: Tell the user

Once port 4300 is responding, tell the user:
> "Preview is live — you should see it in the preview pane on the right."

## Important notes

- Always use `--host 0.0.0.0` — without this the server only listens on localhost and doable can't reach it
- Port **4300** is the fixed preview port — do not use a different port
- The process runs in the background (`&`) — it stays alive while Claude continues working
- If you rebuild or restart the dev server, use the reload button (↻) in the preview pane to reload it
- CORS: the proxy is same-origin, so no CORS configuration needed in your dev server
