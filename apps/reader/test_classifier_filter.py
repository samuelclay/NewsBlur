from django.test import SimpleTestCase

from apps.reader.views import filter_stories_by_classifier


class Test_ClassifierFilterMatching(SimpleTestCase):
    def test_title_filter_matches_classifier_word_start_semantics(self):
        stories = [
            {"story_title": "Dolly Parton remembered"},
            {"story_title": "Art and design"},
            {"story_title": "Artificial intelligence update"},
        ]

        matches = filter_stories_by_classifier(stories, "title", "art")

        self.assertEqual(
            [story["story_title"] for story in matches],
            ["Art and design", "Artificial intelligence update"],
        )
