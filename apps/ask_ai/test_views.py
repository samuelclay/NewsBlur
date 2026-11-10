from types import SimpleNamespace
from unittest.mock import patch

from django.test import RequestFactory, SimpleTestCase
from django.utils import translation

from apps.ask_ai.views import MAX_CUSTOM_QUESTION_LENGTH, ask_ai_question
from utils import json_functions as json


class Test_AskAIValidation(SimpleTestCase):
    @patch("apps.ask_ai.views.AskAIQuestion.apply_async")
    @patch("apps.ask_ai.views.MStory.find_story", return_value=(object(), True))
    @patch("apps.ask_ai.views.AskAIUsageTracker")
    def test_oversized_custom_question_returns_localized_validation_error(self, tracker, story, enqueue):
        tracker.return_value.can_use.return_value = (True, None)
        messages = []
        for language in ("en", "es"):
            request = RequestFactory().post(
                "/ask-ai/question",
                {
                    "story_hash": "123:abc",
                    "question_id": "custom",
                    "custom_question": "x" * (MAX_CUSTOM_QUESTION_LENGTH + 1),
                },
            )
            request.user = SimpleNamespace(pk=1, is_anonymous=False, is_authenticated=True)
            with translation.override(language):
                response = ask_ai_question(request)
            self.assertEqual(response.status_code, 200)
            payload = json.decode(response.content)
            self.assertEqual(payload["code"], -1)
            self.assertIn(str(MAX_CUSTOM_QUESTION_LENGTH), payload["message"])
            messages.append(payload["message"])
        self.assertNotEqual(messages[0], messages[1])
        enqueue.assert_not_called()
