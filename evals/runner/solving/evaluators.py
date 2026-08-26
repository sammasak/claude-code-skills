"""Evaluators for solving evals: BashGrader and StructuredRubricJudge."""

from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass

import anyio
from pydantic import BaseModel
from pydantic_ai import Agent
from pydantic_evals.evaluators import EvaluationReason, Evaluator, EvaluatorContext

from runner.solving.dataset import SolvingInput, SolvingMetadata, SolvingOutput


@dataclass
class BashGrader(Evaluator[SolvingInput, SolvingOutput, SolvingMetadata]):
    """Run the task's test.sh script against the eval output directory."""

    timeout: int = 30

    def evaluate(
        self, ctx: EvaluatorContext[SolvingInput, SolvingOutput, SolvingMetadata]
    ) -> EvaluationReason:
        """Run test.sh and return pass/fail with the script's output as the reason.

        Code paths:
        - ``ctx.output.timed_out`` is True → immediate FAIL (Claude exceeded timeout)
        - ``ctx.metadata`` is None or test script missing → immediate FAIL (misconfigured task)
        - ``ctx.output.tmpdir`` is empty → immediate FAIL (task function did not set tmpdir)
        - subprocess exits 0 → PASS; non-zero → FAIL (stdout+stderr used as reason)
        - subprocess itself times out → FAIL with "Test script timed out"
        - any other exception → FAIL with the exception message
        """
        if ctx.output.timed_out:
            return EvaluationReason(value=False, reason="Task timed out")

        if ctx.metadata is None or not ctx.metadata.test_script.exists():
            return EvaluationReason(value=False, reason="No test script found")

        tmpdir = ctx.output.tmpdir
        if not tmpdir:
            return EvaluationReason(value=False, reason="No tmpdir set in output")

        try:
            result = subprocess.run(
                ["bash", str(ctx.metadata.test_script)],
                capture_output=True,
                text=True,
                timeout=self.timeout,
                env={**os.environ, "EVAL_OUTPUT_DIR": tmpdir},
            )
            passed = result.returncode == 0
            output_text = (result.stdout + result.stderr).strip()
            return EvaluationReason(value=passed, reason=output_text or ("PASS" if passed else "FAIL"))
        except subprocess.TimeoutExpired:
            return EvaluationReason(value=False, reason="Test script timed out")
        except Exception as e:
            return EvaluationReason(value=False, reason=f"Test script error: {e}")

    async def evaluate_async(
        self, ctx: EvaluatorContext[SolvingInput, SolvingOutput, SolvingMetadata]
    ) -> EvaluationReason:
        """Run evaluate() in a thread pool to avoid blocking the event loop.

        ``subprocess.run`` is a blocking call. Offloading it via
        ``anyio.to_thread.run_sync`` keeps the eval runner's async event loop
        responsive while multiple tasks are evaluated concurrently.
        """
        return await anyio.to_thread.run_sync(self.evaluate, ctx)  # ty: ignore[unresolved-attribute]


class RubricScore(BaseModel):
    """Structured per-dimension rubric score from LLM judge."""

    scores: dict[str, int]
    total: int
    maximum: int
    minimum: int
    passed: bool
    reasoning: str


@dataclass
class StructuredRubricJudge(Evaluator[SolvingInput, SolvingOutput, SolvingMetadata]):
    """LLM-based rubric scoring using quality.md dimensions."""

    model: str = "anthropic:claude-haiku-4-5-20251001"

    async def evaluate(
        self, ctx: EvaluatorContext[SolvingInput, SolvingOutput, SolvingMetadata]
    ) -> dict[str, float | bool | str]:
        """Score the task output against a quality rubric using an LLM judge.

        Early-exit paths:
        - No rubric defined (``quality_rubric`` is None) → returns ``{}`` to
          signal that rubric scoring should be skipped entirely for this task.
        - Output timed out or is empty → returns
          ``{"rubric_passed": False, ...}`` without calling the judge.

        On success, returns a dict with keys ``rubric_passed`` (bool),
        ``rubric_score`` (float 0-1), and ``rubric_reasoning`` (str).
        Judge errors are caught and surfaced as a failed rubric score.
        """
        if ctx.metadata is None or ctx.metadata.quality_rubric is None:
            return {}  # No rubric — skip silently

        if ctx.output.timed_out or not ctx.output.content:
            return {
                "rubric_passed": False,
                "rubric_score": 0.0,
                "rubric_reasoning": "No output to evaluate",
            }

        judge = Agent(
            self.model,
            output_type=RubricScore,
            instructions=self._build_judge_prompt(ctx.metadata.quality_rubric),
        )

        try:
            result = await judge.run(
                f"Evaluate the following output:\n\n```\n{ctx.output.content}\n```"
            )
            score: RubricScore = result.output  # ty: ignore[invalid-assignment]
            normalized = min(score.total / max(score.maximum, 1), 1.0)  # max(score.maximum, 1) guards against division by zero if rubric scores are empty
            return {
                "rubric_passed": score.passed,
                "rubric_score": round(normalized, 3),
                "rubric_reasoning": score.reasoning,
            }
        except Exception as e:
            return {
                "rubric_passed": False,
                "rubric_score": 0.0,
                "rubric_reasoning": f"Judge error: {e}",
            }

    def _build_judge_prompt(self, rubric: str) -> str:
        """Build the system prompt that instructs the LLM judge to score against the given rubric."""
        return f"""You are a technical reviewer evaluating outputs from an AI coding assistant.

Score the provided output using this rubric:

{rubric}

Return a RubricScore with:
- scores: dict mapping each dimension name to its integer score
- total: sum of all dimension scores
- maximum: the total possible points (from the rubric's "X/Y" denominator)
- minimum: the minimum acceptable total (from the rubric's "Minimum acceptable: X/Y" line)
- passed: true if total >= minimum
- reasoning: 1-2 sentences explaining the scores

Be precise and consistent. Only give full marks when criteria are fully met."""
