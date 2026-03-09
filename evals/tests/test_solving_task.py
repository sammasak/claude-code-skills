"""Unit tests for runner.solving.task — _build_prompt and run_solving."""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from runner.solving.dataset import SolvingInput
from runner.solving.task import _build_prompt, run_solving

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def make_input(
    instruction: str = "Write a hello world program.",
    skill: str = "rust-engineering",
    task_id: str = "task-1",
    output_filename: str = "main.rs",
) -> SolvingInput:
    return SolvingInput(
        instruction=instruction,
        skill=skill,
        task_id=task_id,
        output_filename=output_filename,
    )


# ---------------------------------------------------------------------------
# _build_prompt
# ---------------------------------------------------------------------------


def test_build_prompt_contains_tmpdir():
    inputs = make_input()
    prompt = _build_prompt(inputs, "/tmp/my-eval-dir")
    assert "/tmp/my-eval-dir" in prompt


def test_build_prompt_contains_output_filename():
    inputs = make_input(output_filename="solution.rs")
    prompt = _build_prompt(inputs, "/tmp/eval-xyz")
    assert "solution.rs" in prompt


def test_build_prompt_contains_instruction():
    instruction = "Implement a binary search function."
    inputs = make_input(instruction=instruction)
    prompt = _build_prompt(inputs, "/tmp/eval-abc")
    assert instruction in prompt


def test_build_prompt_write_target_is_tmpdir_not_eval_output():
    """The primary write target in the preamble must be the isolated tmpdir, not a shared path."""
    tmpdir = "/tmp/eval-rust-engineering-task-1-xyz"
    inputs = make_input(output_filename="main.rs")
    prompt = _build_prompt(inputs, tmpdir)
    # The preamble starts with "IMPORTANT: Write your output file to <tmpdir>/..."
    assert prompt.startswith(f"IMPORTANT: Write your output file to {tmpdir}/main.rs")


def test_build_prompt_preamble_precedes_instruction():
    """The preamble should come before the original instruction in the prompt."""
    instruction = "Do something."
    inputs = make_input(instruction=instruction)
    tmpdir = "/tmp/testdir"
    prompt = _build_prompt(inputs, tmpdir)
    preamble_end = prompt.index(tmpdir) + len(tmpdir)
    instruction_start = prompt.index(instruction)
    assert preamble_end < instruction_start


# ---------------------------------------------------------------------------
# run_solving — success: file exists
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_run_solving_success_file_exists(tmp_path):
    """Process returns 0 and writes the output file."""
    inputs = make_input(output_filename="result.rs")

    mock_proc = MagicMock()
    mock_proc.communicate = AsyncMock(return_value=(b"all done", b""))
    mock_proc.returncode = 0
    mock_proc.kill = MagicMock()

    # We need to intercept tempfile.mkdtemp to know where the file should go.
    # Instead, patch create_subprocess_exec and write the file in a side-effect
    # by capturing the tmpdir from the call to _build_prompt (which is called
    # inside run_solving before creating the subprocess).
    #
    # Simpler approach: after proc.communicate() returns the file should exist.
    # We patch mkdtemp to return a known path inside tmp_path.
    known_tmpdir = str(tmp_path / "eval-dir")
    (tmp_path / "eval-dir").mkdir()
    artifact = tmp_path / "eval-dir" / "result.rs"
    artifact.write_text("fn main() {}")

    with patch("runner.solving.task.tempfile.mkdtemp", return_value=known_tmpdir), \
         patch("runner.solving.task.asyncio.create_subprocess_exec", AsyncMock(return_value=mock_proc)):
        result = await run_solving(inputs)

    assert result.timed_out is False
    assert result.returncode == 0
    assert result.content == "fn main() {}"
    assert result.tmpdir == known_tmpdir


# ---------------------------------------------------------------------------
# run_solving — success: file missing
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_run_solving_success_file_missing(tmp_path):
    """Process returns 0 but Claude didn't write the output file."""
    inputs = make_input(output_filename="missing.rs")

    mock_proc = MagicMock()
    mock_proc.communicate = AsyncMock(return_value=(b"I forgot to write", b""))
    mock_proc.returncode = 0
    mock_proc.kill = MagicMock()

    known_tmpdir = str(tmp_path / "eval-dir2")
    (tmp_path / "eval-dir2").mkdir()
    # Deliberately do NOT write the artifact.

    with patch("runner.solving.task.tempfile.mkdtemp", return_value=known_tmpdir), \
         patch("runner.solving.task.asyncio.create_subprocess_exec", AsyncMock(return_value=mock_proc)):
        result = await run_solving(inputs)

    assert result.timed_out is False
    assert result.content == ""
    assert result.returncode == 0


# ---------------------------------------------------------------------------
# run_solving — timeout path
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_run_solving_timeout(tmp_path):
    """asyncio.wait_for raises TimeoutError → timed_out=True, returncode=-1."""
    inputs = make_input()

    mock_proc = MagicMock()
    # communicate() is called a second time after kill(), so it must not raise
    mock_proc.communicate = AsyncMock(return_value=(b"", b""))
    mock_proc.returncode = None
    mock_proc.kill = MagicMock()

    known_tmpdir = str(tmp_path / "eval-timeout")
    (tmp_path / "eval-timeout").mkdir()

    # Patch wait_for itself to raise TimeoutError so the inner except block fires
    with patch("runner.solving.task.tempfile.mkdtemp", return_value=known_tmpdir), \
         patch("runner.solving.task.asyncio.create_subprocess_exec", AsyncMock(return_value=mock_proc)), \
         patch("runner.solving.task.asyncio.wait_for", side_effect=TimeoutError()):
        result = await run_solving(inputs)

    assert result.timed_out is True
    assert result.returncode == -1
    assert result.content == ""


# ---------------------------------------------------------------------------
# run_solving — exception path (create_subprocess_exec raises)
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_run_solving_exception(tmp_path):
    """create_subprocess_exec raises → returncode=-2, stderr contains message."""
    inputs = make_input()

    known_tmpdir = str(tmp_path / "eval-exc")
    (tmp_path / "eval-exc").mkdir()

    with patch("runner.solving.task.tempfile.mkdtemp", return_value=known_tmpdir), \
         patch(
             "runner.solving.task.asyncio.create_subprocess_exec",
             side_effect=Exception("claude not found"),
         ):
        result = await run_solving(inputs)

    assert result.returncode == -2
    assert result.timed_out is False
    assert "claude not found" in result.stderr
