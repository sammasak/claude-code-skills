"""Subprocess runner: executes claude -p for each solving task."""

from __future__ import annotations

import asyncio
import tempfile
from pathlib import Path

from runner.solving.dataset import SolvingInput, SolvingOutput

CLAUDE_TIMEOUT = 120  # seconds per task


def _build_prompt(inputs: SolvingInput, tmpdir: str) -> str:
    """Prepend output directory preamble to the instruction."""
    preamble = (
        f"IMPORTANT: Write your output file to {tmpdir}/{inputs.output_filename} "
        f"(not /tmp/eval-output/{inputs.output_filename}).\n\n"
    )
    return preamble + inputs.instruction


async def run_solving(inputs: SolvingInput, timeout: int = CLAUDE_TIMEOUT) -> SolvingOutput:
    """Task function: run Claude on a solving task with tmpdir isolation."""
    # Create a persistent tempdir (no auto-cleanup — BashGrader uses it after us)
    tmpdir = tempfile.mkdtemp(prefix=f"eval-{inputs.skill}-{inputs.task_id}-")

    prompt = _build_prompt(inputs, tmpdir)

    try:
        proc = await asyncio.create_subprocess_exec(
            "claude",
            "-p",
            "--dangerously-skip-permissions",
            prompt,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        try:
            stdout_bytes, stderr_bytes = await asyncio.wait_for(
                proc.communicate(), timeout=timeout
            )
        except asyncio.TimeoutError:
            proc.kill()
            await proc.communicate()
            return SolvingOutput(
                content="",
                stdout="",
                stderr="",
                timed_out=True,
                tmpdir=tmpdir,
                returncode=-1,
            )

        # Read the artifact if Claude wrote it
        artifact = Path(tmpdir) / inputs.output_filename
        content = artifact.read_text() if artifact.exists() else ""

        return SolvingOutput(
            content=content,
            stdout=stdout_bytes.decode(errors="replace"),
            stderr=stderr_bytes.decode(errors="replace"),
            timed_out=False,
            tmpdir=tmpdir,
            returncode=proc.returncode,
        )

    except Exception as e:
        return SolvingOutput(
            content="",
            stdout="",
            stderr=str(e),
            timed_out=False,
            tmpdir=tmpdir,
            returncode=-2,
        )
