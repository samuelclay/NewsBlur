"""
MongoDB models for the Monitor app.

Stores LLM cost tracking data for all AI features.
"""

from datetime import datetime

import mongoengine as mongo


class MLLMCost(mongo.Document):
    """
    Centralized LLM cost tracking for all AI features.

    Records every LLM API call with token counts and calculated costs.
    Used for cost monitoring, budgeting, and analytics.
    """

    user_id = mongo.IntField()  # Optional - some features may be system-level
    timestamp = mongo.DateTimeField(default=datetime.utcnow, required=True)

    # Provider/Model identification
    provider = mongo.StringField(required=True)  # anthropic, openai, google, xai
    model = mongo.StringField(required=True)  # claude-sonnet-4-5, gpt-5.2, etc.

    # Feature identification
    feature = mongo.StringField(required=True)  # archive_assistant, ask_ai, story_classification, transcription

    # Token counts
    input_tokens = mongo.IntField(default=0)
    output_tokens = mongo.IntField(default=0)
    total_tokens = mongo.IntField(default=0)

    # Cost (USD)
    cost_usd = mongo.FloatField(default=0.0)

    # Request metadata
    request_id = mongo.StringField()  # For correlation
    metadata = mongo.DictField()  # Extra context (question_type, tool_calls, etc.)

    meta = {
        "collection": "llm_costs",
        "indexes": [
            {"fields": ["-timestamp"]},
            {"fields": ["provider", "-timestamp"]},
            {"fields": ["feature", "-timestamp"]},
            {"fields": ["model", "-timestamp"]},
            {"fields": ["user_id", "-timestamp"]},
        ],
        "db_alias": "nbanalytics",
    }

    def __str__(self):
        return f"LLMCost({self.feature}/{self.model}: ${self.cost_usd:.4f})"

    @classmethod
    def get_cost_summary(cls, feature=None, provider=None, model=None, days=1):
        """
        Get aggregated cost summary for the specified period.

        Args:
            feature: Filter by feature name (optional)
            provider: Filter by provider (optional)
            model: Filter by model (optional)
            days: Number of days to look back (default: 1)

        Returns:
            Dict with total_cost, total_tokens, request_count
        """
        from datetime import timedelta

        start_time = datetime.utcnow() - timedelta(days=days)

        query = {"timestamp__gte": start_time}
        if feature:
            query["feature"] = feature
        if provider:
            query["provider"] = provider
        if model:
            query["model"] = model

        costs = cls.objects(**query)

        total_cost = sum(c.cost_usd for c in costs)
        total_tokens = sum(c.total_tokens for c in costs)
        request_count = costs.count()

        return {
            "total_cost": total_cost,
            "total_tokens": total_tokens,
            "request_count": request_count,
            "period_days": days,
        }
