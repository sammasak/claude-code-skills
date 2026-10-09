"""Unit tests for runner.solving.run — _print_pass_at_k and _bash_grader_passed."""

from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import MagicMock

from runner.solving.run import _bash_grader_passed, _estimate_pass_at_k, _print_pass_at_k

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_run(bash_passed: bool | None = None, *, in_assertions: bool = True) -> SimpleNamespace:
    """Build a fake ReportCase with BashGrader in assertions or scores."""
    if bash_passed is None:
        return SimpleNamespace(assertions={}, scores={})
    result = SimpleNamespace(value=bash_passed)
    if in_assertions:
        return SimpleNamespace(assertions={"BashGrader": result}, scores={})
    else:
        return SimpleNamespace(assertions={}, scores={"BashGrader": result})


def _make_group(name: str, runs: list) -> SimpleNamespace:
    return SimpleNamespace(name=name, runs=runs, failures=[])


def _make_report(groups: list | None) -> MagicMock:
    report = MagicMock()
    report.case_groups.return_value = groups
    return report


# ---------------------------------------------------------------------------
# _bash_grader_passed
# ---------------------------------------------------------------------------


def test_bash_grader_passed_true_in_assertions():
    run = _make_run(bash_passed=True, in_assertions=True)
    assert _bash_grader_passed(run) is True


def test_bash_grader_passed_false_in_assertions():
    run = _make_run(bash_passed=False, in_assertions=True)
    assert _bash_grader_passed(run) is False


def test_bash_grader_passed_true_in_scores():
    run = _make_run(bash_passed=True, in_assertions=False)
    assert _bash_grader_passed(run) is True


def test_bash_grader_passed_false_in_scores():
    run = _make_run(bash_passed=False, in_assertions=False)
    assert _bash_grader_passed(run) is False


def test_bash_grader_passed_missing():
    """Returns False when BashGrader is absent from both assertions and scores."""
    run = _make_run(bash_passed=None)
    assert _bash_grader_passed(run) is False


# ---------------------------------------------------------------------------
# _print_pass_at_k
# ---------------------------------------------------------------------------


def test_print_pass_at_k_no_groups(capsys):
    """Prints nothing when case_groups() returns None."""
    report = _make_report(None)
    _print_pass_at_k(report, 3)
    captured = capsys.readouterr()
    assert captured.out == ""


def test_print_pass_at_k_empty_groups(capsys):
    """Prints nothing when case_groups() returns empty list (early return)."""
    report = _make_report([])
    _print_pass_at_k(report, 3)
    captured = capsys.readouterr()
    assert captured.out == ""


def test_print_pass_at_k_all_pass(capsys):
    """Reports 3/3 samples (100%) when all runs pass."""
    runs = [_make_run(True), _make_run(True), _make_run(True)]
    group = _make_group("my-skill::task-1", runs)
    report = _make_report([group])
    _print_pass_at_k(report, 3)
    captured = capsys.readouterr()
    assert "3/3 samples" in captured.out
    assert "pass@3=100.0%" in captured.out
    assert "my-skill::task-1" in captured.out


def test_print_pass_at_k_all_fail(capsys):
    """Reports 0/3 samples (0%) when all runs fail."""
    runs = [_make_run(False), _make_run(False), _make_run(False)]
    group = _make_group("my-skill::task-2", runs)
    report = _make_report([group])
    _print_pass_at_k(report, 3)
    captured = capsys.readouterr()
    assert "0/3 samples" in captured.out
    assert "pass@3=0.0%" in captured.out


def test_print_pass_at_k_mixed(capsys):
    """Reports 2/3 samples when 2 of 3 runs pass."""
    runs = [_make_run(True), _make_run(False), _make_run(True)]
    group = _make_group("my-skill::task-3", runs)
    report = _make_report([group])
    _print_pass_at_k(report, 3)
    captured = capsys.readouterr()
    assert "2/3 samples" in captured.out


def test_print_pass_at_k_header(capsys):
    """Prints the pass@k header with the correct k value and Chen et al reference."""
    runs = [_make_run(True)]
    group = _make_group("skill::task-1", runs)
    report = _make_report([group])
    _print_pass_at_k(report, 5)
    captured = capsys.readouterr()
    assert "pass@5" in captured.out
    assert "Chen et al" in captured.out


def test_print_pass_at_k_multiple_groups(capsys):
    """Prints a line for each group."""
    group1 = _make_group("skill-a::task-1", [_make_run(True), _make_run(True)])
    group2 = _make_group("skill-b::task-1", [_make_run(False), _make_run(True)])
    report = _make_report([group1, group2])
    _print_pass_at_k(report, 2)
    captured = capsys.readouterr()
    assert "skill-a::task-1" in captured.out
    assert "skill-b::task-1" in captured.out
    assert "2/2 samples" in captured.out
    assert "1/2 samples" in captured.out


# ---------------------------------------------------------------------------
# _estimate_pass_at_k
# ---------------------------------------------------------------------------


def test_estimate_pass_at_k_all_pass():
    """All c=n pass → pass@k = 1.0 regardless of k."""
    assert _estimate_pass_at_k(n=5, c=5, k=3) == 1.0


def test_estimate_pass_at_k_none_pass():
    """c=0 → pass@k = 0.0 always."""
    assert _estimate_pass_at_k(n=5, c=0, k=3) == 0.0


def test_estimate_pass_at_k_known_value():
    """n=5, c=2, k=3: intermediate result strictly between 0 and 1."""
    result = _estimate_pass_at_k(n=5, c=2, k=3)
    assert 0.0 < result < 1.0


def test_estimate_pass_at_k_n_less_than_k():
    """When n < k, falls back to c > 0 check."""
    assert _estimate_pass_at_k(n=2, c=1, k=5) == 1.0
    assert _estimate_pass_at_k(n=2, c=0, k=5) == 0.0


def test_estimate_pass_at_k_codex_example():
    """n=200, c=164, k=100: matches the Codex paper's known value ≈ 1.0."""
    result = _estimate_pass_at_k(n=200, c=164, k=100)
    assert result > 0.99


def test_print_pass_at_k_counts_task_failures_in_n_total(capsys):
    """Task-level failures (exceptions) count in n_total denominator."""
    # 2 completed runs (1 pass, 1 fail) + 1 task failure = n_total=3
    runs = [_make_run(True), _make_run(False)]
    failure = SimpleNamespace()  # a task-level failure with no output
    group = SimpleNamespace(name="skill::task-1", runs=runs, failures=[failure])
    report = _make_report([group])
    _print_pass_at_k(report, 3)
    captured = capsys.readouterr()
    # n_total = 2 runs + 1 failure = 3; only 1 passes
    assert "1/3 samples" in captured.out
