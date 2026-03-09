"""Unit tests for runner.solving.dataset — build_solving_dataset."""

from __future__ import annotations

import warnings
from typing import TYPE_CHECKING

from runner.solving.evaluators import BashGrader, StructuredRubricJudge

if TYPE_CHECKING:
    from pathlib import Path

# ---------------------------------------------------------------------------
# Fixtures / helpers
# ---------------------------------------------------------------------------


def make_task_dir(
    tmp_path: Path,
    skill: str,
    task_id: str,
    *,
    with_quality: bool = False,
    skip_instruction: bool = False,
    skip_test: bool = False,
) -> Path:
    task_path = tmp_path / skill / "tasks" / task_id
    task_path.mkdir(parents=True)
    if not skip_instruction:
        (task_path / "instruction.md").write_text(f"Instruction for {task_id}")
    if not skip_test:
        (task_path / "test.sh").write_text("#!/bin/bash\nexit 0")
    if with_quality:
        (task_path / "quality.md").write_text("# Quality\nMinimum acceptable: 5/8")
    return task_path


# ---------------------------------------------------------------------------
# build_solving_dataset — basic loading
# ---------------------------------------------------------------------------


def test_build_solving_dataset_no_filter(tmp_path, monkeypatch):
    """All tasks from all patched SOLVING_SKILLS are returned."""
    monkeypatch.setattr("runner.solving.dataset.EVALS_ROOT", tmp_path)
    monkeypatch.setattr(
        "runner.solving.dataset.SOLVING_SKILLS",
        ["skill-a", "skill-b"],
    )
    # Add known key → filename mappings so no warning fires
    monkeypatch.setattr(
        "runner.solving.dataset.OUTPUT_FILENAMES",
        {
            ("skill-a", "task-1"): "output-a.md",
            ("skill-b", "task-1"): "output-b.md",
        },
    )

    make_task_dir(tmp_path, "skill-a", "task-1")
    make_task_dir(tmp_path, "skill-b", "task-1")

    from runner.solving.dataset import build_solving_dataset

    ds = build_solving_dataset()
    assert len(ds.cases) == 2
    names = {c.name for c in ds.cases}
    assert "skill-a::task-1" in names
    assert "skill-b::task-1" in names


def test_build_solving_dataset_skill_filter(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.solving.dataset.EVALS_ROOT", tmp_path)
    monkeypatch.setattr(
        "runner.solving.dataset.SOLVING_SKILLS",
        ["skill-a", "skill-b"],
    )
    monkeypatch.setattr(
        "runner.solving.dataset.OUTPUT_FILENAMES",
        {
            ("skill-a", "task-1"): "output-a.md",
            ("skill-b", "task-1"): "output-b.md",
        },
    )

    make_task_dir(tmp_path, "skill-a", "task-1")
    make_task_dir(tmp_path, "skill-b", "task-1")

    from runner.solving.dataset import build_solving_dataset

    ds = build_solving_dataset(skill_filter="skill-a")
    assert len(ds.cases) == 1
    assert ds.cases[0].name == "skill-a::task-1"


def test_build_solving_dataset_task_filter(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.solving.dataset.EVALS_ROOT", tmp_path)
    monkeypatch.setattr("runner.solving.dataset.SOLVING_SKILLS", ["skill-a"])
    monkeypatch.setattr(
        "runner.solving.dataset.OUTPUT_FILENAMES",
        {
            ("skill-a", "task-1"): "out1.md",
            ("skill-a", "task-2"): "out2.md",
        },
    )

    make_task_dir(tmp_path, "skill-a", "task-1")
    make_task_dir(tmp_path, "skill-a", "task-2")

    from runner.solving.dataset import build_solving_dataset

    ds = build_solving_dataset(skill_filter="skill-a", task_filter="task-2")
    assert len(ds.cases) == 1
    assert ds.cases[0].name == "skill-a::task-2"


# ---------------------------------------------------------------------------
# build_solving_dataset — skipping incomplete tasks
# ---------------------------------------------------------------------------


def test_build_solving_dataset_skips_missing_instruction(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.solving.dataset.EVALS_ROOT", tmp_path)
    monkeypatch.setattr("runner.solving.dataset.SOLVING_SKILLS", ["skill-a"])
    monkeypatch.setattr(
        "runner.solving.dataset.OUTPUT_FILENAMES",
        {("skill-a", "task-1"): "out.md"},
    )

    make_task_dir(tmp_path, "skill-a", "task-1", skip_instruction=True)

    from runner.solving.dataset import build_solving_dataset

    ds = build_solving_dataset()
    assert len(ds.cases) == 0


def test_build_solving_dataset_skips_missing_test(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.solving.dataset.EVALS_ROOT", tmp_path)
    monkeypatch.setattr("runner.solving.dataset.SOLVING_SKILLS", ["skill-a"])
    monkeypatch.setattr(
        "runner.solving.dataset.OUTPUT_FILENAMES",
        {("skill-a", "task-1"): "out.md"},
    )

    make_task_dir(tmp_path, "skill-a", "task-1", skip_test=True)

    from runner.solving.dataset import build_solving_dataset

    ds = build_solving_dataset()
    assert len(ds.cases) == 0


# ---------------------------------------------------------------------------
# build_solving_dataset — evaluator selection
# ---------------------------------------------------------------------------


def test_build_solving_dataset_with_quality_rubric(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.solving.dataset.EVALS_ROOT", tmp_path)
    monkeypatch.setattr("runner.solving.dataset.SOLVING_SKILLS", ["skill-a"])
    monkeypatch.setattr(
        "runner.solving.dataset.OUTPUT_FILENAMES",
        {("skill-a", "task-1"): "out.md"},
    )

    make_task_dir(tmp_path, "skill-a", "task-1", with_quality=True)

    from runner.solving.dataset import build_solving_dataset

    ds = build_solving_dataset()
    assert len(ds.cases) == 1
    evaluator_types = {type(e) for e in ds.cases[0].evaluators}
    assert BashGrader in evaluator_types
    assert StructuredRubricJudge in evaluator_types


def test_build_solving_dataset_without_quality_rubric(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.solving.dataset.EVALS_ROOT", tmp_path)
    monkeypatch.setattr("runner.solving.dataset.SOLVING_SKILLS", ["skill-a"])
    monkeypatch.setattr(
        "runner.solving.dataset.OUTPUT_FILENAMES",
        {("skill-a", "task-1"): "out.md"},
    )

    make_task_dir(tmp_path, "skill-a", "task-1", with_quality=False)

    from runner.solving.dataset import build_solving_dataset

    ds = build_solving_dataset()
    assert len(ds.cases) == 1
    evaluator_types = {type(e) for e in ds.cases[0].evaluators}
    assert BashGrader in evaluator_types
    assert StructuredRubricJudge not in evaluator_types


# ---------------------------------------------------------------------------
# build_solving_dataset — unknown task warns
# ---------------------------------------------------------------------------


def test_build_solving_dataset_unknown_key_warns(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.solving.dataset.EVALS_ROOT", tmp_path)
    monkeypatch.setattr("runner.solving.dataset.SOLVING_SKILLS", ["skill-x"])
    # Empty mapping — task-1 is unknown
    monkeypatch.setattr("runner.solving.dataset.OUTPUT_FILENAMES", {})

    make_task_dir(tmp_path, "skill-x", "task-1")

    from runner.solving.dataset import build_solving_dataset

    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        ds = build_solving_dataset()

    assert len(caught) == 1
    assert issubclass(caught[0].category, UserWarning)
    assert "skill-x" in str(caught[0].message)
    assert "task-1" in str(caught[0].message)
    # Falls back to output.md
    assert ds.cases[0].inputs.output_filename == "output.md"


# ---------------------------------------------------------------------------
# build_solving_dataset — SolvingInput fields
# ---------------------------------------------------------------------------


def test_build_solving_dataset_input_fields(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.solving.dataset.EVALS_ROOT", tmp_path)
    monkeypatch.setattr("runner.solving.dataset.SOLVING_SKILLS", ["skill-a"])
    monkeypatch.setattr(
        "runner.solving.dataset.OUTPUT_FILENAMES",
        {("skill-a", "task-1"): "result.md"},
    )

    task_path = make_task_dir(tmp_path, "skill-a", "task-1")
    (task_path / "instruction.md").write_text("Do the thing.")  # overwrite default

    from runner.solving.dataset import build_solving_dataset

    ds = build_solving_dataset()
    inp = ds.cases[0].inputs
    assert inp.skill == "skill-a"
    assert inp.task_id == "task-1"
    assert inp.output_filename == "result.md"
    assert inp.instruction == "Do the thing."


# ---------------------------------------------------------------------------
# build_solving_dataset — SolvingMetadata.test_script path
# ---------------------------------------------------------------------------


def test_build_solving_dataset_metadata_test_script(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.solving.dataset.EVALS_ROOT", tmp_path)
    monkeypatch.setattr("runner.solving.dataset.SOLVING_SKILLS", ["skill-a"])
    monkeypatch.setattr(
        "runner.solving.dataset.OUTPUT_FILENAMES",
        {("skill-a", "task-1"): "out.md"},
    )

    task_path = make_task_dir(tmp_path, "skill-a", "task-1")
    expected_test_sh = task_path / "test.sh"

    from runner.solving.dataset import build_solving_dataset

    ds = build_solving_dataset()
    meta = ds.cases[0].metadata
    assert meta.test_script == expected_test_sh
