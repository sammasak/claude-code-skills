# Forge — Vision Document

**Date:** 2026-03-21

---

## What Forge Is

Forge is the operating system for building a company with AI: you define the company's DNA as structured docs, break work into tickets, and coding agents build each ticket autonomously while you steer the direction.

---

## The Problem

Every serious attempt to use AI for software development runs into the same wall. You can generate a component, scaffold a feature, even vibe-code an entire app in one session. But then the session ends. The next agent — or the next conversation — starts cold. It doesn't know your stack, your patterns, your decisions, your culture. You spend half your time re-explaining context that shouldn't need explaining.

The deeper problem is that most "AI coding" tools are one-shot tools. They're great for getting from zero to something fast. They're terrible for sustained, compounding work — the kind of work that builds a real company over months and years. There's no memory, no process, no team. It's just you, a prompt, and a disposable agent that forgets everything the moment you close the tab.

Forge is built around the belief that the bottleneck isn't the quality of any single AI coding session. The bottleneck is the absence of organizational structure around those sessions. Companies work because they have documented ways of working, defined processes, and shared context. Forge brings that organizational layer to AI development.

---

## Who It's For

Forge is for founders and small technical teams who want to move at agent speed without sacrificing the organizational coherence that makes a company compound over time. The person it's built for is someone who has used Lovable or Bolt, shipped something real, and then hit the ceiling — they needed to iterate, maintain, and extend, and the one-shot paradigm broke down. They understand what AI coding can do. They're trying to figure out how to build a whole company with it, not just a prototype.

---

## How It Works

You start by defining your company. Not in a form — in a git repository. You write markdown files that describe your mission, your ways of working, your tech stack, your conventions, your product context. This is your ICM repo: the structured, versioned source of truth for what your company is and how it operates.

Then you create a project and define its workflow. Not a preset Backlog/In-Progress/Done workflow — your workflow. Maybe it's Idea → Research → Spec → Build → QA → Ship. Maybe it's Triage → Design → Implementation → Verification → Released. You name the columns, set their order, and for each column you decide whether an agent should activate when a ticket lands there.

For each agent column, you write a goal template. This is the instruction that fires when a ticket is moved in: "Research this feature idea and enrich the ticket description with technical considerations, edge cases, and a rough implementation plan." Or: "Build this feature according to the spec. Use our standard SvelteKit patterns from CONTEXT.md. Run the tests." The agent spins up as a full VM — a real development environment with your codebase, your tools, your context from the ICM docs — and works until it's done.

Then you move the ticket. That's it. Drag it from one column to the next, and Forge dispatches the work. You come back to a PR, a research summary, a test report — whatever that column's agent was configured to produce. You review it, adjust the ticket, move it forward.

---

## Why ICM Docs Are the Foundation

The quality gap between a good AI coding session and a bad one almost always comes down to context. An agent that knows your codebase, your patterns, your naming conventions, your deployment pipeline, and your product constraints produces dramatically better output than one that's guessing. ICM — Interpreted Context Methodology — is a structured way of encoding that knowledge as markdown files in a git repo.

When Forge dispatches an agent, it clones your ICM repo into the agent's environment before it starts. The agent reads your CLAUDE.md routing table, your CONTEXT.md domain files, your skills. It knows what stack you're using. It knows your team's preferences. It knows what "done" means in your context. That structural investment compounds: the better you document your company, the better every agent that works for it performs. Your ICM repo becomes a moat.

---

## The NATS Queue

Agents are expensive — in time, in compute, in money. Each agent run is a full VM, a real coding environment, potentially tens of minutes of work. You cannot dispatch them naively. If ten tickets get moved simultaneously, you cannot spin up ten VMs without a plan for what happens when the eleventh arrives.

Forge uses NATS JetStream as its work queue between the kanban board and the agent dispatcher. Every ticket move to an agent column publishes a durable message to a JetStream subject. Consumers pull from that subject at a controlled rate. If the VM pool is full, messages wait — they're not dropped, not lost, not silently failed. The queue provides backpressure: the UI shows "queued" status, the system knows exactly where every unit of work is, and nothing falls on the floor. This is not a detail. For a system built around long-running, expensive async workers, the work queue is the core.

---

## What Success Looks Like

Success is a morning standup where half the tickets on the board made visible progress overnight. You defined the work, you set the context, and the agents ran. You wake up to a queue of agent outputs to review — code to skim, PRs to merge, research to read. Your job shifts from building to steering: reading what the agents produced, deciding what's good, adjusting what needs more direction, moving the next batch forward.

Success is a codebase that stays coherent month over month because every agent is working from the same documented context, not reinventing the wheel or diverging from conventions. Success is a team of two humans moving at the pace that used to require a team of ten.

---

## The Ambition

Forge's two-year vision is the complete organizational layer for an AI-native company. The kanban board and ICM repo are the foundation — but above that you build recruiting (define a role in ICM, agents screen candidates), onboarding (new humans or agents get a richer, more complete context automatically), financial modeling, OKR tracking, roadmap planning. The company's documented structure becomes the interface through which all work — human and agent — is coordinated.

The deeper bet is that the company that wins in AI development isn't the one with the best single agent. It's the one that builds the best organizational scaffolding around a fleet of agents. Forge is that scaffolding.
