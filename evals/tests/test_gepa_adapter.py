"""Unit tests for runner.gepa.adapter — specifically write_back_descriptions."""

from __future__ import annotations

from pathlib import Path

import pytest

from runner.gepa.adapter import write_back_descriptions


def _make_skill_md(tmp_path: Path, skill: str, content: str) -> Path:
    skill_dir = tmp_path / skill
    skill_dir.mkdir()
    skill_md = skill_dir / "SKILL.md"
    skill_md.write_text(content)
    return skill_md


# ---------------------------------------------------------------------------
# write_back_descriptions — basic rewriting
# ---------------------------------------------------------------------------


def test_write_back_updates_quoted_description(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.gepa.adapter.SKILLS_ROOT", tmp_path)
    skill_md = _make_skill_md(
        tmp_path,
        "my-skill",
        '---\nskill: my-skill\ndescription: "old description"\n---\n# Body\n',
    )

    write_back_descriptions({"my-skill": "new description"})

    result = skill_md.read_text()
    assert 'description: "new description"' in result
    assert "old description" not in result


def test_write_back_updates_unquoted_description(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.gepa.adapter.SKILLS_ROOT", tmp_path)
    skill_md = _make_skill_md(
        tmp_path,
        "my-skill",
        "---\nskill: my-skill\ndescription: old unquoted value\n---\n",
    )

    write_back_descriptions({"my-skill": "new value"})

    result = skill_md.read_text()
    assert 'description: "new value"' in result
    assert "old unquoted value" not in result


def test_write_back_preserves_rest_of_file(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.gepa.adapter.SKILLS_ROOT", tmp_path)
    body = "# Instructions\n\nDo stuff here.\n"
    skill_md = _make_skill_md(
        tmp_path,
        "my-skill",
        f'---\nskill: my-skill\ndescription: "old"\n---\n{body}',
    )

    write_back_descriptions({"my-skill": "updated"})

    result = skill_md.read_text()
    assert body in result
    assert "skill: my-skill" in result


def test_write_back_no_change_when_same_description(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr("runner.gepa.adapter.SKILLS_ROOT", tmp_path)
    skill_md = _make_skill_md(
        tmp_path,
        "my-skill",
        '---\ndescription: "same"\n---\n',
    )
    original_mtime = skill_md.stat().st_mtime

    write_back_descriptions({"my-skill": "same"})

    captured = capsys.readouterr()
    assert "UNCHANGED" in captured.out
    # File should not be rewritten
    assert skill_md.stat().st_mtime == original_mtime


def test_write_back_skips_missing_skill_md(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr("runner.gepa.adapter.SKILLS_ROOT", tmp_path)

    write_back_descriptions({"nonexistent-skill": "some description"})

    captured = capsys.readouterr()
    assert "SKIP" in captured.out


# ---------------------------------------------------------------------------
# Backslash handling — the key fix being tested
# ---------------------------------------------------------------------------


def test_write_back_description_with_backslash(tmp_path, monkeypatch):
    """Backslashes in descriptions must be written verbatim, not doubled."""
    monkeypatch.setattr("runner.gepa.adapter.SKILLS_ROOT", tmp_path)
    skill_md = _make_skill_md(
        tmp_path,
        "my-skill",
        '---\ndescription: "old"\n---\n',
    )

    write_back_descriptions({"my-skill": r"use \n for newlines"})

    result = skill_md.read_text()
    # Should contain exactly one backslash, not two
    assert r'description: "use \n for newlines"' in result
    assert r"use \\n" not in result


def test_write_back_description_with_special_regex_chars(tmp_path, monkeypatch):
    """Descriptions with regex metacharacters must not corrupt the output."""
    monkeypatch.setattr("runner.gepa.adapter.SKILLS_ROOT", tmp_path)
    skill_md = _make_skill_md(
        tmp_path,
        "my-skill",
        '---\ndescription: "old"\n---\n',
    )

    write_back_descriptions({"my-skill": "Use when $VAR or (pattern) needed"})

    result = skill_md.read_text()
    assert 'description: "Use when $VAR or (pattern) needed"' in result


def test_write_back_multiple_skills(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.gepa.adapter.SKILLS_ROOT", tmp_path)
    for skill in ("skill-a", "skill-b"):
        _make_skill_md(tmp_path, skill, f'---\ndescription: "old {skill}"\n---\n')

    write_back_descriptions({"skill-a": "new a", "skill-b": "new b"})

    assert 'description: "new a"' in (tmp_path / "skill-a" / "SKILL.md").read_text()
    assert 'description: "new b"' in (tmp_path / "skill-b" / "SKILL.md").read_text()
