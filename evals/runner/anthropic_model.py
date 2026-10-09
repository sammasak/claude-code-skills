"""Anthropic model factory honoring either credential the README names.

ANTHROPIC_API_KEY flows through pydantic-ai's default provider;
CLAUDE_CODE_OAUTH_TOKEN is a bearer token, which needs an explicit anthropic
client (auth_token) — the default x-api-key path rejects it.
"""

import os

HAIKU = "claude-haiku-4-5-20251001"


def anthropic_model(model_name: str = HAIKU):
    token = os.environ.get("CLAUDE_CODE_OAUTH_TOKEN")
    if os.environ.get("ANTHROPIC_API_KEY") or not token:
        return f"anthropic:{model_name}"
    from anthropic import AsyncAnthropic
    from pydantic_ai.models.anthropic import AnthropicModel
    from pydantic_ai.providers.anthropic import AnthropicProvider

    client = AsyncAnthropic(auth_token=token)
    return AnthropicModel(model_name, provider=AnthropicProvider(anthropic_client=client))
