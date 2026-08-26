"""Pydantic-ai task function for solving evals: LLM with skill as system prompt."""

from __future__ import annotations

import re
import tempfile
from pathlib import Path

from pydantic_ai import Agent

from runner.solving.dataset import SolvingInput, SolvingOutput

SKILLS_ROOT = Path(__file__).parent.parent.parent.parent / "skills"
SOLVE_MODEL = "anthropic:claude-haiku-4-5-20251001"


def _load_skill_body(skill: str) -> str:
    """Return the SKILL.md body (below the frontmatter) for the given skill name."""
    skill_md = SKILLS_ROOT / skill / "SKILL.md"
    if not skill_md.exists():
        return ""
    content = skill_md.read_text()
    if content.startswith("---"):
        end = content.find("---", 3)
        if end != -1:
            return content[end + 3 :].strip()
    return content


def _strip_code_fence(text: str) -> str:
    """Strip a single markdown code fence (```lang ... ```) from LLM output."""
    match = re.search(r"```(?:\w+)?\n(.*?)```", text, re.DOTALL)
    return match.group(1).strip() if match else text


async def run_solving(inputs: SolvingInput, model: str = SOLVE_MODEL) -> SolvingOutput:
    """Run the skill-guided LLM on a task and capture its text output.

    The skill's SKILL.md body is injected as the system prompt, grounding the LLM
    in the skill's patterns and conventions. The response is written to a tmpdir so
    that BashGrader can still run test.sh assertions against the output file.
    """
    skill_body = _load_skill_body(inputs.skill)
    agent = Agent(model, instructions=skill_body or None, output_type=str)

    tmpdir = tempfile.mkdtemp(prefix=f"eval-{inputs.skill}-{inputs.task_id}-")

    try:
        result = await agent.run(inputs.instruction)
        content = _strip_code_fence(result.output)

        artifact = Path(tmpdir) / inputs.output_filename
        artifact.write_text(content)

        return SolvingOutput(
            content=content,
            stdout="",
            stderr="",
            timed_out=False,
            tmpdir=tmpdir,
            returncode=0,
        )

    except Exception as e:
        return SolvingOutput(
            content="",
            stdout="",
            stderr=str(e),
            timed_out=False,
            tmpdir=tmpdir,
            returncode=-1,
        )
