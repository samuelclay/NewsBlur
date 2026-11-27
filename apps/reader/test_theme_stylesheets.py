"""Tests for where the Gray and Warm theme stylesheets sit in the CSS bundle."""

from django.test import SimpleTestCase
from pipeline.packager import Packager


class Test_ThemeStylesheetOrder(SimpleTestCase):
    def test_gray_and_warm_load_after_every_stylesheet_they_answer(self):
        # test_theme_stylesheets.py: graymode.css and sepiamode.css restate dark and light rules at
        # those rules' own specificity, so they only win by coming later. A stylesheet listed after
        # them in newsblur_web/assets.yml would keep its light or slate colors in Gray and Warm.
        stylesheets = [path.rsplit("/", 1)[-1] for path in Packager().package_for("css", "common").paths]

        self.assertEqual(stylesheets[-2:], ["graymode.css", "sepiamode.css"])
