"""Unit tests for strip_non_embeddable_iframes in utils/story_functions.py."""

from django.test import SimpleTestCase

from utils.story_functions import strip_non_embeddable_iframes

FACEBOOK_POST = (
    '<iframe src="https://www.facebook.com/plugins/post.php?href='
    'https%3A%2F%2Fwww.facebook.com%2FUrbanComics%2Fposts%2Fpfbid02vS&amp;show_text=true'
    '&amp;width=500" width="500" height="628"></iframe>'
)
SLASHDOT_AD = '<iframe src="http://feedads.g.doubleclick.net/~ah/f/x/300/250"></iframe>'


class StripNonEmbeddableIframesTest(SimpleTestCase):
    def test_keeps_facebook_plugin_iframe(self):
        content = "<p>Before</p>%s<p>After</p>" % FACEBOOK_POST
        self.assertEqual(strip_non_embeddable_iframes(content), content)

    def test_keeps_facebook_embed_urls(self):
        for src in [
            "https://www.facebook.com/plugins/post.php?href=x",
            "https://facebook.com/plugins/post.php",
            "https://m.facebook.com/plugins/video.php?href=x",
        ]:
            with self.subTest(src=src):
                content = '<iframe src="%s"></iframe>' % src
                self.assertEqual(strip_non_embeddable_iframes(content), content)

    def test_strips_other_facebook_urls(self):
        for src in [
            "https://www.facebook.com/UrbanComics",
            "https://www.facebook.com/plugins/page.php",
            "https://www.facebook.com/plugins/post.php/extra",
            "https://evil.facebook.com/plugins/post.php",
            "https://www.facebook.com.evil.example/plugins/post.php",
        ]:
            with self.subTest(src=src):
                content = '<iframe src="%s"></iframe>' % src
                self.assertEqual(strip_non_embeddable_iframes(content), "")

    def test_does_not_match_lookalike_domain(self):
        content = '<iframe src="https://notfacebook.com/plugins/post.php"></iframe>'
        self.assertEqual(strip_non_embeddable_iframes(content), "")

    def test_still_strips_other_iframes(self):
        self.assertEqual(strip_non_embeddable_iframes("<p>a</p>" + SLASHDOT_AD), "<p>a</p>")
