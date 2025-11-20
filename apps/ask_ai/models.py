import datetime
import zlib

import mongoengine as mongo
import pytz
from django.utils.encoding import smart_bytes, smart_str


class MAskAIResponse(mongo.Document):
    """Cache of Ask AI responses for stories."""

    user_id = mongo.IntField()
    story_hash = mongo.StringField(max_length=32)
    question_id = mongo.StringField(max_length=64)
    custom_question = mongo.StringField()
    response_z = mongo.BinaryField()
    response_metadata = mongo.DictField()
    created_at = mongo.DateTimeField(default=datetime.datetime.now)

    meta = {
        "collection": "ask_ai_responses",
        "indexes": [
            {
                "fields": ["user_id", "story_hash", "question_id"],
                "unique": False,
            },
        ],
        "allow_inheritance": False,
    }

    def save(self, *args, **kwargs):
        """Compress response before saving."""
        if hasattr(self, "_response_text") and self._response_text:
            self.response_z = zlib.compress(smart_bytes(self._response_text))
        super(MAskAIResponse, self).save(*args, **kwargs)

    @property
    def response_text(self):
        """Decompress and return response text."""
        if self.response_z:
            return smart_str(zlib.decompress(self.response_z))
        return ""

    @response_text.setter
    def response_text(self, value):
        """Store text for compression on save."""
        self._response_text = value

    @classmethod
    def get_cached_response(cls, user_id, story_hash, question_id, custom_question=None):
        """
        Get cached response for a story and question.

        Args:
            user_id: User ID
            story_hash: Story hash
            question_id: Question ID (e.g., "sentence", "bullets")
            custom_question: Optional custom question text

        Returns:
            MAskAIResponse instance or None
        """
        query = {
            "user_id": user_id,
            "story_hash": story_hash,
            "question_id": question_id,
        }

        if custom_question:
            query["custom_question"] = custom_question

        try:
            return cls.objects(**query).order_by("-created_at").first()
        except cls.DoesNotExist:
            return None

    @classmethod
    def create_response(
        cls, user_id, story_hash, question_id, response_text, custom_question=None, metadata=None
    ):
        """
        Create a new Ask AI response.

        Args:
            user_id: User ID
            story_hash: Story hash
            question_id: Question ID
            response_text: Full response text from AI
            custom_question: Optional custom question
            metadata: Optional metadata dict (tokens, model, etc.)

        Returns:
            MAskAIResponse instance
        """
        response = cls(
            user_id=user_id,
            story_hash=story_hash,
            question_id=question_id,
            custom_question=custom_question or "",
            response_metadata=metadata or {},
        )
        response.response_text = response_text
        response.save()
        return response


class MAskAIUsage(mongo.Document):
    """
    History of Ask AI usage per request.

    Tracks each question asked for rate limiting and analytics.
    Use AskAIUsageTracker class for rate limiting logic.
    """

    user_id = mongo.IntField(required=True)
    question_id = mongo.StringField()
    story_hash = mongo.StringField()
    request_id = mongo.StringField()
    plan_tier = mongo.StringField()  # free, premium, archive, pro
    source = mongo.StringField(default="live")  # live or cache
    created_at = mongo.DateTimeField(default=datetime.datetime.utcnow)

    meta = {
        "collection": "ask_ai_usage",
        "indexes": [
            {"fields": ["user_id", "-created_at"]},
        ],
        "allow_inheritance": False,
    }
