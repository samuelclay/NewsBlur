"""
Data models for the Archive Assistant feature.

Stores conversation history, queries, and cached responses.
"""

import zlib
from datetime import datetime

import mongoengine as mongo


class MArchiveConversation(mongo.Document):
    """
    Stores a conversation session between user and Archive Assistant.
    Each conversation can have multiple queries/responses.
    """

    user_id = mongo.IntField(required=True)
    created_date = mongo.DateTimeField(default=datetime.now)
    last_activity = mongo.DateTimeField(default=datetime.now)
    title = mongo.StringField(max_length=256)  # Auto-generated from first query

    # Conversation state
    is_active = mongo.BooleanField(default=True)

    meta = {
        "collection": "archive_conversations",
        "indexes": [
            {"fields": ["user_id", "-last_activity"]},
            {"fields": ["user_id", "is_active", "-last_activity"]},
        ],
        "db_alias": "nbanalytics",
        "ordering": ["-last_activity"],
    }

    def __str__(self):
        return f"Conversation {self.id}: {self.title or 'Untitled'}"


class MArchiveQuery(mongo.Document):
    """
    Stores individual queries and responses within a conversation.
    """

    user_id = mongo.IntField(required=True)
    conversation_id = mongo.ObjectIdField(required=True)

    # Query details
    query_text = mongo.StringField(required=True, max_length=4096)
    query_date = mongo.DateTimeField(default=datetime.now)

    # Response (compressed)
    response_z = mongo.BinaryField()  # zlib-compressed response text
    response_date = mongo.DateTimeField()

    # Metadata
    model = mongo.StringField(max_length=64, default="claude-sonnet-4-5")
    duration_ms = mongo.IntField()  # Time to generate response
    tokens_used = mongo.IntField()

    # Archives referenced in the response
    referenced_archive_ids = mongo.ListField(mongo.ObjectIdField())

    # Tool calls made during response generation
    tool_calls = mongo.ListField(mongo.DictField())

    # Error tracking
    error = mongo.StringField()

    meta = {
        "collection": "archive_queries",
        "indexes": [
            {"fields": ["user_id", "-query_date"]},
            {"fields": ["conversation_id", "query_date"]},
        ],
        "db_alias": "nbanalytics",
        "ordering": ["query_date"],
    }

    def set_response(self, response_text):
        """Compress and store response."""
        if response_text:
            self.response_z = zlib.compress(response_text.encode("utf-8"))
            self.response_date = datetime.now()

    def get_response(self):
        """Decompress and return response."""
        if self.response_z:
            try:
                return zlib.decompress(self.response_z).decode("utf-8")
            except Exception:
                return ""
        return ""

    def __str__(self):
        return f"Query: {self.query_text[:50]}..."


class MArchiveAssistantUsage(mongo.Document):
    """
    Tracks usage of the Archive Assistant for rate limiting and analytics.
    Similar to MAskAIUsage in ask_ai app.
    """

    user_id = mongo.IntField(required=True)
    query_date = mongo.DateTimeField(default=datetime.now)
    model = mongo.StringField(max_length=64)
    tokens_used = mongo.IntField(default=0)
    source = mongo.StringField(choices=["live", "cache", "denied"], default="live")

    meta = {
        "collection": "archive_assistant_usage",
        "indexes": [
            {"fields": ["user_id", "-query_date"]},
            {"fields": ["user_id", "source", "-query_date"]},
        ],
        "db_alias": "nbanalytics",
    }

    @classmethod
    def can_use(cls, user):
        """
        Check if user can make an Archive Assistant query.
        All users can query, but non-premium users have a lower daily limit
        and get truncated responses.
        """
        from apps.profile.models import Profile

        profile = Profile.objects.get(user=user)

        # Different daily limits based on subscription
        # Premium archive: 100 queries/day, Non-premium: 20 queries/day
        daily_limit = 100 if profile.is_archive else 20

        today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        today_count = cls.objects(
            user_id=user.pk, query_date__gte=today_start, source__in=["live", "cache"]
        ).count()

        if today_count >= daily_limit:
            return False, f"Daily query limit reached ({daily_limit} queries per day)"

        return True, None

    @classmethod
    def record_usage(cls, user_id, model, tokens_used=0, source="live"):
        """Record a query for usage tracking."""
        usage = cls(user_id=user_id, model=model, tokens_used=tokens_used, source=source)
        usage.save()
        return usage
