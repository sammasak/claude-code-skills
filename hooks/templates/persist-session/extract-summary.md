Summarise this Claude Code session into a structured record.

Context:
- Topic/rooms: {{TOPIC}}
- Repos touched: {{REPOS_TOUCHED}}
- Tools used: {{TOOLS_USED}}
- Errors seen: {{ERRORS_SEEN}}
- Goal status: {{GOAL_STATUS}}

Git activity and transcript follow.

Output a single JSON object (no markdown fences) with these fields:
{
  "goal": "one-sentence description of what was attempted",
  "outcome": "one-sentence result — what was achieved or why it failed",
  "project": "project name (repo or topic area, e.g. homelab, claude-code-skills)",
  "key_findings": ["finding 1", "finding 2"],
  "decisions_made": ["decision 1"],
  "what_worked": ["approach that succeeded"],
  "what_didnt_work": ["approach that failed"],
  "not_tried": ["promising alternative not yet attempted"],
  "slug": "kebab-case-slug-max-40-chars"
}
