"""Shared utilities for solving eval runner."""

from __future__ import annotations

import re


def strip_code_fence(text: str) -> str:
    """Strip a single markdown code fence (```lang ... ```) from LLM output.

    Only the first code fence is extracted. If the output contains multiple
    fenced blocks, only the content of the first is returned. If no fence is
    found, the original text is returned unchanged.
    """
    match = re.search(r"```(?:\w+)?\n(.*?)```", text, re.DOTALL)
    return match.group(1).strip() if match else text
