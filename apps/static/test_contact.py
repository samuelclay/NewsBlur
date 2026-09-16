from unittest.mock import patch

from django.contrib.sites.models import Site
from django.test import SimpleTestCase
from django.urls import resolve, reverse


class Test_ContactPage(SimpleTestCase):
    @patch("utils.templatetags.utils_tags.Site.objects.get_current")
    def test_public_contact_page_has_visible_email(self, get_current_site):
        from django.test import RequestFactory

        get_current_site.return_value = Site(domain="www.newsblur.com", name="NewsBlur")
        path = reverse("contact")
        response = resolve(path).func(RequestFactory().get(path))
        self.assertContains(response, "Contact us")
        self.assertContains(response, "mailto:android@newsblur.com")
        self.assertContains(response, "android@newsblur.com</a>")
        self.assertContains(response, "mailto:samuel@newsblur.com")

    def test_public_footer_links_to_contact_page(self):
        from django.template.loader import render_to_string

        footer = render_to_string("reader/footer.xhtml")
        self.assertIn('href="%s">Contact us</a>' % reverse("contact"), footer)
