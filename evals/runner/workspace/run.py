from __future__ import annotations

import argparse
import shutil
from datetime import datetime
from pathlib import Path
from typing import Any

from pydantic_evals.reporting import EvaluationReport, EvaluationReportAdapter

from runner.workspace.dataset import (
    WorkspaceInput,
    WorkspaceMetadata,
    WorkspaceOutput,
    build_workspace_dataset,
)
from runner.workspace.task import WORKSPACE_MODEL, run_workspace

RESULTS_DIR: Path = Path(__file__).parent.parent.parent / "results"


def main() -> None:
    parser = argparse.ArgumentParser(description="Run workspace workflow evals")
    parser.add_argument("--workflow", help="Filter to a specific workflow")
    parser.add_argument("--task", help="Filter to a specific task")
    parser.add_argument("--with-quality", action="store_true", help="Include rubric judge")
    parser.add_argument(
        "--max-concurrency",
        type=int,
        default=3,
        help="Maximum concurrent invocations",
    )
    parser.add_argument("--no-save", action="store_true", help="Skip saving results JSON")
    parser.add_argument(
        "--no-cleanup",
        action="store_true",
        help="Keep tmpdir artifacts after evaluation; useful for debugging; tmpdirs are in /tmp/eval-workspace-*/",
    )
    args = parser.parse_args()

    dataset = build_workspace_dataset(
        workflow_filter=args.workflow,
        task_filter=args.task,
        with_quality=args.with_quality,
    )
    print(f"Running workspace evals: {len(dataset.cases)} cases")

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    workflow_tag = f"-{args.workflow}" if args.workflow else ""
    run_name = f"workspace{workflow_tag}-{timestamp}"

    report = dataset.evaluate_sync(
        run_workspace,
        name=run_name,
        max_concurrency=args.max_concurrency,
    )

    report.print(
        include_input=False,
        include_output=True,
        include_reasons=True,
    )

    if not args.no_save:
        RESULTS_DIR.mkdir(exist_ok=True)
        report_path = RESULTS_DIR / f"{run_name}.json"
        report_path.write_text(EvaluationReportAdapter.dump_json(report, indent=2).decode())
        print(f"\nReport saved to {report_path}")

    if not args.no_cleanup:
        _cleanup_tmpdirs(report)


def _cleanup_tmpdirs(report: EvaluationReport[WorkspaceInput, WorkspaceOutput, WorkspaceMetadata]) -> None:
    """Clean up mkdtemp directories created during workspace evals."""
    cleaned = 0
    for case_result in report.cases:
        output = case_result.output
        if output is not None and output.tmpdir:
            tmpdir = Path(output.tmpdir)
            if tmpdir.exists():
                shutil.rmtree(tmpdir, ignore_errors=True)
                cleaned += 1
    for failure in report.failures:
        output = getattr(failure, "output", None)
        if output is not None and getattr(output, "tmpdir", None):
            tmpdir = Path(output.tmpdir)
            if tmpdir.exists():
                shutil.rmtree(tmpdir, ignore_errors=True)
                cleaned += 1
    if cleaned:
        print(f"Cleaned up {cleaned} temporary directories")


if __name__ == "__main__":
    main()
