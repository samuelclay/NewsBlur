import datetime
import hashlib
import time
from urllib.parse import urljoin

import requests
from django.conf import settings
from lxml import html as lxml_html

from apps.rss_feeds.models import Feed
from apps.webfeed.models import MWebFeedConfig
from utils import log as logging

USER_AGENT = "NewsBlur Web Feed Fetcher (https://newsblur.com)"

# Custom exception code for web feed XPath extraction failure
WEBFEED_EXCEPTION_CODE = 590


class WebFeedFetcher:
    """Fetches HTML from a website and extracts stories using stored XPath expressions."""

    def __init__(self, feed):
        self.feed = feed
        self.url = feed.feed_address[len("webfeed:"):]
        self.config = MWebFeedConfig.get_config(feed.pk)

    def fetch(self):
        """Main entry point. Returns a feedparser-compatible dict or None on failure."""
        if not self.config:
            logging.debug(
                "   ***> [%-30s] ~FRWeb Feed: No config found for feed %s" % (self.feed.log_title[:30], self.feed.pk)
            )
            return None

        start = time.time()
        logging.debug(
            "   ---> [%-30s] ~FYWeb Feed: Fetching ~SB%s~SN" % (self.feed.log_title[:30], self.url)
        )

        page_html = self._fetch_html()
        if not page_html:
            self.config.record_failure()
            if self.config.needs_reanalysis:
                self.feed.has_feed_exception = True
                self.feed.exception_code = WEBFEED_EXCEPTION_CODE
                self.feed.save()
            return None

        stories = self._extract_stories(page_html)

        if not stories:
            self.config.record_failure()
            logging.debug(
                "   ***> [%-30s] ~FRWeb Feed: 0 stories extracted (failure %d)"
                % (self.feed.log_title[:30], self.config.consecutive_failures)
            )
            if self.config.needs_reanalysis:
                self.feed.has_feed_exception = True
                self.feed.exception_code = WEBFEED_EXCEPTION_CODE
                self.feed.save()
            return None

        self.config.record_success()

        # Clear any previous exception
        if self.feed.has_feed_exception and self.feed.exception_code == WEBFEED_EXCEPTION_CODE:
            self.feed.has_feed_exception = False
            self.feed.exception_code = 0
            self.feed.save()

        fpf = self._to_feedparser_format(stories)

        logging.debug(
            "   ---> [%-30s] ~FGWeb Feed: Extracted ~SB%s~SN stories in ~SB%.2fs~SN"
            % (self.feed.log_title[:30], len(stories), time.time() - start)
        )

        return fpf

    def _fetch_html(self):
        """Fetch page HTML with proxy fallbacks for forbidden feeds."""
        headers = {"User-Agent": USER_AGENT}

        # Try direct fetch first
        try:
            response = requests.get(self.url, headers=headers, timeout=15, allow_redirects=True)
            if response.status_code == 200 and response.text:
                return response.text
        except requests.RequestException:
            pass

        # Fallback to ScrapingBee
        if getattr(settings, "SCRAPINGBEE_API_KEY", None):
            try:
                response = requests.get(
                    "https://app.scrapingbee.com/api/v1",
                    params={
                        "api_key": settings.SCRAPINGBEE_API_KEY,
                        "url": self.url,
                        "render_js": "false",
                        "return_page_source": "true",
                    },
                    timeout=15,
                )
                if response.status_code == 200 and response.text:
                    return response.text
            except requests.RequestException:
                pass

        # Fallback to ScrapeNinja
        if getattr(settings, "SCRAPENINJA_API_KEY", None):
            try:
                response = requests.post(
                    "https://scrapeninja.p.rapidapi.com/scrape",
                    headers={
                        "X-RapidAPI-Key": settings.SCRAPENINJA_API_KEY,
                        "X-RapidAPI-Host": "scrapeninja.p.rapidapi.com",
                        "Content-Type": "application/json",
                    },
                    json={"url": self.url},
                    timeout=15,
                )
                if response.status_code == 200:
                    data = response.json()
                    if data.get("body"):
                        return data["body"]
            except requests.RequestException:
                pass

        logging.debug(
            "   ***> [%-30s] ~FRWeb Feed: All fetch methods failed for ~SB%s~SN"
            % (self.feed.log_title[:30], self.url)
        )
        return None

    def _extract_stories(self, html_text):
        """Apply stored XPaths to HTML and extract story dicts."""
        try:
            doc = lxml_html.fromstring(html_text)
        except Exception:
            return []

        stories = []
        seen_keys = set()
        try:
            containers = doc.xpath(self.config.story_container_xpath)
        except Exception:
            return []

        for container in containers:
            story = {}

            # Title
            try:
                titles = container.xpath(self.config.title_xpath)
                story["title"] = titles[0].strip() if titles else None
            except Exception:
                story["title"] = None

            # Link
            try:
                links = container.xpath(self.config.link_xpath)
                link = links[0].strip() if links else None
                if link and not link.startswith("http"):
                    link = urljoin(self.url, link)
                story["link"] = link
            except Exception:
                story["link"] = None

            # Content
            if self.config.content_xpath:
                try:
                    contents = container.xpath(self.config.content_xpath)
                    story["content"] = contents[0].strip() if contents else ""
                except Exception:
                    story["content"] = ""
            else:
                story["content"] = ""

            # Image
            if self.config.image_xpath:
                try:
                    images = container.xpath(self.config.image_xpath)
                    img_src = images[0].strip() if images else ""
                    if img_src and not img_src.startswith("http"):
                        img_src = urljoin(self.url, img_src)
                    story["image"] = img_src
                except Exception:
                    story["image"] = ""
            else:
                story["image"] = ""

            # Author
            if self.config.author_xpath:
                try:
                    authors = container.xpath(self.config.author_xpath)
                    story["author"] = authors[0].strip() if authors else ""
                except Exception:
                    story["author"] = ""
            else:
                story["author"] = ""

            # Date
            if self.config.date_xpath:
                try:
                    dates = container.xpath(self.config.date_xpath)
                    story["date_string"] = dates[0].strip() if dates else ""
                except Exception:
                    story["date_string"] = ""
            else:
                story["date_string"] = ""

            # Generate GUID
            story["guid"] = self._generate_guid(story.get("link"), story.get("title"))

            if story.get("title") or story.get("link"):
                dedup_key = (story.get("title", ""), story.get("link", ""))
                if dedup_key in seen_keys:
                    continue
                seen_keys.add(dedup_key)
                stories.append(story)

        return stories

    def _generate_guid(self, permalink, title):
        """Generate a stable GUID for a web-scraped story."""
        if permalink:
            normalized = permalink.rstrip("/").lower()
            return hashlib.sha256(normalized.encode("utf-8")).hexdigest()[:32]
        if title:
            key = f"{self.feed.pk}:{title.strip().lower()}"
            return hashlib.sha256(key.encode("utf-8")).hexdigest()[:32]
        return hashlib.sha256(str(time.time()).encode("utf-8")).hexdigest()[:32]

    def _to_feedparser_format(self, stories):
        """Build a feedparser-compatible result dict from extracted stories."""
        entries = []
        for story in stories:
            summary = story.get("content", "")
            image_url = story.get("image", "")
            if image_url:
                img_tag = f'<img src="{image_url}" />'
                summary = img_tag + summary if summary else img_tag
            entry = {
                "title": story.get("title", ""),
                "link": story.get("link", ""),
                "guid": story.get("guid", ""),
                "summary": summary,
                "author": story.get("author", ""),
            }
            entries.append(entry)

        # Build a minimal feedparser-like object
        fpf = FeedParserResult(
            entries=entries,
            feed_title=self.feed.feed_title,
            feed_link=self.url,
            encoding="utf-8",
        )

        return fpf


class FeedParserResult:
    """Minimal feedparser-compatible result object for web feed extraction."""

    def __init__(self, entries, feed_title, feed_link, encoding="utf-8"):
        self.entries = entries
        self.encoding = encoding
        self.headers = {}
        self.feed = FeedParserFeed(feed_title, feed_link)
        self.bozo = 0
        self.status = 200
        self.etag = None
        self.modified = None

    def get(self, key, default=None):
        return getattr(self, key, default)


class FeedParserFeed:
    """Minimal feedparser feed metadata object."""

    def __init__(self, title, link):
        self.title = title
        self.link = link

    def get(self, key, default=None):
        return getattr(self, key, default)
