# Template Stack Reference

This document contains the full technical details for the pre-baked SvelteKit 2 + PostgreSQL 16 environment.

## Svelte 5 Runes

The runtime is **Svelte 5** — use the runes API exclusively. Do NOT use Svelte 4 reactive syntax.

| Svelte 4 (wrong) | Svelte 5 runes (correct) |
|---|---|
| `export let count = 0;` | `let count = $state(0);` |
| `export let name;` (prop) | `let { name } = $props();` |
| `$: doubled = count * 2` | `let doubled = $derived(count * 2)` |
| `$: { ... }` side-effect | `$effect(() => { ... })` |
| `<slot />` | `{@render children()}` |

Always use `$state()`, `$derived()`, `$props()`, and `$effect()` — never `$:` labels or `export let` for props.

## UI and Tailwind CSS v4

- Edit `src/routes/+page.svelte` to replace the placeholder loader.
- Add new pages as `src/routes/[page-name]/+page.svelte`.
- Tailwind v4 is already configured in `src/app.css` via `@import 'tailwindcss'`. Use utility classes directly.

## API Endpoints (SvelteKit Server Routes)

```typescript
import { json } from '@sveltejs/kit';
import pg from 'pg';
const pool = new pg.Pool({ connectionString: 'postgresql://claude@localhost/claude' });
export async function GET() {
  const { rows } = await pool.query('SELECT * FROM items ORDER BY created_at DESC');
  return json(rows);
}
```

## Database (PostgreSQL 16)

Create `schema.sql` at the workspace root. Use `CREATE TABLE IF NOT EXISTS`.
Apply manually: `psql postgresql://claude@localhost/claude < ~/workspace/schema.sql`

## Optional Rust Backend

Only use if SvelteKit is insufficient. Run on port 3001 and proxy via `vite.config.ts`.
```typescript
proxy: { '/rust-api': 'http://localhost:3001' }
```

## Production Deployment

1. `npm run build`
2. Create `Containerfile` (see detailed templates if needed).
3. `buildah build -t registry.sammasak.dev/apps/[project-name]:latest .`
4. `buildah push ...`

## Repo Mode (Cloned GitHub Repos)

If the workspace was cloned, first detect the stack (`package.json`, `Cargo.toml`, etc.) and ensure a `flake.nix` exists. Start the dev server on port 8080.
Refer to the full `template-stack/SKILL.md` (or this doc) for Nix flake examples.
