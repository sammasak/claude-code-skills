"""Skill dispatcher agent using pydantic-ai."""

from __future__ import annotations

import re

from pydantic_ai import Agent

from runner.trigger.dataset import EVALS_ROOT, SKILLS, SkillName, TriggerInput

SKILLS_ROOT = EVALS_ROOT.parent / "skills"
EXTRA_SKILLS = ["container-workflows", "observability-patterns"]

_DEFAULT_AGENT: Agent[None, str] | None = None


def _read_skill_description(skill_name: str) -> str:
    """Read the description field from a SKILL.md frontmatter."""
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
    """Load skill descriptions, optionally overriding specific ones (for GEPA)."""
    descriptions = {skill: _read_skill_description(skill) for skill in SKILLS}
    # Also add skills that might appear as hard_negative targets
    for skill in EXTRA_SKILLS:
        descriptions[skill] = _read_skill_description(skill)
    if overrides:
        descriptions.update(overrides)
    return descriptions


def _build_dispatcher_prompt(descriptions: dict[str, str]) -> str:
    """Build the dispatcher system prompt from current skill descriptions."""
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
    """Build the pydantic-ai dispatcher agent with current skill descriptions."""
    global _DEFAULT_AGENT
    if descriptions is None:
        if _DEFAULT_AGENT is None:
            _DEFAULT_AGENT = Agent(
                "anthropic:claude-haiku-4-5-20251001",
                output_type=str,
                instructions=_build_dispatcher_prompt(load_skill_descriptions()),
                model_settings={"temperature": 0},
            )
        return _DEFAULT_AGENT
    return Agent(
        "anthropic:claude-haiku-4-5-20251001",
        output_type=str,
        instructions=_build_dispatcher_prompt(descriptions),
        model_settings={"temperature": 0},
    )


async def dispatch_skill(inputs: TriggerInput) -> str:
    """Task function: dispatch a query to the most relevant skill."""
    agent = build_dispatcher_agent()
    result = await agent.run(inputs.query)
    # Normalize output: strip whitespace, ensure it's a valid skill name or "none"
    output = result.output.strip().lower().strip('"\'')
    return output


__all__ = [
    "SkillName",
    "SKILLS_ROOT",
    "EXTRA_SKILLS",
    "load_skill_descriptions",
    "build_dispatcher_agent",
    "dispatch_skill",
]
