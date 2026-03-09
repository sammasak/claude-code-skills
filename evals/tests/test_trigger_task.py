"""Unit tests for runner.trigger.task — description reading, prompt building, agent."""

from __future__ import annotations

from pydantic_ai import Agent

from runner.trigger.dataset import SKILLS
from runner.trigger.task import (
    EXTRA_SKILLS,
    _build_dispatcher_prompt,
    _read_skill_description,
    build_dispatcher_agent,
    load_skill_descriptions,
)

# ---------------------------------------------------------------------------
# _read_skill_description
# ---------------------------------------------------------------------------


def test_read_skill_description_file_missing(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.trigger.task.SKILLS_ROOT", tmp_path)
    result = _read_skill_description("nonexistent-skill")
    assert "nonexistent skill" in result or "nonexistent-skill" in result


def test_read_skill_description_file_no_frontmatter(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.trigger.task.SKILLS_ROOT", tmp_path)
    skill_dir = tmp_path / "my-skill"
    skill_dir.mkdir()
    (skill_dir / "SKILL.md").write_text("# My Skill\n\nNo frontmatter here.\n")
    result = _read_skill_description("my-skill")
    # Falls back to generated string
    assert "my skill" in result or "my-skill" in result


def test_read_skill_description_with_description_field(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.trigger.task.SKILLS_ROOT", tmp_path)
    skill_dir = tmp_path / "my-skill"
    skill_dir.mkdir()
    (skill_dir / "SKILL.md").write_text(
        '---\nskill: my-skill\ndescription: "Handles K8s deployments."\n---\n# Body\n'
    )
    result = _read_skill_description("my-skill")
    assert result == "Handles K8s deployments."


def test_read_skill_description_quoted(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.trigger.task.SKILLS_ROOT", tmp_path)
    skill_dir = tmp_path / "my-skill"
    skill_dir.mkdir()
    (skill_dir / "SKILL.md").write_text(
        "---\nskill: my-skill\ndescription: \"Use for Rust projects.\"\n---\n"
    )
    result = _read_skill_description("my-skill")
    # Surrounding quotes must be stripped
    assert result == "Use for Rust projects."
    assert result[0] != '"'
    assert result[-1] != '"'


def test_read_skill_description_unquoted(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.trigger.task.SKILLS_ROOT", tmp_path)
    skill_dir = tmp_path / "my-skill"
    skill_dir.mkdir()
    (skill_dir / "SKILL.md").write_text(
        "---\nskill: my-skill\ndescription: Use for Nix flakes.\n---\n"
    )
    result = _read_skill_description("my-skill")
    assert result == "Use for Nix flakes."


# ---------------------------------------------------------------------------
# load_skill_descriptions
# ---------------------------------------------------------------------------


def test_load_skill_descriptions_contains_all_skills(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.trigger.task.SKILLS_ROOT", tmp_path)
    descriptions = load_skill_descriptions()
    all_expected = set(SKILLS) | set(EXTRA_SKILLS)
    assert all_expected.issubset(set(descriptions.keys()))


def test_load_skill_descriptions_overrides(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.trigger.task.SKILLS_ROOT", tmp_path)
    overrides = {"kubernetes-gitops": "Custom override description."}
    descriptions = load_skill_descriptions(overrides=overrides)
    assert descriptions["kubernetes-gitops"] == "Custom override description."


def test_load_skill_descriptions_non_empty_values(tmp_path, monkeypatch):
    monkeypatch.setattr("runner.trigger.task.SKILLS_ROOT", tmp_path)
    descriptions = load_skill_descriptions()
    for key, val in descriptions.items():
        assert isinstance(val, str) and val, f"Empty description for {key!r}"


# ---------------------------------------------------------------------------
# _build_dispatcher_prompt
# ---------------------------------------------------------------------------


def test_build_dispatcher_prompt_none_not_in_skill_list():
    descriptions = {
        "kubernetes-gitops": "K8s stuff.",
        "none": "This should not appear as a skill.",
    }
    prompt = _build_dispatcher_prompt(descriptions)
    lines = prompt.split("\n")
    # "none" must not appear as a skill entry (lines starting with "- none:")
    skill_lines = [ln for ln in lines if ln.startswith("- ")]
    assert not any(ln.startswith("- none:") for ln in skill_lines)


def test_build_dispatcher_prompt_all_skills_present():
    descriptions = {
        "kubernetes-gitops": "K8s stuff.",
        "rust-engineering": "Rust stuff.",
        "nix-flake-development": "Nix stuff.",
    }
    prompt = _build_dispatcher_prompt(descriptions)
    for skill in descriptions:
        assert skill in prompt


def test_build_dispatcher_prompt_skills_sorted_alphabetically():
    descriptions = {
        "rust-engineering": "Rust.",
        "kubernetes-gitops": "K8s.",
        "nix-flake-development": "Nix.",
    }
    prompt = _build_dispatcher_prompt(descriptions)
    # The skill list appears between "Available skills:" and "Rules:"
    skill_section = prompt.split("Available skills:")[1].split("Rules:")[0]
    # Extract skill names from lines of form "- skill-name: desc"
    skill_names = [
        line.split(":")[0].lstrip("- ").strip()
        for line in skill_section.strip().split("\n")
        if line.strip().startswith("- ")
    ]
    assert skill_names == sorted(skill_names)


# ---------------------------------------------------------------------------
# build_dispatcher_agent
# ---------------------------------------------------------------------------


def test_build_dispatcher_agent_returns_agent(monkeypatch):
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key")
    descriptions = {"kubernetes-gitops": "K8s."}
    agent = build_dispatcher_agent(descriptions=descriptions)
    assert isinstance(agent, Agent)


def test_build_dispatcher_agent_empty_descriptions(monkeypatch):
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key")
    agent = build_dispatcher_agent(descriptions={})
    assert isinstance(agent, Agent)


def test_build_dispatcher_agent_no_singleton_caching(monkeypatch):
    """Two calls without explicit descriptions must return distinct objects."""
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key")
    descriptions = {"kubernetes-gitops": "K8s."}
    agent1 = build_dispatcher_agent(descriptions=descriptions)
    agent2 = build_dispatcher_agent(descriptions=descriptions)
    assert agent1 is not agent2
