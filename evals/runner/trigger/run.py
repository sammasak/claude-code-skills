"""Entry point for trigger evals: python -m runner.trigger"""

from __future__ import annotations

import argparse
import asyncio
import json
from datetime import datetime
from pathlib import Path

from runner.trigger.dataset import build_trigger_dataset
from runner.trigger.task import dispatch_skill

RESULTS_DIR = Path(__file__).parent.parent.parent / "results"


def main() -> None:
    parser = argparse.ArgumentParser(description="Run skill trigger evaluations")
    parser.add_argument(
        "--repeat", type=int, default=1, help="Number of times to repeat each case"
    )
    parser.add_argument(
        "--skill",
        type=str,
        default=None,
        help="Filter to a single skill (e.g. kubernetes-gitops)",
    )
    parser.add_argument(
        "--max-concurrency",
        type=int,
        default=5,
        help="Maximum concurrent API calls",
    )
    parser.add_argument(
        "--no-save", action="store_true", help="Do not save JSON report to results/"
    )
    args = parser.parse_args()

    dataset = build_trigger_dataset(skill_filter=args.skill)
    print(f"Running trigger evals: {len(dataset.cases)} cases")
    if args.repeat > 1:
        print(f"  Repeating each case {args.repeat}x")

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    run_name = f"trigger-{timestamp}"

    report = dataset.evaluate_sync(
        dispatch_skill,
        name=run_name,
        max_concurrency=args.max_concurrency,
        repeat=args.repeat,
    )

    report.print(
        include_input=True,
        include_output=True,
        include_expected_output=True,
    )

    if not args.no_save:
        RESULTS_DIR.mkdir(exist_ok=True)
        report_path = RESULTS_DIR / f"{run_name}.json"
        report_path.write_text(report.model_dump_json(indent=2))
        print(f"\nReport saved to {report_path}")


if __name__ == "__main__":
    main()
