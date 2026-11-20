"""Tests for natural language text and image filters answered by Jev (apps/analyzer/jev.py)."""

import base64
import datetime
import io
import uuid
from contextlib import contextmanager
from unittest.mock import MagicMock, patch

import redis
from django.conf import settings
from django.contrib.auth.models import User
from django.test import TransactionTestCase, override_settings
from django.test.client import Client
from PIL import Image

from apps.analyzer import jev
from apps.analyzer.models import MClassifierPrompt
from apps.analyzer.views import TEST_PROMPT_DAILY_LIMIT, _test_prompt_count_key
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed, MStory


class FakeJev:
    """Stands in for OpenRouter's Decisions endpoint.

    apps/analyzer/test_jev.py: `probability` answers every question, or is called with a
    question's instructions. `status_code` fails every request. `drop_answers` leaves
    answers out of the response, the way a malformed reply would. Each request's JSON
    body is kept in `requests`.
    """

    def __init__(self, probability=0.95, status_code=200, drop_answers=False):
        self.probability = probability
        self.status_code = status_code
        self.drop_answers = drop_answers
        self.requests = []

    def post(self, url, headers=None, json=None, timeout=None):
        self.requests.append(json)
        response = MagicMock()
        response.status_code = self.status_code
        response.text = "upstream error"
        answers = {}
        if not self.drop_answers:
            for question_id, question in json["questions"].items():
                probability = self.probability
                if callable(probability):
                    probability = probability(question["instructions"])
                answers[question_id] = {"type": "noul", "noul": probability}
        response.json.return_value = {
            "answers": answers,
            "usage": {"input_tokens": 500, "output_tokens": 12, "cost": 0.000021},
        }
        return response

    @property
    def instructions(self):
        return [q["instructions"] for request in self.requests for q in request["questions"].values()]


@contextmanager
def fake_jev(describe=None, **kwargs):
    """Route Jev requests to a FakeJev.

    Filters are described as written unless `describe` maps filter text to a description,
    so a description cached in the shared dev Redis can't leak into a test.
    """
    api = FakeJev(**kwargs)
    descriptions = describe or {}
    # test_jev.py: Cost records go to the shared analytics Mongo, not the test database.
    with override_settings(OPENROUTER_API_KEY="test-openrouter-key"), patch(
        "apps.analyzer.jev.requests.post", side_effect=api.post
    ), patch("apps.analyzer.jev.time.sleep"), patch("apps.analyzer.jev.LLMCostTracker.record_usage"), patch(
        "apps.analyzer.jev.describe_filter",
        side_effect=lambda text, *args, **kwargs: descriptions.get(text, text),
    ):
        yield api


def png_bytes(width, height, mode="RGB"):
    buffer = io.BytesIO()
    Image.new(mode, (width, height)).save(buffer, "PNG")
    return buffer.getvalue()


def image_response(data):
    response = MagicMock()
    response.headers = {"Content-Length": str(len(data))}
    response.iter_content.return_value = [data]
    response.raise_for_status.return_value = None
    return response


IMAGE_PART = {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,AAAA"}}


class Test_JevPromptClassification(TransactionTestCase):
    """MClassifierPrompt.classify_stories (apps/analyzer/models.py) through Jev."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
        "apps/rss_feeds/fixtures/rss_feeds.json",
    ]

    def setUp(self):
        self.user = User.objects.create_user(username="jevuser", password="testpass", email="jev@test.com")
        self.user.profile.is_archive = True
        self.user.profile.save()
        self.feed = Feed.objects.get(pk=1)
        UserSubscription.objects.create(user=self.user, feed=self.feed, is_trained=True, active=True)
        self.stories = [
            {
                "story_hash": "%s:jev%d" % (self.feed.pk, i),
                "story_feed_id": self.feed.pk,
                "story_title": title,
                "story_content": "<p>%s</p>" % body,
                "image_urls": [],
            }
            for i, (title, body) in enumerate(
                [
                    ("Dodgers edge the Pirates 5-4 in the 10th", "A walk-off single in a baseball game."),
                    ("Rust 2.0 ships a new borrow checker", "Release notes for a programming language."),
                ]
            )
        ]

    def tearDown(self):
        for prompt in MClassifierPrompt.objects(user_id=self.user.pk):
            MClassifierPrompt.invalidate_cache(self.user.pk, str(prompt.id), feed_ids=[self.feed.pk])
        MClassifierPrompt.objects(user_id=self.user.pk).delete()

    def add_prompt(self, prompt, classifier_type="focus", include_images=False):
        return MClassifierPrompt.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            prompt=prompt,
            classifier_type=classifier_type,
            include_images=include_images,
        )

    def cached(self, prompt):
        return MClassifierPrompt.get_cached_scores(
            self.user.pk, str(prompt.id), self.feed.pk, [s["story_hash"] for s in self.stories]
        )

    def test_a_hidden_match_hides_and_a_focus_match_focuses(self):
        """The direction comes from classifier_type. "sports" is a valid focus filter and a
        valid hidden filter, and the reader only honors -1 from a hidden one."""
        from apps.reader.views import get_prompt_scores_or_queue

        hidden = self.add_prompt("sports", "hidden")
        with fake_jev(probability=lambda q: 0.95 if "s0" in q else 0.02):
            MClassifierPrompt.classify_stories(self.user.pk, self.stories)
        self.assertEqual(
            self.cached(hidden), {self.stories[0]["story_hash"]: -1, self.stories[1]["story_hash"]: 0}
        )
        scores = get_prompt_scores_or_queue(self.user, self.stories, [self.feed.pk])["scores"]
        self.assertEqual(scores, {self.stories[0]["story_hash"]: -1})

        hidden.delete()
        focus = self.add_prompt("sports", "focus")
        with fake_jev(probability=lambda q: 0.95 if "s0" in q else 0.02):
            MClassifierPrompt.classify_stories(self.user.pk, self.stories)
        self.assertEqual(self.cached(focus)[self.stories[0]["story_hash"]], 1)

    def test_a_low_probability_is_a_cached_non_match(self):
        """Jev answers with a probability, never a 0. A confident "no" must be cached as a
        non-match so the story isn't asked about again, not read as truthy."""
        prompt = self.add_prompt("sports", "hidden")
        with fake_jev(probability=0.08) as api:
            result = MClassifierPrompt.classify_stories(self.user.pk, self.stories)
        self.assertEqual(set(result.values()), {0})
        self.assertEqual(self.cached(prompt), {s["story_hash"]: 0 for s in self.stories})

        with fake_jev() as api:
            MClassifierPrompt.classify_stories(self.user.pk, self.stories)
        self.assertEqual(api.requests, [], "Cached verdicts must not be asked about again")

    def test_every_filter_is_asked_about_every_story_in_one_request(self):
        """Jev reads the stories once and charges about 20 tokens per extra question, so
        a reader's filters share one request instead of one request each."""
        for prompt in ("sports", "programming languages", "politics"):
            self.add_prompt(prompt, "hidden")
        with fake_jev(probability=0.02) as api:
            MClassifierPrompt.classify_stories(self.user.pk, self.stories)
        self.assertEqual(len(api.requests), 1)
        self.assertEqual(len(api.requests[0]["questions"]), 6)
        self.assertEqual(len(api.requests[0]["state"]["stories"]), 2)

    def test_jev_is_asked_about_the_description_not_the_typed_filter(self):
        """Jev answers the literal question. Asked whether a story is about "I don't want
        politics", it answers as if the reader wanted something else, so the question has
        to carry the neutral description."""
        self.add_prompt("I don't want politics or election coverage", "hidden")
        with fake_jev(
            probability=0.02, describe={"I don't want politics or election coverage": "politics"}
        ) as api:
            MClassifierPrompt.classify_stories(self.user.pk, self.stories)
        self.assertTrue(api.instructions)
        for instructions in api.instructions:
            self.assertIn("about this: politics?", instructions)
            self.assertNotIn("don't want", instructions)

    def test_image_filters_get_their_own_requests(self):
        """Every request with an image runs in Jev's slower, less accurate long-context mode,
        so text filters must never share a request with an image filter."""
        self.add_prompt("sports", "hidden")
        image_prompt = self.add_prompt("photos of food", "focus", include_images=True)
        self.stories[0]["image_urls"] = ["https://example.com/plate.jpg"]
        with fake_jev(probability=0.9) as api, patch(
            "apps.analyzer.jev.fetch_image", return_value=IMAGE_PART
        ):
            MClassifierPrompt.classify_stories(self.user.pk, self.stories)

        self.assertEqual(len(api.requests), 2)
        text_request, image_request = api.requests
        self.assertNotIn("image_url", str(text_request["state"]))
        self.assertIn("image_url", str(image_request["state"]))
        self.assertTrue(
            all("photos of food" in q["instructions"] for q in image_request["questions"].values())
        )
        # The story without images is a known non-match, cached without asking Jev.
        self.assertEqual(
            self.cached(image_prompt),
            {self.stories[0]["story_hash"]: 1, self.stories[1]["story_hash"]: 0},
        )

    def test_a_failed_request_leaves_its_stories_uncached(self):
        """A transient failure must not be cached as "not a match", which would stick for
        the full TTL. The next fetch retries the stories instead."""
        prompt = self.add_prompt("sports", "hidden")
        with fake_jev(status_code=503) as api:
            result = MClassifierPrompt.classify_stories(self.user.pk, self.stories)
        self.assertEqual(len(api.requests), 2, "A 503 is retried once")
        self.assertEqual(set(result.values()), {0})
        self.assertEqual(self.cached(prompt), {})

        with fake_jev(drop_answers=True):
            MClassifierPrompt.classify_stories(self.user.pk, self.stories)
        self.assertEqual(self.cached(prompt), {}, "A reply missing answers is a failure too")

    def test_filters_dont_run_without_premium_archive(self):
        """Anyone can save AI filters, but they only score stories on Premium Archive."""
        self.add_prompt("sports", "hidden")
        self.user.profile.is_archive = False
        self.user.profile.save()

        with fake_jev() as api:
            result = MClassifierPrompt.classify_stories(self.user.pk, self.stories)
        self.assertEqual(result, {})
        self.assertEqual(api.requests, [])
        self.assertNotIn(self.user.pk, MClassifierPrompt.feed_has_prompt_subscribers(self.feed.pk))

        self.user.profile.is_archive = True
        self.user.profile.save()
        self.assertIn(self.user.pk, MClassifierPrompt.feed_has_prompt_subscribers(self.feed.pk))


class Test_JevImages(TransactionTestCase):
    """apps/analyzer/jev.py fetch_image: Jev rejects a whole request over one image outside
    256 to 1,568 pixels per side or under 78,400 pixels, so every image is fitted first."""

    def fetch(self, data):
        with patch("apps.analyzer.jev.requests.get", return_value=image_response(data)):
            part = jev.fetch_image("https://example.com/image.png")
        if part is None:
            return None
        encoded = part["image_url"]["url"].split(",", 1)[1]
        return Image.open(io.BytesIO(base64.b64decode(encoded)))

    def assert_jev_accepts(self, image):
        self.assertEqual(image.format, "JPEG")
        self.assertTrue(256 <= min(image.size) and max(image.size) <= 1568, image.size)
        self.assertGreaterEqual(image.size[0] * image.size[1], 78400, image.size)

    def test_large_and_small_pictures_are_fitted(self):
        for size in ((4000, 3000), (3000, 4000), (200, 150), (180, 600), (900, 600)):
            image = self.fetch(png_bytes(*size))
            self.assertIsNotNone(image, size)
            self.assert_jev_accepts(image)

    def test_transparent_images_become_jpeg(self):
        self.assert_jev_accepts(self.fetch(png_bytes(600, 400, mode="RGBA")))

    def test_icons_banners_and_junk_are_skipped(self):
        self.assertIsNone(self.fetch(png_bytes(32, 32)), "A tracking pixel or icon isn't a picture")
        self.assertIsNone(self.fetch(png_bytes(3000, 120)), "A thin banner can't fit Jev's limits")
        self.assertIsNone(self.fetch(b"<html>not an image</html>"))


class Test_JevDescribeFilter(TransactionTestCase):
    """apps/analyzer/jev.py describe_filter rewrites typed filters into neutral topics."""

    def response(self, description):
        block = MagicMock()
        block.type = "tool_use"
        block.name = "describe_filter"
        block.input = {"description": description}
        response = MagicMock()
        response.content = [block]
        response.usage.input_tokens = 690
        response.usage.output_tokens = 35
        return response

    def test_the_description_is_cached_and_failures_fall_back_to_the_text(self):
        text = "Hide anything about sports %s" % uuid.uuid4().hex
        with patch("apps.ask_ai.providers.AnthropicProvider.is_configured", return_value=True), patch(
            "apps.analyzer.jev.anthropic.Anthropic"
        ) as MockAnthropic, patch("apps.analyzer.jev.LLMCostTracker.record_usage"):
            create = MockAnthropic.return_value.messages.create
            create.side_effect = jev.anthropic.APIConnectionError(request=MagicMock())
            self.assertEqual(jev.describe_filter(text, "hidden"), text)

            create.side_effect = None
            create.return_value = self.response("sports")
            self.assertEqual(jev.describe_filter(text, "hidden"), "sports")
            self.assertEqual(jev.describe_filter(text, "hidden"), "sports")
            self.assertEqual(create.call_count, 2, "The failure isn't cached, the description is")


class Test_TestPromptView(TransactionTestCase):
    """apps/analyzer/views.py test_prompt_classifier, "Test on this story" in the trainer."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
        "apps/rss_feeds/fixtures/rss_feeds.json",
    ]

    def setUp(self):
        self.client = Client()
        self.user = User.objects.create_user(username="jevtester", password="testpass", email="t@test.com")
        self.client.login(username="jevtester", password="testpass")
        self.story = MStory(
            story_feed_id=1,
            story_date=datetime.datetime(2026, 11, 19, 12, 0),
            story_title="Dodgers win the World Series",
            story_content="<p>Baseball.</p>",
            story_guid="jev-test-prompt-%s" % uuid.uuid4().hex,
            story_permalink="https://example.com/dodgers",
            image_urls=["https://example.com/a.jpg", "https://example.com/b.jpg"],
        )
        self.story.save()
        # test_jev.py: Test user ids repeat across runs in the shared dev Redis.
        self.redis = redis.Redis(connection_pool=settings.REDIS_POOL)
        self.redis.delete(_test_prompt_count_key(self.user))

    def tearDown(self):
        self.redis.delete(_test_prompt_count_key(self.user))
        self.story.delete()

    def post(self, **data):
        data.setdefault("story_hash", self.story.story_hash)
        data.setdefault("prompt", "sports")
        return self.client.post("/classifier/test_prompt", data).json()

    def test_a_free_account_can_test_a_filter(self):
        """Anyone can try a filter; only Archive accounts get it applied."""
        self.assertFalse(self.user.profile.is_archive)
        with fake_jev(probability=0.93, describe={"Hide anything about sports": "sports"}):
            result = self.post(prompt="Hide anything about sports", classifier_type="hidden")
        self.assertEqual(result["code"], 0)
        self.assertEqual(result["classification"], 1)
        self.assertEqual(result["description"], "sports")

    def test_each_image_gets_its_own_verdict(self):
        def by_image(instructions):
            return 0.9 if "story s0" in instructions else 0.05

        def fetch(url):
            return IMAGE_PART if url.endswith("a.jpg") else None

        with fake_jev(probability=by_image), patch("apps.analyzer.jev.fetch_image", side_effect=fetch):
            result = self.post(prompt="baseball players", include_images="true")
        self.assertEqual(result["code"], 0)
        # The second image couldn't be read, so it's a non-match rather than a failure.
        self.assertEqual(result["image_results"], [1, 0])
        self.assertEqual(result["classification"], 1)

    def test_a_failed_request_is_an_error_not_a_non_match(self):
        with fake_jev(status_code=500):
            result = self.post()
        self.assertEqual(result["code"], -1)

    def test_without_archive_a_reader_gets_ten_tests_a_day(self):
        """Readers without Premium Archive can try filters a few times a day. A failed test
        doesn't use one up, and the test past the limit never reaches Jev."""
        with fake_jev(status_code=500):
            for _ in range(3):
                self.assertEqual(self.post()["code"], -1)
        with fake_jev(probability=0.9) as api:
            for _ in range(TEST_PROMPT_DAILY_LIMIT):
                self.assertEqual(self.post()["code"], 0)
            requests_before = len(api.requests)
            refused = self.post()
        self.assertEqual(refused["code"], -1)
        self.assertTrue(refused["test_limit_reached"])
        self.assertEqual(len(api.requests), requests_before)

    def test_premium_archive_tests_arent_capped(self):
        self.user.profile.is_archive = True
        self.user.profile.save()
        with fake_jev(probability=0.9):
            results = [self.post()["code"] for _ in range(TEST_PROMPT_DAILY_LIMIT + 2)]
        self.assertEqual(set(results), {0})
