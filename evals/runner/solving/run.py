"""Entry point for solving evals: python -m runner.solving"""

from __future__ import annotations

import argparse
import shutil
from datetime import datetime
from functools import partial
from pathlib import Path

from pydantic_evals.reporting import EvaluationReport, EvaluationReportAdapter

from runner.solving.dataset import (
    SolvingInput,
    SolvingMetadata,
    SolvingOutput,
    build_solving_dataset,
)
from runner.solving.task import run_solving

RESULTS_DIR = Path(__file__).parent.parent.parent / "results"


def main() -> None:
    parser = argparse.ArgumentParser(description="Run skill solving evaluations")
    parser.add_argument(
        "--skill",
        type=str,
        default=None,
        help="Filter to a single skill (e.g. kubernetes-gitops)",
    )
    parser.add_argument(
        "--task",
        type=str,
        default=None,
        help="Filter to a single task (e.g. task-1)",
    )
    parser.add_argument(
        "--max-concurrency",
        type=int,
        default=3,
        help="Maximum concurrent Claude invocations",
    )
    parser.add_argument(
        "--no-save", action="store_true", help="Do not save JSON report to results/"
    )
    parser.add_argument(
        "--no-cleanup",
        action="store_true",
        help="Keep temporary output directories after evaluation; useful for debugging failing cases; tmpdirs are in /tmp/eval-*/",
    )
    args = parser.parse_args()

    dataset = build_solving_dataset(
        skill_filter=args.skill,
        task_filter=args.task,
    )
    print(f"Running solving evals: {len(dataset.cases)} cases")

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    skill_tag = f"-{args.skill}" if args.skill else ""
    run_name = f"solving{skill_tag}-{timestamp}"

    task_fn = partial(run_solving)
    report = dataset.evaluate_sync(
        task_fn,
        name=run_name,
        max_concurrency=args.max_concurrency,
    )

    report.print(
        include_input=False,  # instruction is long; skip for readability
        include_output=True,
        include_reasons=True,
    )

    if not args.no_save:
        RESULTS_DIR.mkdir(exist_ok=True)
        report_path = RESULTS_DIR / f"{run_name}.json"
        report_path.write_text(EvaluationReportAdapter.dump_json(report, indent=2).decode())
        print(f"\nReport saved to {report_path}")

    # Clean up tmpdirs unless --no-cleanup is set
    if not args.no_cleanup:
        _cleanup_tmpdirs(report)


def _cleanup_tmpdirs(report: EvaluationReport[SolvingInput, SolvingOutput, SolvingMetadata]) -> None:
    """Clean up mkdtemp directories created during solving evals.

    Each solving task creates a temporary directory via ``tempfile.mkdtemp``
    and stores its path in ``SolvingOutput.tmpdir``. Because mkdtemp directories
    persist until explicitly deleted (unlike ``TemporaryDirectory`` context
    managers), this function must be called after the report is finalised to
    avoid leaking directories in /tmp/. The typed ``EvaluationReport`` is used
    directly so that ``case_result.output`` is already typed as ``SolvingOutput``
    rather than requiring a cast.
    """
    cleaned = 0
    for case_result in report.cases:
        output = case_result.output
        if output is not None and output.tmpdir:
            tmpdir = Path(output.tmpdir)
            if tmpdir.exists():
                shutil.rmtree(tmpdir, ignore_errors=True)
                cleaned += 1
    if cleaned:
        print(f"Cleaned up {cleaned} temporary directories")


if __name__ == "__main__":
    main()
