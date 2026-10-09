"""Extract evaluable constraints from SKILL.md files."""

from __future__ import annotations

import re
from pathlib import Path

SKILLS_ROOT = Path(__file__).parent.parent.parent.parent / "skills"

# Patterns that indicate an explicit, evaluable constraint in the skill body
_PATTERNS = [
    r"\*\*CRITICAL\*\*:?\s+(.+)",       # **CRITICAL**: TEXT or **CRITICAL** TEXT
    r"\*\*CRITICAL:\s+(.+?)\*\*",        # **CRITICAL: TEXT**
    r"\*\*IMPORTANT\*\*:?\s+(.+)",       # **IMPORTANT**: TEXT or **IMPORTANT** TEXT
    r"\*\*IMPORTANT:\s+(.+?)\*\*",       # **IMPORTANT: TEXT**
    r"- \*\*Never\*\*\s+(.+)",           # - **Never** TEXT
    r"- \*\*Always\*\*\s+(.+)",          # - **Always** TEXT
    # Bullet items containing must/never/always/require in-sentence (not leading **Never**/**Always**)
    r"(?:^|\n)- (?!\*\*Never\*\*|\*\*Always\*\*)(.+(?:must|must not|never|always|require).+?)(?:\.|$)",
    # Bullet items where the keyword starts the sentence (e.g. "- must not exceed ...")
    r"(?:^|\n)- ((?:must not|must|never|always|require)\s+.{10,}?)(?:\.|$)",
]


def extract_constraints(skill: str) -> list[str]:
    """Extract evaluable rules from a SKILL.md body."""
    skill_md = SKILLS_ROOT / skill / "SKILL.md"
    if not skill_md.exists():
        return []
    content = skill_md.read_text()
    # Strip frontmatter
    if content.startswith("---"):
        end = content.find("---", 3)
        if end != -1:
            content = content[end + 3 :].strip()
    constraints = []
    for pattern in _PATTERNS:
        for match in re.finditer(pattern, content, re.MULTILINE | re.IGNORECASE):
            constraint = match.group(1).strip()
            if constraint and len(constraint) > 10:  # skip trivially short matches
                constraints.append(constraint)
    # Deduplicate while preserving order
    seen: set[str] = set()
    return [c for c in constraints if not (c in seen or seen.add(c))]
