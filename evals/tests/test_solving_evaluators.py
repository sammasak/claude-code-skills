"""Unit tests for runner.solving.evaluators — BashGrader and StructuredRubricJudge."""

from __future__ import annotations

import subprocess
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest

from runner.solving.dataset import SolvingMetadata, SolvingOutput
from runner.solving.evaluators import BashGrader, StructuredRubricJudge

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def make_output(
    *,
    timed_out: bool = False,
    content: str = "some content",
    tmpdir: str = "/tmp/eval-test",
    returncode: int = 0,
) -> SolvingOutput:
    return SolvingOutput(
        content=content,
        stdout="",
        stderr="",
        timed_out=timed_out,
        tmpdir=tmpdir,
        returncode=returncode,
    )


def make_ctx(output: SolvingOutput, metadata: SolvingMetadata | None = None):
    """Create a minimal fake EvaluatorContext using SimpleNamespace."""
    return SimpleNamespace(output=output, metadata=metadata)


def make_meta(test_script: Path, quality_rubric: str | None = None) -> SolvingMetadata:
    return SolvingMetadata(test_script=test_script, quality_rubric=quality_rubric)


# ---------------------------------------------------------------------------
# BashGrader.evaluate — early-exit paths (no subprocess)
# ---------------------------------------------------------------------------


def test_bash_grader_timed_out():
    grader = BashGrader()
    ctx = make_ctx(make_output(timed_out=True))
    result = grader.evaluate(ctx)
    assert result.value is False
    assert result.reason == "Task timed out"


def test_bash_grader_metadata_none():
    grader = BashGrader()
    ctx = make_ctx(make_output(), metadata=None)
    result = grader.evaluate(ctx)
    assert result.value is False
    assert result.reason == "No test script found"


def test_bash_grader_test_script_missing(tmp_path):
    grader = BashGrader()
    missing = tmp_path / "nonexistent.sh"
    meta = make_meta(test_script=missing)
    ctx = make_ctx(make_output(), metadata=meta)
    result = grader.evaluate(ctx)
    assert result.value is False
    assert "No test script found" in result.reason


def test_bash_grader_empty_tmpdir(tmp_path):
    grader = BashGrader()
    test_sh = tmp_path / "test.sh"
    test_sh.write_text("#!/bin/bash\nexit 0\n")
    meta = make_meta(test_script=test_sh)
    ctx = make_ctx(make_output(tmpdir=""), metadata=meta)
    result = grader.evaluate(ctx)
    assert result.value is False
    assert result.reason == "No tmpdir set in output"


# ---------------------------------------------------------------------------
# BashGrader.evaluate — subprocess paths
# ---------------------------------------------------------------------------


def test_bash_grader_subprocess_pass(tmp_path):
    grader = BashGrader()
    test_sh = tmp_path / "test.sh"
    test_sh.write_text("#!/bin/bash\nexit 0\n")
    meta = make_meta(test_script=test_sh)
    ctx = make_ctx(make_output(tmpdir=str(tmp_path)), metadata=meta)

    mock_result = MagicMock()
    mock_result.returncode = 0
    mock_result.stdout = "all tests passed"
    mock_result.stderr = ""

    with patch("runner.solving.evaluators.subprocess.run", return_value=mock_result):
        result = grader.evaluate(ctx)

    assert result.value is True
    assert "all tests passed" in result.reason


def test_bash_grader_subprocess_fail(tmp_path):
    grader = BashGrader()
    test_sh = tmp_path / "test.sh"
    test_sh.write_text("#!/bin/bash\nexit 1\n")
    meta = make_meta(test_script=test_sh)
    ctx = make_ctx(make_output(tmpdir=str(tmp_path)), metadata=meta)

    mock_result = MagicMock()
    mock_result.returncode = 1
    mock_result.stdout = ""
    mock_result.stderr = "assertion failed"

    with patch("runner.solving.evaluators.subprocess.run", return_value=mock_result):
        result = grader.evaluate(ctx)

    assert result.value is False
    assert "assertion failed" in result.reason


def test_bash_grader_subprocess_pass_no_output(tmp_path):
    """Return code 0 with no stdout/stderr → reason defaults to 'PASS'."""
    grader = BashGrader()
    test_sh = tmp_path / "test.sh"
    test_sh.write_text("#!/bin/bash\nexit 0\n")
    meta = make_meta(test_script=test_sh)
    ctx = make_ctx(make_output(tmpdir=str(tmp_path)), metadata=meta)

    mock_result = MagicMock()
    mock_result.returncode = 0
    mock_result.stdout = ""
    mock_result.stderr = ""

    with patch("runner.solving.evaluators.subprocess.run", return_value=mock_result):
        result = grader.evaluate(ctx)

    assert result.value is True
    assert result.reason == "PASS"


def test_bash_grader_subprocess_fail_no_output(tmp_path):
    """Return code non-zero with no stdout/stderr → reason defaults to 'FAIL'."""
    grader = BashGrader()
    test_sh = tmp_path / "test.sh"
    test_sh.write_text("#!/bin/bash\nexit 2\n")
    meta = make_meta(test_script=test_sh)
    ctx = make_ctx(make_output(tmpdir=str(tmp_path)), metadata=meta)

    mock_result = MagicMock()
    mock_result.returncode = 2
    mock_result.stdout = ""
    mock_result.stderr = ""

    with patch("runner.solving.evaluators.subprocess.run", return_value=mock_result):
        result = grader.evaluate(ctx)

    assert result.value is False
    assert result.reason == "FAIL"


def test_bash_grader_timeout_expired(tmp_path):
    grader = BashGrader()
    test_sh = tmp_path / "test.sh"
    test_sh.write_text("#!/bin/bash\nsleep 999\n")
    meta = make_meta(test_script=test_sh)
    ctx = make_ctx(make_output(tmpdir=str(tmp_path)), metadata=meta)

    with patch(
        "runner.solving.evaluators.subprocess.run",
        side_effect=subprocess.TimeoutExpired(cmd="bash", timeout=30),
    ):
        result = grader.evaluate(ctx)

    assert result.value is False
    assert result.reason == "Test script timed out"


def test_bash_grader_generic_exception(tmp_path):
    grader = BashGrader()
    test_sh = tmp_path / "test.sh"
    test_sh.write_text("#!/bin/bash\nexit 0\n")
    meta = make_meta(test_script=test_sh)
    ctx = make_ctx(make_output(tmpdir=str(tmp_path)), metadata=meta)

    with patch(
        "runner.solving.evaluators.subprocess.run",
        side_effect=OSError("permission denied"),
    ):
        result = grader.evaluate(ctx)

    assert result.value is False
    assert "Test script error:" in result.reason
    assert "permission denied" in result.reason


# ---------------------------------------------------------------------------
# StructuredRubricJudge.evaluate — early-exit guard paths (async, no LLM)
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_rubric_judge_metadata_none():
    judge = StructuredRubricJudge()
    ctx = make_ctx(make_output(), metadata=None)
    result = await judge.evaluate(ctx)
    assert result == {}


@pytest.mark.anyio
async def test_rubric_judge_quality_rubric_none():
    judge = StructuredRubricJudge()
    meta = make_meta(test_script=Path("/fake/test.sh"), quality_rubric=None)
    ctx = make_ctx(make_output(), metadata=meta)
    result = await judge.evaluate(ctx)
    assert result == {}


@pytest.mark.anyio
async def test_rubric_judge_timed_out():
    judge = StructuredRubricJudge()
    meta = make_meta(test_script=Path("/fake/test.sh"), quality_rubric="# Rubric\n- Correctness: 0-5")
    ctx = make_ctx(make_output(timed_out=True, content="some content"), metadata=meta)
    result = await judge.evaluate(ctx)
    assert result["rubric_passed"] is False
    assert result["rubric_score"] == 0.0
    assert "rubric_reasoning" in result


@pytest.mark.anyio
async def test_rubric_judge_empty_content():
    judge = StructuredRubricJudge()
    meta = make_meta(test_script=Path("/fake/test.sh"), quality_rubric="# Rubric\n- Correctness: 0-5")
    ctx = make_ctx(make_output(content=""), metadata=meta)
    result = await judge.evaluate(ctx)
    assert result["rubric_passed"] is False
    assert result["rubric_score"] == 0.0
    assert "rubric_reasoning" in result
