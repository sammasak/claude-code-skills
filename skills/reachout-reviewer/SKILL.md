---
name: reachout-reviewer
description: Use when drafting or reviewing LinkedIn messages, recruiter replies, cold outreach, or any professional networking message before sending.
---

# Reachout Reviewer

## Overview

Review and draft professional networking messages. **Never draft without first completing the research phase.** Context from the job ad and company shapes every word of the reply.

## Inbound Posture (When They Contact You First)

When a recruiter or company initiates contact, you are evaluating them, not applying to them.

- Signal is **1 sentence max**, not a paragraph
- Questions do the work, not the pitch
- Do not explain, justify, or contextualize your stack or choices
- Do not match their energy or enthusiasm
- Under 80 words total is the target
- If there is a stack mismatch, ask about it as a question. Do not pre-justify it.

The implicit message: you are filtering them.

## Signal Source (Check Before Drafting)

Professional signal always comes first. Never lead with personal or homelab projects when professional work is available.

Before drafting, check:
- `~/workspace/whoami/companies/<current-employer>.md` for what was actually built
- `~/workspace/whoami/profile.md` for career positioning
- `~/workspace/whoami/personal-preferences.md` for stack and domain exclusions — if the role's stack conflicts with stated preferences, the question should probe that directly rather than ignoring it

Personal projects are secondary signal. Only include them if they demonstrate something the professional work does not.

## Pre-Draft Research (Required)

**Do not draft a reply until both steps are complete.**

### Step 1: Ingest the job posting

If a job posting URL is present, fetch it with WebFetch and extract:
- Actual tech stack (languages, frameworks, infra)
- Role type (greenfield, maintenance, platform, product)
- Team size and structure signals
- Seniority expectations
- Any culture or process signals (async, on-call, shipping cadence)

If no URL is present, say so and ask for it before continuing.

### Step 2: Research the company

Use WebSearch to look up the company. Extract:
- What they actually do (not just their tagline)
- Funding stage and approximate headcount
- Engineering blog or tech talks (reveals real stack and culture)
- Recent news (hiring wave, layoffs, product launch, pivot)

### Step 3: Summarize findings before drafting

Output a brief research block before the draft:

```
**Company:** [name, stage, headcount estimate]
**Stack:** [actual languages/frameworks found]
**Role signals:** [greenfield/maintenance, frontend-heavy/backend-heavy, etc.]
**Culture signals:** [anything notable]
**Open questions:** [things not found, would need to ask]
```

The signal paragraph and questions in the reply must map to what was found here. If the stack is unknown after research, that becomes one of the questions.

## Reply Type — Decide Before Drafting

After research, classify the reply before writing a single word:

| Type | When | Pattern |
|------|------|---------|
| **Interested** | Stack fits, company interesting, role plausible | Signal + questions |
| **Uncertain** | One blocker that could be resolved | Single clarifying question, no signal |
| **Soft decline** | Not a fit but worth being courteous | One sentence reason + door left open |
| **Hard decline** | Domain exclusion, clear mismatch, not looking | One sentence, no explanation |

Wrong type = wrong draft. Do not default to Interested when Uncertain or Decline is more honest.

## Writing Patterns by Reply Type

### Interested (inbound)
```
[1 sentence: specific professional signal that maps to their ask]

[2 questions that gate your interest]

[Sign-off]
```

### Uncertain
```
[1 clarifying question that resolves the blocker]

[Sign-off]
```
No signal. No pitch. The question does everything.

### Soft Decline
```
Tack för meddelandet. [1 sentence: honest reason, specific not vague]

[Sign-off]
```
"Tack för meddelandet" is the one allowed opener for declines — it softens without being sycophantic. No "lycka till", no "feel free to reach out." One sentence reason, done.

### Hard Decline
Do not reply. Or if a reply is warranted (warm relationship, referral context):
```
Inte rätt timing för mig just nu.

[Sign-off]
```

## Writing Rules (All Types)

- No em dashes (-- or &mdash;) — use commas, periods, or restructure
- No filler openers ("Kul att höra av dig", "Thanks for reaching out")
- Match the language they wrote in (Swedish → Swedish, English → English)
- Never mirror their vague language back at them
- Shorter is always better than longer

## Checklist

**Research (gate)**
- [ ] `whoami/personal-preferences.md` checked for stack and domain exclusions
- [ ] `whoami/companies/<employer>.md` checked for professional signal
- [ ] Job posting fetched and stack extracted (or noted as missing)
- [ ] Company researched: stage, product, headcount
- [ ] Reply type decided: Interested / Uncertain / Soft decline / Hard decline

**Draft**
- [ ] Correct template used for reply type
- [ ] No signal in Uncertain or Decline replies
- [ ] No filler opener
- [ ] No em dashes
- [ ] Under 80 words (inbound interested), under 30 words (decline/uncertain)
- [ ] Ends with question or period, not a soft CTA

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Drafting without fetching the job ad | Stop. Fetch it first. Stack and role type change everything. |
| Drafting without researching the company | Stop. Company stage and product change what signal is relevant. |
| Signal based on recruiter message alone | Recruiter messages are generic. Use the actual job ad. |
| Leading with personal/homelab projects | Check `whoami/companies/<employer>.md` first. Professional work is the signal. |
| Selling yourself when they reached out | They came to you. 1 sentence of signal, then questions. Let them work. |
| Long reply to inbound outreach | Under 80 words. Shorter signals more confidence than longer. |
| Em dash used | Replace with comma, period, or split into two sentences |
| Questions too broad ("Tell me more about the role") | Ask what would actually change your answer ("Does the team write Rust?") |
| Opener mirrors recruiter language | Cut it. Start with the signal paragraph. |
| Lists every matching skill | Pick the 1-2 most relevant, mention them specifically |
| Ends with "Let me know if..." | End with the questions themselves |
