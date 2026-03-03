"""AI-powered story summarization and question answering.

Supports multiple providers (Claude, GPT, Gemini, Grok). Responses are processed
asynchronously via Celery and cached with zlib compression in MongoDB.
"""

default_app_config = "apps.ask_ai.apps.AskAiConfig"
