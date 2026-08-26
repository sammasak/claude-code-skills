from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from pydantic_evals import Case, Dataset

EVALS_ROOT: Path = Path(__file__).parent.parent.parent
WORKSPACE_ROOT: Path = EVALS_ROOT.parent.parent / "workspace"

WORKSPACE_WORKFLOWS: list[str] = [
    "deploy-service",
    "provision-vm",
    "release-nixos",
]

OUTPUT_FILENAMES: dict[tuple[str, str], str] = {
    ("deploy-service", "task-doable"): "plan.md",
    ("deploy-service", "task-workstation-api"): "plan.md",
    ("provision-vm", "task-with-goal"): "plan.md",
    ("provision-vm", "task-without-goal"): "plan.md",
    ("release-nixos", "task-local"): "plan.md",
}


@dataclass
class WorkspaceInput:
    instruction: str
    workflow: str
    task_id: str
    output_filename: str


@dataclass
class WorkspaceOutput:
    content: str
    stdout: str
    stderr: str
    timed_out: bool
    tmpdir: str
    returncode: int


@dataclass
class WorkspaceMetadata:
    test_script: Path
    quality_rubric: str | None


def build_workspace_dataset(
    workflow_filter: str | None = None,
    task_filter: str | None = None,
    with_quality: bool = False,
) -> Dataset[WorkspaceInput, WorkspaceOutput, WorkspaceMetadata]:
    from runner.solving.evaluators import BashGrader, StructuredRubricJudge

    cases: list[Case] = []

    workflows_dir = EVALS_ROOT / "workspace"
    workflows = WORKSPACE_WORKFLOWS if not workflow_filter else [workflow_filter]

    for workflow in workflows:
        tasks_dir = workflows_dir / workflow
        if not tasks_dir.exists():
            continue

        for task_path in sorted(tasks_dir.iterdir()):
            if not task_path.is_dir():
                continue

            task_id = task_path.name
            if task_filter and task_id != task_filter:
                continue

            instruction_path = task_path / "instruction.md"
            test_script_path = task_path / "test.sh"

            if not instruction_path.exists() or not test_script_path.exists():
                continue

            instruction = instruction_path.read_text()
            output_filename = OUTPUT_FILENAMES.get((workflow, task_id), "plan.md")

            quality_rubric: str | None = None
            quality_path = task_path / "quality.md"
            if with_quality and quality_path.exists():
                quality_rubric = quality_path.read_text()

            evaluators: list = [BashGrader()]
            if with_quality and quality_rubric:
                evaluators.append(StructuredRubricJudge())

            cases.append(
                Case(
                    name=f"{workflow}::{task_id}",
                    inputs=WorkspaceInput(
                        instruction=instruction,
                        workflow=workflow,
                        task_id=task_id,
                        output_filename=output_filename,
                    ),
                    metadata=WorkspaceMetadata(
                        test_script=test_script_path,
                        quality_rubric=quality_rubric,
                    ),
                    evaluators=tuple(evaluators),
                )
            )

    return Dataset(name="workspace", cases=cases)
