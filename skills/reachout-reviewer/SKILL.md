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

## Writing Guidelines

**Always:**
- Use commas, periods, or restructure sentences instead of em dashes (never use --)
- Keep replies under 150 words unless content demands more
- Be direct. No filler phrases ("Great to hear from you", "Thanks so much for reaching out")
- One concrete paragraph of relevant signal, then specific questions
- End with questions, not a soft CTA

**Never:**
- Em dashes (-- or &mdash;)
- Oversell or list every credential
- Mirror the recruiter's vague language back at them

## Reachout Review Checklist

Before finalizing any outreach message, verify each item:

**Research (gate — do not proceed without these)**
- [ ] Professional signal source checked (`~/workspace/whoami/companies/<employer>.md`)
- [ ] Job posting fetched and tech stack extracted (or noted as missing)
- [ ] Company researched: stage, headcount, real product understood
- [ ] Research summary block written
- [ ] Inbound posture applied if they initiated contact

**Signal**
- [ ] Mentions 1-2 specific, relevant things from your actual work (not generic "experience with X")
- [ ] Avoids listing everything; picks what's most relevant to the role

**Questions**
- [ ] Asks the questions that would actually change whether you respond (company name, tech stack, key decision)
- [ ] Questions are pointed enough that a vague answer is itself informative
- [ ] Not more than 2-3 questions

**Style**
- [ ] No em dashes
- [ ] No filler opener
- [ ] Could be read in 30 seconds

**Tone**
- [ ] Curious but not eager
- [ ] Not dismissive or cold
- [ ] Honest about what would make it a fit vs not

## Template Structure

```
[Optional 1-sentence acknowledgment if something specific warrants it]

[1 paragraph: relevant signal from your actual work that maps to their ask]

[2-3 focused questions that gate your interest]

[Sign-off]
```

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
