"""AI-powered story summarization and question answering.

Supports multiple providers (Claude, GPT, Gemini, Grok). Responses are processed
asynchronously via Celery and cached with zlib compression in MongoDB.
"""

# Django 4.1+ automatically discovers app configs, no default_app_config needed
