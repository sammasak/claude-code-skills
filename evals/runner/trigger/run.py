"""Entry point for trigger evals: python -m runner.trigger"""

from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path

from pydantic_evals.reporting import EvaluationReportAdapter

from runner.trigger.dataset import build_trigger_dataset
from runner.trigger.task import dispatch_skill

RESULTS_DIR = Path(__file__).parent.parent.parent / "results"


def _print_per_skill_metrics(report: object) -> None:
    """Print per-skill precision, recall, and F1 from evaluation report."""
    from collections import defaultdict

    tp: dict[str, int] = defaultdict(int)
    fp: dict[str, int] = defaultdict(int)
    fn: dict[str, int] = defaultdict(int)

    for case_result in getattr(report, "cases", []):
        expected = getattr(case_result, "expected_output", None)
        output = getattr(case_result, "output", None)
        if expected is None or output is None:
            continue
        if expected == output:
            tp[expected] += 1
        else:
            fn[expected] += 1
            fp[output] += 1

    all_skills = sorted(set(tp) | set(fp) | set(fn))
    if not all_skills:
        return

    print("\n--- Per-Skill Metrics ---")
    print(f"{'Skill':<30} {'Prec':>6} {'Rec':>6} {'F1':>6} {'TP':>4} {'FP':>4} {'FN':>4}")
    print("-" * 68)
    for skill in all_skills:
        p = tp[skill] / (tp[skill] + fp[skill]) if (tp[skill] + fp[skill]) > 0 else 0.0
        r = tp[skill] / (tp[skill] + fn[skill]) if (tp[skill] + fn[skill]) > 0 else 0.0
        f1 = 2 * p * r / (p + r) if (p + r) > 0 else 0.0
        print(f"{skill:<30} {p:>6.1%} {r:>6.1%} {f1:>6.1%} {tp[skill]:>4} {fp[skill]:>4} {fn[skill]:>4}")


def _compare_with_baseline(report: object, results_dir: Path) -> None:
    """Compare current run accuracy against the most recent previous run."""
    import json

    prev_reports = sorted(results_dir.glob("trigger-*.json"), reverse=True)
    if not prev_reports:
        return

    try:
        prev_data = json.loads(prev_reports[0].read_text())
    except Exception:
        return

    # Count current accuracy from report cases
    current_cases = getattr(report, "cases", [])
    if not current_cases:
        return
    current_correct = sum(
        1 for c in current_cases
        if getattr(c, "output", None) == getattr(c, "expected_output", None)
    )
    current_acc = current_correct / len(current_cases)

    # Count previous accuracy from JSON
    prev_cases = prev_data.get("cases", [])
    if not prev_cases:
        return
    prev_correct = sum(
        1 for c in prev_cases
        if c.get("output") == c.get("expected_output")
    )
    prev_acc = prev_correct / len(prev_cases) if prev_cases else 0.0

    delta = current_acc - prev_acc
    sign = "+" if delta >= 0 else ""
    prev_name = prev_reports[0].stem
    print(f"\n--- Regression vs {prev_name} ---")
    print(f"Previous: {prev_acc:.1%} ({prev_correct}/{len(prev_cases)})")
    print(f"Current:  {current_acc:.1%} ({current_correct}/{len(current_cases)})")
    print(f"Delta:    {sign}{delta:.1%} {'✓ IMPROVED' if delta > 0 else ('✗ REGRESSION' if delta < 0 else '= UNCHANGED')}")
    if delta < -0.02:  # 2% regression threshold
        print("⚠ Warning: accuracy dropped by more than 2%")


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

    _print_per_skill_metrics(report)
    if not args.no_save:
        _compare_with_baseline(report, RESULTS_DIR)
        RESULTS_DIR.mkdir(exist_ok=True)
        report_path = RESULTS_DIR / f"{run_name}.json"
        report_path.write_text(EvaluationReportAdapter.dump_json(report, indent=2).decode())
        print(f"\nReport saved to {report_path}")


if __name__ == "__main__":
    main()
