"""Central LLM model IDs for the web backend.

utils/llm_models.py is THE place to change model IDs when upgrading models on web.
Everything on the backend — the Ask AI and briefing registries in
apps/ask_ai/providers.py, story classifiers, discover commands, the archive
assistant, and web feed analysis — reads its model ID from here.

The iOS and Android clients keep their own single-file equivalents:
  - clients/ios/Classes/AskAI/AskAIModels.swift
  - clients/android/NewsBlur/app/src/main/java/com/newsblur/askai/AskAiModels.kt

When adding a new model here, also add its pricing to utils/llm_costs.py.
"""

# Cheap tier: used by story classification, discover, curation, and web feed
# analysis. Always the vendor's cheapest current model.
ANTHROPIC_MODEL = "claude-haiku-4-5"
ANTHROPIC_MODEL_DISPLAY = "Claude Haiku 4.5"

# Chat tier: user-facing conversations — Ask AI and the Daily Briefing — get a
# Sonnet-class model instead of the cheap tier so answers are worth reading.
ANTHROPIC_CHAT_MODEL = "claude-sonnet-5"
ANTHROPIC_CHAT_MODEL_DISPLAY = "Claude Sonnet 5"

OPENAI_MODEL = "gpt-5.6-luna"
OPENAI_MODEL_DISPLAY = "GPT-5.6 Luna"

GOOGLE_MODEL = "gemini-3.6-flash"
GOOGLE_MODEL_DISPLAY = "Gemini 3.6 Flash"

XAI_MODEL = "grok-4.6"
XAI_MODEL_DISPLAY = "Grok 4.6"

# Heavier tier: Archive Assistant runs long multi-tool searches over years of
# stories, so it keeps a Sonnet-class model instead of the cheap tier.
ANTHROPIC_ARCHIVE_MODEL = "claude-sonnet-5"
