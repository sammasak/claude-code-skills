"""Load trigger.yaml files into a pydantic-evals Dataset."""

from __future__ import annotations

import re
import warnings
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

import yaml
from pydantic_evals import Case, Dataset

EVALS_ROOT = Path(__file__).parent.parent.parent
SKILLS = [
    "kubernetes-gitops",
    "rust-engineering",
    "nix-flake-development",
    "secrets-management",
]


@dataclass
class TriggerInput:
    query: str


@dataclass
class TriggerMetadata:
    category: Literal["positive", "hard_negative", "true_negative"]
    source_skill: str


def _slugify(text: str) -> str:
    """Convert a query string to a short slug for case naming."""
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return slug[:60]


def _parse_hard_negative(item_text: str) -> tuple[str, str]:
    """Parse a hard_negative raw item text, preserving '# → skill-name' comments.

    This function must be called with raw YAML item text (not yaml.safe_load output),
    because yaml.safe_load strips YAML comments before returning string values.

    Args:
        item_text: Raw text of one list item, e.g.:
            '"Some query text"             # → secrets-management'

    Returns:
        (query, expected_skill) where expected_skill is "none" if no comment.
    """
    # Split on the YAML comment marker (whitespace + #)
    comment_match = re.search(r'\s+#\s*(.*)', item_text)
    if comment_match:
        comment = comment_match.group(1)
        query_raw = item_text[: comment_match.start()]
        # Parse expected skill: "→ skill-name" or "skill-name"
        expected = comment.lstrip("→ ").strip()
        parts = expected.split()
        expected = parts[0] if parts else "none"
    else:
        warnings.warn(
            f"hard_negative has no '# → skill' comment, defaulting to 'none': {item_text.strip()!r}",
            stacklevel=4,
        )
        query_raw = item_text
        expected = "none"

    # Strip surrounding YAML quotes and whitespace from the query
    query = query_raw.strip().strip("\"'")
    return query, expected


def _parse_hard_negatives_raw(trigger_path: Path) -> list[tuple[str, str]]:
    """Parse hard_negatives from raw YAML text to preserve inline # → comments.

    yaml.safe_load() strips YAML comments, so we read the raw file text to
    extract the expected-skill annotations embedded as inline comments.
    """
    raw = trigger_path.read_text()
    # Match the hard_negatives section: header + all indented list items
    section_match = re.search(
        r"^hard_negatives:\s*\n((?:[ \t]+-[^\n]*\n?)*)",
        raw,
        re.MULTILINE,
    )
    if not section_match:
        return []

    results = []
    for raw_line in section_match.group(1).splitlines():
        # Each line looks like:  '  - "query text"   # → skill-name'
        item_match = re.match(r"^\s+-\s+", raw_line)
        if not item_match:
            continue
        item_text = raw_line[item_match.end():]  # strip leading "  - "
        query, expected = _parse_hard_negative(item_text)
        results.append((query, expected))

    return results


def load_trigger_cases(skill_dir: Path) -> list[Case]:
    """Load cases from a single trigger.yaml file."""
    trigger_path = skill_dir / "trigger.yaml"
    if not trigger_path.exists():
        return []

    data = yaml.safe_load(trigger_path.read_text())
    skill = data.get("skill")
    if not skill:
        raise ValueError(f"trigger.yaml missing 'skill' key: {trigger_path}")
    cases: list[Case] = []

    for query in data.get("positives", []):
        cases.append(
            Case(
                name=f"{skill}::positive::{_slugify(query)}",
                inputs=TriggerInput(query=query),
                expected_output=skill,
                metadata=TriggerMetadata(category="positive", source_skill=skill),
            )
        )

    # Parse hard_negatives from raw text to preserve inline # → skill comments
    # (yaml.safe_load strips comments before returning string values)
    for query, expected in _parse_hard_negatives_raw(trigger_path):
        cases.append(
            Case(
                name=f"{skill}::hard_neg::{_slugify(query)}",
                inputs=TriggerInput(query=query),
                expected_output=expected,
                metadata=TriggerMetadata(category="hard_negative", source_skill=skill),
            )
        )

    for query in data.get("true_negatives", []):
        cases.append(
            Case(
                name=f"{skill}::true_neg::{_slugify(query)}",
                inputs=TriggerInput(query=query),
                expected_output="none",
                metadata=TriggerMetadata(category="true_negative", source_skill=skill),
            )
        )

    return cases


def build_trigger_dataset(
    skill_filter: str | None = None,
) -> Dataset[TriggerInput, str, TriggerMetadata]:
    """Build the full trigger evaluation Dataset across all skills."""
    from pydantic_evals.evaluators import ConfusionMatrixEvaluator, EqualsExpected

    skills = [skill_filter] if skill_filter else SKILLS
    all_cases: list[Case] = []
    for skill in skills:
        all_cases.extend(load_trigger_cases(EVALS_ROOT / skill))

    dataset: Dataset[TriggerInput, str, TriggerMetadata] = Dataset(  # ty: ignore[invalid-assignment]
        name="skill-trigger-eval",
        cases=all_cases,
        evaluators=[EqualsExpected()],
        report_evaluators=[ConfusionMatrixEvaluator()],
    )
    return dataset
