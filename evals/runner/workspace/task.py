from __future__ import annotations

import tempfile
from pathlib import Path

from pydantic_ai import Agent

from runner.workspace.dataset import EVALS_ROOT, WORKSPACE_ROOT, WorkspaceInput, WorkspaceOutput

WORKSPACE_MODEL: str = "anthropic:claude-haiku-4-5-20251001"


def _load_workflow_context(workflow: str) -> str:
    context_path = WORKSPACE_ROOT / workflow / "CONTEXT.md"
    if not context_path.exists():
        raise FileNotFoundError(f"CONTEXT.md not found for workflow: {workflow}")
    return context_path.read_text()


async def run_workspace(inputs: WorkspaceInput, model: str = WORKSPACE_MODEL) -> WorkspaceOutput:
    """Run the workspace workflow eval.

    Injects the workflow CONTEXT.md as the system prompt with a preamble
    that simulates the agent having already navigated from CLAUDE.md.
    """
    context_body = _load_workflow_context(inputs.workflow)

    system_prompt = (
        f"You have read ~/workspace/CLAUDE.md and have been routed to "
        f"workflows/{inputs.workflow}/CONTEXT.md. "
        f"The following is that file's contents.\n\n"
        f"{context_body}\n\n"
        f"Execute the workflow stage contracts for the task described by the user. "
        f"Produce your deployment plan at /tmp/eval-output/{inputs.output_filename} "
        f"with labeled ## Stage N sections. Each stage section must include "
        f"the exact commands to run and the verification step."
    )

    tmpdir = tempfile.mkdtemp(prefix=f"eval-workspace-{inputs.workflow}-{inputs.task_id}-")
    output_path = Path(tmpdir) / inputs.output_filename

    try:
        agent = Agent(model, instructions=system_prompt, output_type=str)
        result = await agent.run(inputs.instruction)
        content = result.output if isinstance(result.output, str) else str(result.output)

        output_path.write_text(content)

        return WorkspaceOutput(
            content=content,
            stdout="",
            stderr="",
            timed_out=False,
            tmpdir=tmpdir,
            returncode=0,
        )

    except Exception as e:
        return WorkspaceOutput(
            content="",
            stdout="",
            stderr=str(e),
            timed_out=False,
            tmpdir=tmpdir,
            returncode=-1,
        )
