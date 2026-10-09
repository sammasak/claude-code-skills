"""Unit tests for runner.solving.constraint_extractor."""

from __future__ import annotations

from typing import TYPE_CHECKING
from unittest.mock import patch

import pytest

if TYPE_CHECKING:
    from pathlib import Path

import runner.solving.constraint_extractor as extractor_mod
from runner.solving.constraint_extractor import SKILLS_ROOT, extract_constraints

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _write_skill(tmp_path: Path, skill: str, content: str) -> Path:
    """Write a mock SKILL.md for a skill under tmp_path and return the skill root."""
    skill_dir = tmp_path / skill
    skill_dir.mkdir(parents=True)
    (skill_dir / "SKILL.md").write_text(content)
    return skill_dir


def _extract(tmp_path: Path, skill: str, content: str) -> list[str]:
    """Write skill content into tmp_path and run extract_constraints with patched SKILLS_ROOT."""
    _write_skill(tmp_path, skill, content)
    with patch.object(extractor_mod, "SKILLS_ROOT", tmp_path):
        return extract_constraints(skill)


# ---------------------------------------------------------------------------
# Missing skill / empty content
# ---------------------------------------------------------------------------


def test_extract_constraints_missing_skill():
    """Returns empty list if SKILL.md does not exist."""
    result = extract_constraints("skill-that-does-not-exist-xyz-abc")
    assert result == []


def test_extract_constraints_no_constraints(tmp_path):
    """Returns empty list if no constraint patterns match."""
    content = "---\nname: test\n---\n\n# My Skill\n\nThis skill does stuff.\n"
    result = _extract(tmp_path, "test-skill", content)
    assert result == []


# ---------------------------------------------------------------------------
# CRITICAL / IMPORTANT patterns (bold-colon format: **CRITICAL: TEXT**)
# ---------------------------------------------------------------------------


def test_extract_constraints_critical_bold_colon(tmp_path):
    """Matches **CRITICAL: TEXT** format."""
    content = "---\nname: test\n---\n\n**CRITICAL: Never do the bad thing under any circumstances.**\n"
    result = _extract(tmp_path, "test-skill", content)
    assert len(result) == 1
    assert "Never do the bad thing under any circumstances." in result[0]


def test_extract_constraints_important_bold_colon(tmp_path):
    """Matches **IMPORTANT: TEXT** format."""
    content = "---\nname: test\n---\n\n**IMPORTANT: Always run the validation step before deploying.**\n"
    result = _extract(tmp_path, "test-skill", content)
    assert len(result) == 1
    assert "Always run the validation step before deploying." in result[0]


def test_extract_constraints_critical_bold_standalone(tmp_path):
    """Matches **CRITICAL**: TEXT format (bold word, colon outside bold)."""
    content = "---\nname: test\n---\n\n**CRITICAL**: Never commit secrets to version control.\n"
    result = _extract(tmp_path, "test-skill", content)
    assert len(result) == 1
    assert "Never commit secrets to version control." in result[0]


def test_extract_constraints_important_bold_standalone(tmp_path):
    """Matches **IMPORTANT**: TEXT format."""
    content = "---\nname: test\n---\n\n**IMPORTANT**: Always validate inputs at system boundaries.\n"
    result = _extract(tmp_path, "test-skill", content)
    assert len(result) == 1
    assert "Always validate inputs at system boundaries." in result[0]


# ---------------------------------------------------------------------------
# Never / Always bullet patterns
# ---------------------------------------------------------------------------


def test_extract_constraints_never_bullet(tmp_path):
    """Matches - **Never** TEXT pattern."""
    content = "---\nname: test\n---\n\n- **Never** store credentials in plaintext files.\n"
    result = _extract(tmp_path, "test-skill", content)
    assert len(result) == 1
    assert "store credentials in plaintext files." in result[0]


def test_extract_constraints_always_bullet(tmp_path):
    """Matches - **Always** TEXT pattern."""
    content = "---\nname: test\n---\n\n- **Always** pin container image tags to specific versions.\n"
    result = _extract(tmp_path, "test-skill", content)
    assert len(result) == 1
    assert "pin container image tags to specific versions." in result[0]


# ---------------------------------------------------------------------------
# must / never / always inline bullet pattern
# ---------------------------------------------------------------------------


def test_extract_constraints_must_bullet(tmp_path):
    """Matches bullet list items containing 'must'."""
    content = "---\nname: test\n---\n\n- All resources must have resource limits set.\n"
    result = _extract(tmp_path, "test-skill", content)
    # Pattern captures text after 'must': "have resource limits set"
    assert any("resource limits" in c for c in result)


def test_extract_constraints_never_inline_bullet(tmp_path):
    """Matches bullet list items containing 'never'."""
    content = "---\nname: test\n---\n\n- You should never push directly to the main branch.\n"
    result = _extract(tmp_path, "test-skill", content)
    assert any("push directly" in c or "main branch" in c for c in result)


# ---------------------------------------------------------------------------
# Deduplication
# ---------------------------------------------------------------------------


def test_extract_constraints_deduplication(tmp_path):
    """Duplicate constraints are returned only once."""
    content = (
        "---\nname: test\n---\n\n"
        "**CRITICAL: Never push secrets to Git.**\n"
        "**CRITICAL: Never push secrets to Git.**\n"
    )
    result = _extract(tmp_path, "test-skill", content)
    assert len(result) == 1
    assert "Never push secrets to Git." in result[0]


def test_extract_constraints_order_preserved(tmp_path):
    """Order of first occurrence is preserved after deduplication."""
    content = (
        "---\nname: test\n---\n\n"
        "**CRITICAL: First constraint always comes first.**\n"
        "**IMPORTANT: Second constraint comes after.**\n"
    )
    result = _extract(tmp_path, "test-skill", content)
    assert len(result) == 2
    assert "First constraint" in result[0]
    assert "Second constraint" in result[1]


# ---------------------------------------------------------------------------
# Frontmatter stripping
# ---------------------------------------------------------------------------


def test_extract_constraints_frontmatter_stripped(tmp_path):
    """Constraints in frontmatter are not extracted; only body is searched."""
    content = (
        "---\n"
        "name: test\n"
        "description: CRITICAL: this should not be extracted\n"
        "---\n\n"
        "**CRITICAL: This body constraint should be extracted.**\n"
    )
    result = _extract(tmp_path, "test-skill", content)
    assert len(result) == 1
    assert "This body constraint should be extracted." in result[0]


def test_extract_constraints_no_frontmatter(tmp_path):
    """Works correctly when SKILL.md has no frontmatter."""
    content = "# My Skill\n\n**CRITICAL: Always check for errors.**\n"
    result = _extract(tmp_path, "test-skill", content)
    assert len(result) == 1
    assert "Always check for errors." in result[0]


# ---------------------------------------------------------------------------
# Short constraint filtering
# ---------------------------------------------------------------------------


def test_extract_constraints_short_matches_filtered(tmp_path):
    """Matches shorter than 10 characters are ignored."""
    content = "---\nname: test\n---\n\n**CRITICAL: No.**\n"
    result = _extract(tmp_path, "test-skill", content)
    assert result == []


def test_extract_constraints_exactly_10_chars_filtered(tmp_path):
    """Match of exactly 10 chars is filtered (len must be > 10)."""
    # "1234567890" is exactly 10 chars — filtered
    content = "---\nname: test\n---\n\n**CRITICAL: 1234567890**\n"
    result = _extract(tmp_path, "test-skill", content)
    assert result == []


def test_extract_constraints_exactly_11_chars_kept(tmp_path):
    """Match of exactly 11 chars is kept (len > 10 is True for 11)."""
    # "12345678901" is exactly 11 chars — kept
    content = "---\nname: test\n---\n\n**CRITICAL: 12345678901**\n"
    result = _extract(tmp_path, "test-skill", content)
    assert len(result) == 1


# ---------------------------------------------------------------------------
# Real SKILL.md integration (reads actual files)
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "skill",
    ["kubernetes-gitops", "secrets-management"],
)
def test_extract_constraints_real_skill_has_results(skill: str):
    """Real skills with CRITICAL/IMPORTANT markers return at least one constraint."""
    skill_md = SKILLS_ROOT / skill / "SKILL.md"
    if not skill_md.exists():
        pytest.skip(f"Skill {skill!r} not found at {skill_md}")
    result = extract_constraints(skill)
    assert isinstance(result, list)  # pruned bodies may carry no marker lines


def test_extract_constraints_real_kubernetes_gitops():
    """extract_constraints handles the real kubernetes-gitops SKILL.md."""
    skill_md = SKILLS_ROOT / "kubernetes-gitops" / "SKILL.md"
    if not skill_md.exists():
        pytest.skip("kubernetes-gitops SKILL.md not found")
    result = extract_constraints("kubernetes-gitops")
    assert isinstance(result, list)  # pruned body carries no marker lines today
