Review this Claude Code session transcript and extract 0-3 atomic, reusable learnings.

A good learning is:
- Specific and actionable (not "be careful with X")
- Reusable in future sessions on similar tasks
- Not already obvious from documentation
- Grounded in something that actually happened in the transcript

Scope: {{SCOPE}}

Output a single JSON object (no markdown fences):
{
  "learnings": [
    {
      "title": "Short imperative title (max 8 words)",
      "content": "2-4 sentence explanation of the learning with concrete detail",
      "scope": "{{SCOPE}}",
      "confidence": 4,
      "keywords": ["keyword1", "keyword2"]
    }
  ]
}

If there are no clear learnings, output {"learnings": []}.
Confidence: 5=certain, 4=high, 3=moderate. Only include confidence >= 3.
