import datetime
import json
import zlib
from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import SimpleTestCase, TestCase
from django.test.client import Client

from apps.listen.language import detect_language
from apps.listen.models import MListenUsage
from apps.listen.text import (
    build_paragraphs,
    build_segments,
    characters_per_second,
    extract_paragraphs,
    truncate_segments,
)
from apps.listen.usage import (
    ARCHIVE_WEEKLY_SECONDS,
    PRO_WEEKLY_SECONDS,
    SAMPLE_STORIES_PER_DAY,
    ListenUsageTracker,
)
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed, MStarredStory, MStory
from apps.social.models import MSharedStory, MSocialProfile
from utils.llm_costs import LLMCostTracker

USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ListenTests"


class Test_ListenText(SimpleTestCase):
    def test_reads_blocks_in_order_and_skips_code_figures_and_tables(self):
        html = """
        <div><h2>Overview</h2><p>First <b>bold</b> paragraph.</p>
        <figure><img src="a.png"><figcaption>Caption text</figcaption></figure>
        <pre>print("code")</pre><table><tr><td>cell</td></tr></table>
        <ul><li>Item one</li><li>Item two</li></ul>
        <blockquote><p>Quoted words.</p></blockquote>Loose trailing text</div>
        """
        paragraphs = extract_paragraphs(html)
        self.assertEqual(
            [(paragraph["kind"], paragraph["text"]) for paragraph in paragraphs],
            [
                ("heading", "Overview"),
                ("text", "First bold paragraph."),
                ("list", "Item one"),
                ("list", "Item two"),
                ("quote", "Quoted words."),
                ("text", "Loose trailing text"),
            ],
        )

    def test_image_captions_credits_and_galleries_are_not_read(self):
        html = """
        <p>The review starts here.</p>
        <div class="ars-gallery"><div class="pswp-caption-content"><p>A demure scene.</p>
        <p class="ars-gallery-caption-credit">Prime Video</p></div>
        <div class="ars-gallery-caption"><p class="ars-gallery-caption-content">A demure scene. Prime Video</p></div></div>
        <div class="wp-caption-text">Photo: Someone</div>
        <p aria-hidden="true">Hidden decoration</p>
        <p>The review continues.</p>
        """
        self.assertEqual(
            [paragraph["text"] for paragraph in extract_paragraphs(html)],
            ["The review starts here.", "The review continues."],
        )

    def test_an_article_wrapped_in_a_gallery_class_is_still_read(self):
        body = "".join(
            f"<p>Paragraph {n} of a long article with plenty of words in it.</p>" for n in range(30)
        )
        paragraphs = extract_paragraphs(f'<div class="entry-content has-gallery">{body}</div>')
        self.assertEqual(len(paragraphs), 30)

    def test_title_comes_first_and_a_repeated_title_in_the_body_is_dropped(self):
        paragraphs = build_paragraphs("Big News", "<h1>Big News</h1><p>The body.</p>")
        self.assertEqual([paragraph["text"] for paragraph in paragraphs], ["Big News", "The body."])
        self.assertEqual(paragraphs[0]["kind"], "title")

    def test_a_headline_repeated_after_a_byline_is_cut_and_the_excerpt_is_kept(self):
        # Techmeme: the title ends with "(Author/Source)" and the body opens "Author / Source : Headline — excerpt".
        title = (
            "Sources: Meta built a prototype humanoid robot with Chinese firm Fourier in three months "
            "(Jyoti Mann/The Information)"
        )
        html = (
            "<p>Jyoti Mann / The Information : Sources: Meta built a prototype humanoid robot with Chinese "
            "firm Fourier in three months \u2014 Meta Platforms has built a prototype humanoid with Fourier.</p>"
        )
        paragraphs = build_paragraphs(title, html)
        # The full text stays so the clients can match the rendered paragraph; the voice reads the remainder.
        self.assertEqual(len(paragraphs), 2)
        self.assertTrue(paragraphs[1]["text"].startswith("Jyoti Mann / The Information : Sources: Meta"))
        self.assertEqual(
            paragraphs[1]["spoken"], "Meta Platforms has built a prototype humanoid with Fourier."
        )
        segments = build_segments(paragraphs)
        self.assertEqual(segments[1]["text"], "Meta Platforms has built a prototype humanoid with Fourier.")

    def test_a_headline_repeated_with_different_quotes_and_punctuation_is_still_dropped(self):
        title = 'How AI detectors are changing writing: authors drop "delve", or add typos (Morgan Meaker/Bloomberg)'
        html = "<p>Morgan Meaker / Bloomberg : How AI detectors are changing writing: authors drop \u201cdelve\u201d, or add typos</p><p>As AI transforms writing.</p>"
        paragraphs = build_paragraphs(title, html)
        self.assertEqual(
            [paragraph["text"] for paragraph in paragraphs], [title, "As AI transforms writing."]
        )

    def test_a_first_sentence_that_repeats_the_title_reads_only_the_rest(self):
        paragraphs = build_paragraphs(
            "Big News Arrives Today", "<p>Big News Arrives Today. The body continues.</p>"
        )
        self.assertEqual(paragraphs[1]["text"], "Big News Arrives Today. The body continues.")
        self.assertEqual(paragraphs[1]["spoken"], "The body continues.")

    def test_a_short_title_inside_a_longer_first_sentence_is_left_alone(self):
        paragraphs = build_paragraphs("Update", "<p>Update your drivers before the weekend.</p>")
        self.assertEqual(
            [paragraph["text"] for paragraph in paragraphs],
            ["Update", "Update your drivers before the weekend."],
        )
        self.assertNotIn("spoken", paragraphs[1])

    def test_a_title_repeated_after_a_short_byline_paragraph_is_dropped(self):
        html = "<p>By Jane Doe</p><p>Big News Arrives Today</p><p>The body.</p>"
        paragraphs = build_paragraphs("Big News Arrives Today", html)
        self.assertEqual(
            [paragraph["text"] for paragraph in paragraphs],
            ["Big News Arrives Today", "By Jane Doe", "The body."],
        )

    def test_segments_start_with_the_title_merge_short_paragraphs_and_split_long_ones(self):
        long_paragraph = " ".join(f"Sentence number {n} has a few words in it." for n in range(40))
        html = f"<h2>Short heading</h2><p>Short lead.</p><p>{long_paragraph}</p>"
        segments = build_segments(build_paragraphs("Title", html), title_suffix="From Feed.")
        self.assertEqual(segments[0]["text"], "Title. From Feed.")
        self.assertEqual(segments[0]["paragraphs"], [0])
        self.assertEqual(segments[1]["paragraphs"], [1, 2])
        long_segments = [segment for segment in segments if segment["paragraphs"] == [3]]
        self.assertGreater(len(long_segments), 1)
        self.assertTrue(all(len(segment["text"]) <= 700 for segment in long_segments))
        self.assertEqual(segments[1]["previous_text"], "Title. From Feed.")
        self.assertEqual(segments[-1]["next_text"], "")

    def test_preview_keeps_about_thirty_seconds_of_text(self):
        html = "".join(f"<p>{'Words and more words. ' * 20}</p>" for _ in range(10))
        segments = build_segments(build_paragraphs("Title", html))
        kept = truncate_segments(segments, 30, "en")
        spoken = sum(len(segment["text"]) for segment in kept)
        self.assertLessEqual(spoken, 30 * characters_per_second("en"))
        self.assertGreater(spoken, 20 * characters_per_second("en"))
        self.assertLess(len(kept), len(segments))


class Test_ListenLanguage(SimpleTestCase):
    def test_detects_our_languages(self):
        samples = {
            "en": "The council said that it would vote on the plan this week, and the mayor was in favor of it.",
            "fr": "Le conseil a dit que le plan est prêt et que les habitants de la ville sont pour le projet.",
            "de": "Der Rat sagte, dass der Plan in dieser Woche mit den Bürgern und der Stadt besprochen wird.",
            "es": "El consejo dijo que la ciudad votará el plan esta semana y que los vecinos están de acuerdo.",
            "ja": "市議会は今週、駐車場を住宅に転換する計画について投票すると発表しました。",
            "zh-Hans": "市议会说这个计划会在本周投票，们认为这对城市的发展问题很重要，经济也会变好。",
            "zh-Hant": "市議會說這個計劃會在本週投票，們認為這對城市的發展問題很重要，經濟也會變好。",
            "ru": "Совет заявил, что на этой неделе проголосует за план, и мэр поддержал это решение.",
            "uk": "Рада заявила, що цього тижня проголосує за план, і міський голова підтримав це рішення її.",
            "he": "מועצת העיר הודיעה שהיא תצביע השבוע על התוכנית להפוך חניונים לדיור בר השגה.",
            "ar": "قال المجلس إنه سيصوت هذا الأسبوع على خطة تحويل مواقف السيارات إلى مساكن.",
            "th": "สภาเมืองประกาศว่าจะลงมติในสัปดาห์นี้เกี่ยวกับแผนการเปลี่ยนที่จอดรถเป็นที่อยู่อาศัย",
            "ko": "시의회는 이번 주에 주차장을 주택으로 바꾸는 계획에 대해 투표할 것이라고 밝혔다.",
            "vi": "Hội đồng thành phố cho biết sẽ bỏ phiếu trong tuần này về kế hoạch chuyển bãi đỗ xe thành nhà ở.",
        }
        for language, text in samples.items():
            with self.subTest(language=language):
                self.assertEqual(detect_language(text), language)

    def test_letters_vietnamese_shares_with_other_languages_are_not_vietnamese(self):
        samples = [
            (
                "fr",
                "La tempête a frappé la forêt près du théâtre. "
                "Même les fenêtres de l'hôpital ont été endommagées.",
            ),
            (
                "pt-BR",
                "Você também pôde ver o ônibus na avenida, e o avô disse que a lâmpada da câmera "
                "não está pronta para o português.",
            ),
            # Romanian isn't one of our languages, so it falls back to the account's language instead.
            (
                None,
                "Guvernul a anunțat că va investi în infrastructură. Președintele a declarat că această "
                "hotărâre este importantă pentru țară și pentru cetățeni în următoarea perioadă.",
            ),
        ]
        for language, text in samples:
            with self.subTest(language=language):
                self.assertEqual(detect_language(text), language)

    def test_vietnamese_names_in_an_english_story_stay_english(self):
        text = (
            "Nguyễn Phú Trọng visited Hồ Chí Minh City on Monday, and officials in Hà Nội said that "
            "the Việt Nam trade plan was in good shape for the year."
        )
        self.assertEqual(detect_language(text), "en")

    def test_too_little_text_is_undetermined(self):
        self.assertIsNone(detect_language("OK"))


class Test_ListenCosts(SimpleTestCase):
    def test_speech_is_priced_per_character(self):
        self.assertAlmostEqual(LLMCostTracker.calculate_cost("eleven_v4_turbo", characters=10000), 0.40)


class ListenTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user("listener", "listener@example.com", "password")
        self.client = Client(HTTP_USER_AGENT=USER_AGENT)
        self.client.login(username="listener", password="password")
        # A public feed: anyone may read its stories without subscribing (load_single_feed, apps/reader/views.py).
        self.feed = Feed.objects.create(
            pk=900,
            feed_address="https://city.example/feed.xml",
            feed_link="https://city.example",
            feed_title="City Desk",
            num_subscribers=20,
        )
        MListenUsage.drop_collection()
        MStory.drop_collection()
        self.clear_redis()

    def pubsub_redis(self):
        import redis
        from django.conf import settings

        return redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)

    def clear_redis(self, user=None):
        """Listen keeps per-user state in the shared pubsub Redis, and test users reuse ids across runs."""
        user = user or self.user
        r = self.pubsub_redis()
        for pattern in ("charged", "recorded", "manifests"):
            for key in r.scan_iter(f"listen:{pattern}:{user.pk}:*"):
                r.delete(key)
        r.delete(f"listen:segment_lock:{user.pk}", "listen:library_blocked")

    def mark_cached(self, manifest):
        """Stands in for the node stream server (node/listen.coffee) having uploaded every segment to S3."""
        r = self.pubsub_redis()
        for segment in manifest["segments"]:
            marker = f"listen:cached:{segment['cache_key']}"
            r.set(marker, json.dumps({"duration": 4.0, "bytes": 32000}))
            self.addCleanup(r.delete, marker)

    def set_tier(self, premium=False, archive=False, pro=False, user=None):
        profile = (user or self.user).profile
        profile.is_premium = premium
        profile.is_archive = archive
        profile.is_pro = pro
        profile.save()

    def story_body(self, paragraphs=12):
        return "".join(
            f"<p>Paragraph {n} talks about the city council and the housing plan in some detail.</p>"
            for n in range(paragraphs)
        )

    def make_story(self, story_hash="900:abc123", paragraphs=12, feed_id=900):
        body = self.story_body(paragraphs)
        story = MStory(
            story_feed_id=feed_id,
            story_hash=story_hash,
            story_guid=story_hash,
            story_title="Council approves housing plan",
            story_date=datetime.datetime.utcnow(),
            story_content_z=zlib.compress(body.encode()),
            # A cached full text means building the manifest never fetches the original page.
            original_text_z=zlib.compress(body.encode()),
        )
        story.save()
        return story


@patch("apps.listen.elevenlabs.is_configured", return_value=True)
class Test_ListenViews(ListenTestCase):
    def post(self, path, data):
        return json.loads(self.client.post(path, data).content)

    def test_free_users_get_a_thirty_second_preview(self, configured):
        story = self.make_story()
        manifest = self.post("/listen/manifest", {"story_hash": story.story_hash})
        self.assertEqual(manifest["code"], 1)
        self.assertTrue(manifest["preview"]["is_preview"])
        self.assertLessEqual(manifest["total_duration"], 31)
        beyond = self.post(
            "/listen/segment", {"manifest_id": manifest["manifest_id"], "index": len(manifest["segments"])}
        )
        self.assertEqual(beyond["reason"], "preview_ended")

    def test_archive_users_get_the_whole_story(self, configured):
        self.set_tier(premium=True, archive=True)
        story = self.make_story()
        manifest = self.post("/listen/manifest", {"story_hash": story.story_hash})
        self.assertFalse(manifest["preview"]["is_preview"])
        self.assertGreater(manifest["total_duration"], 31)
        self.assertEqual(manifest["paragraphs"][0]["kind"], "title")

    def test_free_users_can_sample_three_stories_a_day(self, configured):
        sampled = []
        for n in range(SAMPLE_STORIES_PER_DAY):
            story = self.make_story(story_hash=f"900:s{n}")
            sampled.append(story.story_hash)
            manifest = self.post("/listen/manifest", {"story_hash": story.story_hash})
            segment = self.post("/listen/segment", {"manifest_id": manifest["manifest_id"], "index": 0})
            self.assertEqual(segment["code"], 1)
        another = self.make_story(story_hash="900:another")
        denied = self.post("/listen/manifest", {"story_hash": another.story_hash})
        self.assertEqual(denied["reason"], "sample_limit")
        again = self.post("/listen/manifest", {"story_hash": sampled[0]})
        self.assertEqual(again["code"], 1)

    def test_retrying_a_segment_does_not_charge_twice(self, configured):
        self.set_tier(premium=True, archive=True)
        story = self.make_story()
        manifest = self.post("/listen/manifest", {"story_hash": story.story_hash})
        first = self.post("/listen/segment", {"manifest_id": manifest["manifest_id"], "index": 1})
        second = self.post("/listen/segment", {"manifest_id": manifest["manifest_id"], "index": 1})
        self.assertTrue(first["url"].startswith("/listen/stream/"))
        self.assertEqual(first["url"], second["url"])
        self.assertEqual(MListenUsage.objects(user_id=self.user.pk, segment_index=1).count(), 1)

    def test_archive_cap_blocks_fresh_audio(self, configured):
        self.set_tier(premium=True, archive=True)
        MListenUsage(user_id=self.user.pk, kind="segment", seconds=2 * 60 * 60, cached=False).save()
        story = self.make_story()
        manifest = self.post("/listen/manifest", {"story_hash": story.story_hash})
        self.assertEqual(manifest["code"], 1)
        denied = self.post("/listen/segment", {"manifest_id": manifest["manifest_id"], "index": 0})
        self.assertEqual(denied["reason"], "cap_reached")
        self.assertEqual(denied["usage"]["seconds_remaining"], 0)
        self.assertEqual(denied["usage"]["seconds_limit"], ARCHIVE_WEEKLY_SECONDS)
        self.assertEqual(denied["usage"]["period"], "week")
        self.assertIn("this week", denied["message"])

    def test_cached_stories_still_play_after_the_weekly_cap(self, configured):
        from apps.listen.manifest import load_manifest

        self.set_tier(premium=True, archive=True)
        story = self.make_story()
        before_cap = self.post("/listen/manifest", {"story_hash": story.story_hash})
        self.mark_cached(load_manifest(before_cap["manifest_id"], self.user))
        MListenUsage(user_id=self.user.pk, kind="segment", seconds=2 * 60 * 60, cached=False).save()

        # A player still holding the manifest from before its audio was cached plays it without a new charge.
        held = self.post("/listen/segment", {"manifest_id": before_cap["manifest_id"], "index": 1})
        self.assertEqual(held["code"], 1)
        self.assertTrue(held["cached"])

        reopened = self.post("/listen/manifest", {"story_hash": story.story_hash})
        self.assertEqual(reopened["code"], 1)
        self.assertTrue(all(segment["cached"] for segment in reopened["segments"]))
        replay = self.post("/listen/segment", {"manifest_id": reopened["manifest_id"], "index": 0})
        self.assertEqual(replay["code"], 1)
        self.assertTrue(replay["cached"])
        self.assertEqual(ListenUsageTracker(self.user).seconds_used(), 2 * 60 * 60)

    def test_cached_audio_does_not_count_against_the_cap(self, configured):
        self.set_tier(premium=True, archive=True)
        MListenUsage(user_id=self.user.pk, kind="segment", seconds=600, cached=True).save()
        MListenUsage(user_id=self.user.pk, kind="segment", seconds=120, cached=False).save()
        self.assertEqual(ListenUsageTracker(self.user).seconds_used(), 120)

    def test_segment_requests_from_another_user_are_rejected(self, configured):
        story = self.make_story()
        manifest = self.post("/listen/manifest", {"story_hash": story.story_hash})
        User.objects.create_user("other", "other@example.com", "password")
        other = Client(HTTP_USER_AGENT=USER_AGENT)
        other.login(username="other", password="password")
        response = json.loads(
            other.post("/listen/segment", {"manifest_id": manifest["manifest_id"], "index": 0}).content
        )
        self.assertEqual(response["reason"], "manifest_expired")


@patch("apps.listen.elevenlabs.is_configured", return_value=True)
class Test_ListenStoryAccess(ListenTestCase):
    """Listen reads a story's text aloud, so a second account may only open the stories it could read anyway."""

    def setUp(self):
        super().setUp()
        MStarredStory.drop_collection()
        MSharedStory.drop_collection()
        MSocialProfile.drop_collection()
        self.set_tier(premium=True, archive=True)
        self.intruder = User.objects.create_user("intruder", "intruder@example.com", "password")
        self.set_tier(premium=True, archive=True, user=self.intruder)
        self.intruder_client = Client(HTTP_USER_AGENT=USER_AGENT)
        self.intruder_client.login(username="intruder", password="password")
        self.clear_redis(self.intruder)

    def manifest(self, client, story_hash):
        return json.loads(client.post("/listen/manifest", {"story_hash": story_hash}).content)

    def preview_text(self, client, story_hash):
        from apps.listen import voices

        response = client.post(
            "/listen/preview", {"voice_id": voices.default_voice_id("en"), "story_hash": story_hash}
        )
        return json.loads(response.content)["text"]

    def assert_only_the_owner_can_listen(self, story_hash):
        self.assertEqual(self.manifest(self.client, story_hash)["code"], 1)
        self.assertIn("city council", self.preview_text(self.client, story_hash))
        denied = self.manifest(self.intruder_client, story_hash)
        self.assertEqual(denied["reason"], "not_found")
        self.assertNotIn("paragraphs", denied)
        self.assertNotIn("city council", self.preview_text(self.intruder_client, story_hash))

    def private_feed(self, **fields):
        feed = Feed.objects.create(feed_link="https://private.example", feed_title="Private", **fields)
        UserSubscription.objects.create(user=self.user, feed=feed)
        return feed

    def test_another_accounts_newsletter_story_is_not_found(self, configured):
        # Enough subscribers that only the newsletter rule can keep it private.
        feed = self.private_feed(feed_address="newsletter:listener-inbox", num_subscribers=20)
        story = self.make_story(story_hash="letter", feed_id=feed.pk)
        self.assert_only_the_owner_can_listen(story.story_hash)

    def test_another_accounts_private_feed_story_is_not_found(self, configured):
        feed = self.private_feed(feed_address="https://private.example/rss?token=secret", num_subscribers=1)
        story = self.make_story(story_hash="private", feed_id=feed.pk)
        self.assert_only_the_owner_can_listen(story.story_hash)

    def test_another_accounts_saved_story_is_not_found(self, configured):
        # The feed trimmed the story, so the owner's saved copy is the only one left.
        body = self.story_body()
        saved = MStarredStory(
            user_id=self.user.pk,
            story_feed_id=900,
            story_guid="https://city.example/saved",
            story_title="Council approves housing plan",
            story_date=datetime.datetime.utcnow(),
            starred_date=datetime.datetime.utcnow(),
            story_content=body,
            original_text_z=zlib.compress(body.encode()),
        )
        saved.save()
        self.assertIsNone(MStory.objects(story_hash=saved.story_hash).first())
        self.assert_only_the_owner_can_listen(saved.story_hash)

    def test_public_feed_stories_are_open_to_every_account(self, configured):
        story = self.make_story(story_hash="public")
        self.assertFalse(UserSubscription.objects.filter(user=self.intruder, feed=self.feed).exists())
        self.assertEqual(self.manifest(self.intruder_client, story.story_hash)["code"], 1)
        self.assertIn("city council", self.preview_text(self.intruder_client, story.story_hash))

    def test_a_private_story_shared_to_a_public_blurblog_is_open_to_its_readers(self, configured):
        feed = self.private_feed(feed_address="https://private.example/rss?token=shared", num_subscribers=1)
        story = self.make_story(story_hash="shared", feed_id=feed.pk)
        body = self.story_body()
        MSharedStory(
            user_id=self.user.pk,
            story_feed_id=feed.pk,
            story_guid=story.story_guid,
            story_title=story.story_title,
            story_date=story.story_date,
            story_content=body,
            original_text_z=zlib.compress(body.encode()),
        ).save()
        self.assertEqual(self.manifest(self.intruder_client, story.story_hash)["code"], 1)

        blurblog = MSocialProfile.get_user(self.user.pk)
        blurblog.private = True
        blurblog.save()
        self.assertEqual(self.manifest(self.intruder_client, story.story_hash)["reason"], "not_found")


class Test_ListenFallbackVoices(SimpleTestCase):
    """When ElevenLabs refuses library voices (a plan without them), the stand-in should sound like the pick."""

    def test_fallback_matches_gender_and_accent(self):
        from apps.listen import voices

        premade = {voice["voice_id"]: voice for voice in voices.catalog()["premade"]}
        for picked in (
            {"voice_id": "peter", "gender": "male", "age": "middle_aged", "accent": "american"},
            {"voice_id": "allison", "gender": "female", "age": "young", "accent": "british"},
            {"voice_id": "charlie", "gender": "male", "age": "young", "accent": "australian"},
        ):
            with self.subTest(picked=picked["voice_id"]):
                fallback = premade[voices.fallback_voice_id(picked)]
                self.assertEqual(fallback["gender"], picked["gender"])
                self.assertEqual(fallback["accent"], picked["accent"])


@patch("apps.listen.elevenlabs.is_configured", return_value=True)
@patch("apps.listen.voices.library_voices_blocked", return_value=True)
class Test_ListenBlockedLibraryPreview(ListenTestCase):
    def test_preview_plays_the_voices_own_sample_instead_of_a_stand_in(self, blocked, configured):
        from apps.listen import voices

        picked = voices.curated_voices("en")[0]
        story = self.make_story()
        response = json.loads(
            self.client.post(
                "/listen/preview", {"voice_id": picked["voice_id"], "story_hash": story.story_hash}
            ).content
        )
        self.assertEqual(response["code"], 1)
        self.assertEqual(response["url"], picked["preview_url"])
        self.assertEqual(response["voice"]["voice_id"], picked["voice_id"])
        self.assertTrue(response["sample"])
        self.assertEqual(MListenUsage.objects(user_id=self.user.pk, kind="preview").count(), 0)


@patch("apps.listen.elevenlabs.is_configured", return_value=True)
class Test_ListenAnalytics(ListenTestCase):
    def setUp(self):
        super().setUp()
        from apps.listen.models import MListenDaily

        MListenDaily.drop_collection()

    def listen(self, story_hash, reports):
        story = self.make_story(story_hash=story_hash)
        manifest = json.loads(self.client.post("/listen/manifest", {"story_hash": story.story_hash}).content)
        for seconds, speed, finished in reports:
            self.client.post(
                "/listen/progress",
                {
                    "manifest_id": manifest["manifest_id"],
                    "seconds": seconds,
                    "speed": speed,
                    "finished": finished,
                },
            )
        return manifest

    def metrics(self):
        import redis
        from django.conf import settings

        # All-time totals are cached an hour (apps/monitor/views/newsblur_listen.py).
        redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL).delete("monitor:listen:alltime")
        lines = self.client.get("/monitor/listen").content.decode().splitlines()
        values = {}
        for line in lines:
            if line.startswith("listen{"):
                series, value = line.rsplit(" ", 1)
                self.assertNotIn(series, values, f"duplicate series {series}")
                values[series] = float(value)
        return values

    def test_progress_reports_add_up_to_minutes_and_listeners(self, configured):
        self.set_tier(premium=True, archive=True)
        self.listen("900:one", [(30, 1, "false"), (30, 2, "false"), (6, 1, "true")])
        self.listen("900:two", [(60, 1, "false")])
        values = self.metrics()
        self.assertEqual(values['listen{metric="listeners",period="daily"}'], 1)
        self.assertEqual(values['listen{metric="stories",period="daily"}'], 2)
        self.assertEqual(values['listen{metric="feeds",period="monthly"}'], 1)
        # 30s at 1x + 30s of audio at 2x (15s) + 6s + 60s = 111 seconds listened, 126 seconds of audio.
        self.assertAlmostEqual(values['listen{metric="minutes_listened",period="daily"}'], 1.85, places=2)
        self.assertAlmostEqual(values['listen{metric="audio_minutes",period="alltime"}'], 2.1, places=2)
        self.assertEqual(values['listen{metric="stories_finished",period="daily"}'], 1)
        self.assertEqual(values['listen{metric="listeners_by_tier",tier="archive"}'], 1)

    def test_reports_are_bounded_and_expired_manifests_ignored(self, configured):
        self.set_tier(premium=True, archive=True)
        self.listen("900:big", [(100000, 1, "false")])
        response = json.loads(
            self.client.post("/listen/progress", {"manifest_id": "gone", "seconds": 30}).content
        )
        self.assertEqual(response["code"], 1)
        values = self.metrics()
        self.assertEqual(values['listen{metric="minutes_listened",period="daily"}'], 5)

    def test_preview_funnel_counts_samplers_and_limits(self, configured):
        for n in range(4):
            story = self.make_story(story_hash=f"900:f{n}")
            manifest = json.loads(
                self.client.post("/listen/manifest", {"story_hash": story.story_hash}).content
            )
            if manifest["code"] == 1:
                self.client.post("/listen/segment", {"manifest_id": manifest["manifest_id"], "index": 0})
                self.client.post("/listen/progress", {"manifest_id": manifest["manifest_id"], "seconds": 30})
        values = self.metrics()
        self.assertEqual(values['listen{metric="preview_sampled_users",period="monthly"}'], 1)
        self.assertEqual(values['listen{metric="preview_completed_users",period="monthly"}'], 1)
        self.assertEqual(values['listen{metric="preview_limit_users",period="monthly"}'], 1)
        self.assertEqual(values['listen{metric="denied_requests",reason="sample_limit",period="daily"}'], 1)


@patch("apps.listen.elevenlabs.is_configured", return_value=True)
class Test_ListenAbuse(ListenTestCase):
    """Limits that must hold even for clients that don't behave (backend review, apps/listen)."""

    def post(self, path, data):
        return json.loads(self.client.post(path, data).content)

    def test_manifests_made_up_front_still_count_against_the_daily_samples(self, configured):
        manifests = []
        for n in range(SAMPLE_STORIES_PER_DAY + 1):
            story = self.make_story(story_hash=f"900:up{n}")
            manifests.append(self.post("/listen/manifest", {"story_hash": story.story_hash}))
        self.assertTrue(all(manifest["code"] == 1 for manifest in manifests))
        results = [
            self.post("/listen/segment", {"manifest_id": manifest["manifest_id"], "index": 0})
            for manifest in manifests
        ]
        self.assertEqual([result["code"] for result in results], [1, 1, 1, -1])
        self.assertEqual(results[-1]["reason"], "sample_limit")

    def test_rebuilding_a_sampled_story_with_new_voices_stops_at_the_fresh_audio_budget(self, configured):
        from apps.listen.usage import SAMPLE_FRESH_SECONDS_PER_DAY

        story = self.make_story(story_hash="900:voices")
        MListenUsage(
            user_id=self.user.pk,
            kind="segment",
            story_hash=story.story_hash,
            seconds=SAMPLE_FRESH_SECONDS_PER_DAY,
            is_sample=True,
            cached=False,
        ).save()
        manifest = self.post("/listen/manifest", {"story_hash": story.story_hash})
        self.assertEqual(manifest["code"], 1)
        segment = self.post("/listen/segment", {"manifest_id": manifest["manifest_id"], "index": 0})
        self.assertEqual(segment["reason"], "sample_limit")

    def test_a_crafted_voice_id_never_reaches_elevenlabs(self, configured):
        from apps.listen import voices

        self.set_tier(premium=True, archive=True)
        story = self.make_story(story_hash="900:inject")
        default_voice = voices.default_voice_id("en")
        for voice_id in ("../../v1/sound-generation#", "x" * 20, "abcdefghij0123456789"):
            with self.subTest(voice_id=voice_id):
                manifest = self.post(
                    "/listen/manifest", {"story_hash": story.story_hash, "voice_id": voice_id}
                )
                self.assertEqual(manifest["voice"]["voice_id"], default_voice)
                preview = self.post("/listen/preview", {"voice_id": voice_id, "story_hash": story.story_hash})
                self.assertEqual(preview["voice"]["voice_id"], default_voice)
        self.user.profile.preferences = json.dumps({"listen_voices": json.dumps({"en": "../../v1/x#"})})
        self.user.profile.save()
        manifest = self.post("/listen/manifest", {"story_hash": story.story_hash})
        self.assertEqual(manifest["voice"]["voice_id"], default_voice)

    def test_rebuilding_the_same_manifest_reuses_it(self, configured):
        story = self.make_story(story_hash="900:same")
        first = self.post("/listen/manifest", {"story_hash": story.story_hash})
        second = self.post("/listen/manifest", {"story_hash": story.story_hash})
        self.assertEqual(first["manifest_id"], second["manifest_id"])

    def test_manifests_are_rate_limited(self, configured):
        from apps.listen.manifest import MANIFESTS_PER_WINDOW

        self.set_tier(premium=True, archive=True)
        story = self.make_story(story_hash="900:flood")
        for n in range(MANIFESTS_PER_WINDOW):
            self.post("/listen/manifest", {"story_hash": story.story_hash, "language": "en"})
        denied = self.post("/listen/manifest", {"story_hash": story.story_hash})
        self.assertEqual(denied["reason"], "rate_limited")

    def test_identical_text_in_two_feeds_shares_one_s3_object(self, configured):
        from apps.listen.storage import object_key

        self.assertEqual(object_key("abc"), "listen/segments/abc.mp3")

    @patch("apps.listen.voices.library_voices_blocked", return_value=False)
    def test_a_manifest_built_before_library_voices_were_refused_is_rebuilt(self, blocked, configured):
        self.set_tier(premium=True, archive=True)
        story = self.make_story(story_hash="900:refused")
        manifest = self.post("/listen/manifest", {"story_hash": story.story_hash})
        blocked.return_value = True
        segment = self.post("/listen/segment", {"manifest_id": manifest["manifest_id"], "index": 0})
        self.assertEqual(segment["reason"], "manifest_expired")


class Test_ListenUsageWindows(SimpleTestCase):
    def tracker(self, timezone_name):
        from types import SimpleNamespace

        user = SimpleNamespace(pk=1, profile=SimpleNamespace(timezone=timezone_name))
        return ListenUsageTracker(user)

    def test_week_and_day_windows_start_at_local_midnight_across_dst(self):
        import pytz

        tracker = self.tracker("America/New_York")
        # Weeks start on Sunday. Nov 1, 2026 is a Sunday and the night the clocks fall back, so the week began at
        # midnight EDT (04:00 UTC) and the next one begins at midnight EST (05:00 UTC).
        now = pytz.UTC.localize(datetime.datetime(2026, 11, 4, 15, 0))
        start, end, reset_local = tracker.week_window(now=now)
        self.assertEqual(start, datetime.datetime(2026, 11, 1, 4, 0))
        self.assertEqual(end, datetime.datetime(2026, 11, 8, 5, 0))
        self.assertEqual(reset_local.date(), datetime.date(2026, 11, 8))
        # Sunday itself starts a new week.
        start, end, _ = tracker.week_window(now=pytz.UTC.localize(datetime.datetime(2026, 11, 8, 10, 0)))
        self.assertEqual(start, datetime.datetime(2026, 11, 8, 5, 0))
        self.assertEqual(end, datetime.datetime(2026, 11, 15, 5, 0))
        # Saturday night in UTC is still Saturday in New York, so it belongs to the week that is ending.
        start, _, _ = tracker.week_window(now=pytz.UTC.localize(datetime.datetime(2026, 11, 8, 3, 0)))
        self.assertEqual(start, datetime.datetime(2026, 11, 1, 4, 0))
        # Mar 8, 2026 springs forward at 2am; that day still began at midnight EST (05:00 UTC).
        day_start, day_end = tracker.day_window(now=pytz.UTC.localize(datetime.datetime(2026, 3, 8, 20, 0)))
        self.assertEqual(day_start, datetime.datetime(2026, 3, 8, 5, 0))
        self.assertEqual(day_end, datetime.datetime(2026, 3, 9, 4, 0))

    def test_weekly_limits_are_ten_hours_for_pro_and_one_hour_for_archive(self):
        self.assertEqual(PRO_WEEKLY_SECONDS, 10 * 60 * 60)
        self.assertEqual(ARCHIVE_WEEKLY_SECONDS, 60 * 60)

    def test_durations_read_as_hours_and_minutes(self):
        tracker = self.tracker("UTC")
        self.assertEqual(tracker.format_duration(30 * 60), "30 minutes")
        self.assertEqual(tracker.format_duration(60 * 60), "1 hour")
        self.assertEqual(tracker.format_duration(90 * 60), "1 hour 30 minutes")
        self.assertEqual(tracker.format_duration(10 * 60 * 60), "10 hours")

    def test_cap_messages_name_the_week_and_the_reset_day(self):
        from types import SimpleNamespace

        archive = ListenUsageTracker(
            SimpleNamespace(
                pk=1, profile=SimpleNamespace(timezone="UTC", is_pro=False, is_archive=True, is_premium=True)
            )
        )
        self.assertEqual(
            archive.cap_message(),
            "You've listened to 1 hour of stories this week. Listening resets on Sunday, "
            "or upgrade to Premium Pro for 10 hours a week.",
        )
        self.assertIsNone(archive.upgrade_message())
        pro = ListenUsageTracker(
            SimpleNamespace(
                pk=1, profile=SimpleNamespace(timezone="UTC", is_pro=True, is_archive=True, is_premium=True)
            )
        )
        self.assertEqual(
            pro.cap_message(), "You've listened to 10 hours of stories this week. Listening resets on Sunday."
        )
        free = ListenUsageTracker(
            SimpleNamespace(
                pk=1,
                profile=SimpleNamespace(timezone="UTC", is_pro=False, is_archive=False, is_premium=False),
            )
        )
        self.assertEqual(
            free.upgrade_message(), "Premium Archive unlocks full stories read aloud, up to 1 hour a week."
        )
        self.assertEqual(pro.weekly_limit, PRO_WEEKLY_SECONDS)
        self.assertEqual(archive.weekly_limit, ARCHIVE_WEEKLY_SECONDS)
