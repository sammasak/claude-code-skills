"""Skill dispatcher agent using pydantic-ai."""

from __future__ import annotations

import re

from pydantic_ai import Agent
from pydantic_evals import increment_eval_metric

from runner.trigger.dataset import EVALS_ROOT, SKILLS, TriggerInput

SKILLS_ROOT = EVALS_ROOT.parent / "skills"
EXTRA_SKILLS = ["container-workflows", "observability-patterns"]


def _read_skill_description(skill_name: str) -> str:
    """Read the description field from a SKILL.md frontmatter.

    Falls back to a generic description if the file is missing, has no YAML
    frontmatter, or has no description key.
    """
    skill_md = SKILLS_ROOT / skill_name / "SKILL.md"
    if not skill_md.exists():
        return f"Use when working with {skill_name.replace('-', ' ')}."

    content = skill_md.read_text()
    # Parse YAML frontmatter between --- delimiters
    match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    if not match:
        return f"Use when working with {skill_name.replace('-', ' ')}."

    frontmatter = match.group(1)
    # Extract description field
    desc_match = re.search(r'^description:\s*["\']?(.+?)["\']?\s*$', frontmatter, re.MULTILINE)
    if desc_match:
        return desc_match.group(1).strip('"\'')
    return f"Use when working with {skill_name.replace('-', ' ')}."


def load_skill_descriptions(overrides: dict[str, str] | None = None) -> dict[str, str]:
    """Load skill descriptions, optionally overriding specific ones (for GEPA).

    EXTRA_SKILLS are also loaded because they can appear as expected targets in
    hard_negative cases — the dispatcher must know about them even though they
    are not in the primary SKILLS list being evaluated.
    """
    descriptions = {skill: _read_skill_description(skill) for skill in SKILLS}
    # Also add skills that might appear as hard_negative targets
    for skill in EXTRA_SKILLS:
        descriptions[skill] = _read_skill_description(skill)
    if overrides:
        descriptions.update(overrides)
    return descriptions


def _build_dispatcher_prompt(descriptions: dict[str, str]) -> str:
    """Build the dispatcher system prompt from current skill descriptions.

    The "none" key is excluded from the skill list presented to the model;
    instead "none" is described inline in the rules as the fallback when no
    skill matches.
    """
    skill_list = "\n".join(
        f"- {name}: {desc}" for name, desc in sorted(descriptions.items()) if name != "none"
    )
    return f"""You are a skill dispatcher. Given a user query, return the name of the most relevant skill, or "none" if no skill matches.

Available skills:
{skill_list}

Rules:
- Return ONLY the skill name exactly as listed above (e.g. "kubernetes-gitops") or "none"
- "none" means no skill is relevant — the query is generic or off-topic
- Pick the MOST specific skill; do not return "none" if a skill clearly matches
- No explanation, no punctuation — just the skill name or "none\""""


def build_dispatcher_agent(descriptions: dict[str, str] | None = None) -> Agent[None, str]:
    """Build a dispatcher agent with the given (or default) skill descriptions.

    Always creates a fresh Agent instance — there is no caching. This is
    intentional: callers such as the GEPA adapter need to construct agents with
    different description sets across iterations.
    """
    descs = descriptions if descriptions is not None else load_skill_descriptions()
    return Agent(
        "anthropic:claude-haiku-4-5-20251001",
        output_type=str,
        instructions=_build_dispatcher_prompt(descs),
        model_settings={"temperature": 0.0},
    )


async def dispatch_skill(inputs: TriggerInput) -> str:
    """Task function: dispatch a query to the most relevant skill.

    Output is normalized before returning: whitespace is stripped, the string
    is lowercased, and surrounding quotes are removed. This ensures consistent
    comparison against the expected skill names defined in the dataset.
    """
    agent = build_dispatcher_agent()
    result = await agent.run(inputs.query)
    # Track token usage per case
    usage = result.usage()
    increment_eval_metric("input_tokens", usage.input_tokens or 0)
    increment_eval_metric("output_tokens", usage.output_tokens or 0)
    # Normalize output
    output = result.output.strip().lower().strip('"\'')
    return output


__all__ = [
    "EXTRA_SKILLS",
    "SKILLS_ROOT",
    "build_dispatcher_agent",
    "dispatch_skill",
    "load_skill_descriptions",
]
