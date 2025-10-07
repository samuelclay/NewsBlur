import datetime
import html
import multiprocessing
import time
import traceback

import django

django.setup()

import http
import http.client
import urllib.error
import urllib.parse
import urllib.request

http.client._MAXHEADERS = 10000

import random
import re
import xml.sax

import feedparser
import pymongo
import redis
import requests
from django.conf import settings
from django.core.cache import cache
from django.db import IntegrityError
from sentry_sdk import set_user

from apps.notifications.models import MUserFeedNotification
from apps.notifications.tasks import QueueNotifications
from apps.push.models import PushSubscription
from apps.reader.models import UserSubscription
from apps.rss_feeds.icon_importer import IconImporter
from apps.rss_feeds.models import Feed, MStory
from apps.rss_feeds.page_importer import PageImporter
from apps.statistics.models import MAnalyticsFetcher, MStatistics

feedparser.sanitizer._HTMLSanitizer.acceptable_elements.update(["iframe"])
feedparser.sanitizer._HTMLSanitizer.acceptable_elements.update(["text"])

from bs4 import BeautifulSoup
from celery.exceptions import SoftTimeLimitExceeded
from django.utils import feedgenerator
from django.utils.encoding import smart_str
from django.utils.html import linebreaks
from mongoengine import connect, connection
from qurl import qurl
from sentry_sdk import capture_exception, flush

from utils import json_functions as json
from utils import log as logging
from utils.facebook_fetcher import FacebookFetcher
from utils.feed_functions import (
    TimeoutError,
    strip_underscore_from_feed_address,
    timelimit,
)
from utils.json_fetcher import JSONFetcher
from utils.story_functions import (
    extract_story_date,
    linkify,
    pre_process_story,
    strip_tags,
)
from utils.twitter_fetcher import TwitterFetcher
from utils.youtube_fetcher import YoutubeFetcher


def preprocess_feed_encoding(raw_xml):
    """
    Fix for The Verge RSS feed encoding issues (and other feeds with similar problems).

    The Verge and other Vox Media sites often serve RSS feeds with special characters
    that were incorrectly encoded. This happens when UTF-8 bytes are misinterpreted
    as Latin-1/Windows-1252 characters and then HTML-encoded, resulting in garbled text
    like "Apple&acirc;&#128;&#153;s" instead of "Apple's" with a smart apostrophe.

    This function detects these patterns and reverses the process by:
    1. Unescaping the HTML entities (producing characters like â€™)
    2. Re-encoding as Latin-1 and decoding as UTF-8 to recover the original characters

    Args:
        raw_xml (str): The raw XML content fetched from the feed

    Returns:
        str: The corrected XML content with proper encoding
    """
    # Common indicators of misencoded UTF-8
    misencoding_indicators = [
        # Common UTF-8 double encoded patterns
        "&acirc;&#128;&#153;",  # Smart apostrophe (')
        "&acirc;&#128;&#147;",  # Em dash (—)
        "&acirc;&#128;&#148;",  # En dash (–)
        "&acirc;&#128;&#156;",  # Opening smart quote (")
        "&acirc;&#128;&#157;",  # Closing smart quote (")
        "&acirc;&#128;&#152;",  # Single opening quote (')
        "&acirc;&#128;&#153;",  # Single closing quote (')
        "&acirc;&#128;&#166;",  # Ellipsis (…)
        "&acirc;&#128;&#160;",  # Non-breaking space
        "&acirc;&#128;&#176;",  # Bullet point (•)
        "&acirc;&#128;&#174;",  # Registered trademark (®)
        "&acirc;&#128;&#169;",  # Copyright (©)
        # Additional patterns that indicate encoding issues
        "&Atilde;&copy;",  # é misencoded
        "&Atilde;&reg;",  # ® misencoded
        "&Atilde;&para;",  # ¶ misencoded
        "&Atilde;&sup2;",  # ² misencoded
        "&Atilde;&deg;",  # ° misencoded
        "&Aring;&frac12;",  # ½ misencoded
    ]

    # Check if any of the indicators are present
    needs_fixing = any(indicator in raw_xml for indicator in misencoding_indicators)

    if needs_fixing:
        try:
            # Step 1: HTML Unescaping - convert HTML entities to their literal characters
            # This will typically produce characters like â€™ in place of the intended smart apostrophe
            unescaped = html.unescape(raw_xml)

            # Step 2: Encoding Reinterpretation
            # Re-encode as Latin-1/Windows-1252 and decode as UTF-8
            # This "encoding shuffle" restores the original characters
            corrected = unescaped.encode("latin1").decode("utf-8", errors="replace")

            return corrected
        except (UnicodeError, AttributeError) as e:
            # If there's an error in the encoding correction, log it and return the original
            logging.debug("Error fixing feed encoding: %s" % str(e))
            return raw_xml

    # If no indicators are found, return the original XML
    return raw_xml


# from utils.feed_functions import mail_feed_error_to_admin


# Refresh feed code adapted from Feedjack.
# http://feedjack.googlecode.com

MAX_ENTRIES_TO_PROCESS = 100
MAX_ENTRIES_HIGH_VOLUME = 250
HIGH_VOLUME_FEED_URLS = ["arxiv.org"]  # Feeds that can handle more stories per fetch

FEED_OK, FEED_SAME, FEED_ERRPARSE, FEED_ERRHTTP, FEED_ERREXC = list(range(5))

NO_UNDERSCORE_ADDRESSES = ["jwz"]


class FetchFeed:
    def __init__(self, feed_id, options):
        self.feed = Feed.get_by_id(feed_id)
        self.options = options
        self.fpf = None
        self.raw_feed = None

    @timelimit(45)
    def fetch(self):
        """
        Uses requests to download the feed, parsing it in feedparser. Will be storified later.
        """
        start = time.time()
        identity = self.get_identity()
        if self.options.get("archive_page", None):
            log_msg = "%2s ---> [%-30s] ~FYFetching feed (~FB%d~FY) ~BG~FMarchive page~ST~FY: ~SB%s" % (
                identity,
                self.feed.log_title[:30],
                self.feed.id,
                self.options["archive_page"],
            )
        else:
            log_msg = "%2s ---> [%-30s] ~FYFetching feed (~FB%d~FY), last update: %s" % (
                identity,
                self.feed.log_title[:30],
                self.feed.id,
                datetime.datetime.now() - self.feed.last_update,
            )
        logging.debug(log_msg)

        etag = self.feed.etag
        modified = self.feed.last_modified.utctimetuple()[:7] if self.feed.last_modified else None
        address = self.feed.feed_address

        if self.options.get("force") or self.options.get("archive_page", None) or random.random() <= 0.01:
            self.options["force"] = True
            modified = None
            etag = None
            if self.options.get("archive_page", None) == "rfc5005" and self.options.get(
                "archive_page_link", None
            ):
                address = self.options["archive_page_link"]
            elif self.options.get("archive_page", None):
                address = qurl(address, add={self.options["archive_page_key"]: self.options["archive_page"]})
            # Don't use the underscore cache buster: https://forum.newsblur.com/t/jwz-feed-broken-hes-mad-about-url-parameters/10742/15
            # elif address.startswith("http") and not any(item in address for item in NO_UNDERSCORE_ADDRESSES):
            #     address = qurl(address, add={"_": random.randint(0, 10000)})
            logging.debug("   ---> [%-30s] ~FBForcing fetch: %s" % (self.feed.log_title[:30], address))
        elif not self.feed.fetched_once or not self.feed.known_good:
            modified = None
            etag = None

        if self.options.get("feed_xml"):
            logging.debug(
                "   ---> [%-30s] ~FM~BKFeed has been fat pinged. Ignoring fat: %s"
                % (self.feed.log_title[:30], len(self.options.get("feed_xml")))
            )

        if self.options.get("fpf"):
            self.fpf = self.options.get("fpf")
            logging.debug(
                "   ---> [%-30s] ~FM~BKFeed fetched in real-time with fat ping." % (self.feed.log_title[:30])
            )
            return FEED_OK, self.fpf

        if "youtube.com" in address:
            youtube_feed = self.fetch_youtube()
            if not youtube_feed:
                logging.debug(
                    "   ***> [%-30s] ~FRYouTube fetch failed: %s." % (self.feed.log_title[:30], address)
                )
                return FEED_ERRHTTP, None
            # Apply encoding preprocessing to special feed content
            processed_youtube_feed = preprocess_feed_encoding(youtube_feed)
            if processed_youtube_feed != youtube_feed:
                logging.debug(
                    "   ---> [%-30s] ~FGApplied encoding correction to YouTube feed"
                    % (self.feed.log_title[:30])
                )
            self.fpf = feedparser.parse(processed_youtube_feed, sanitize_html=False)
        elif re.match(r"(https?)?://twitter.com/\w+/?", qurl(address, remove=["_"])):
            twitter_feed = self.fetch_twitter(address)
            if not twitter_feed:
                logging.debug(
                    "   ***> [%-30s] ~FRTwitter fetch failed: %s" % (self.feed.log_title[:30], address)
                )
                return FEED_ERRHTTP, None
            # Apply encoding preprocessing to special feed content
            processed_twitter_feed = preprocess_feed_encoding(twitter_feed)
            if processed_twitter_feed != twitter_feed:
                logging.debug(
                    "   ---> [%-30s] ~FGApplied encoding correction to Twitter feed"
                    % (self.feed.log_title[:30])
                )
            self.fpf = feedparser.parse(processed_twitter_feed)
        elif re.match(r"(.*?)facebook.com/\w+/?$", qurl(address, remove=["_"])):
            facebook_feed = self.fetch_facebook()
            if not facebook_feed:
                logging.debug(
                    "   ***> [%-30s] ~FRFacebook fetch failed: %s" % (self.feed.log_title[:30], address)
                )
                return FEED_ERRHTTP, None
            # Apply encoding preprocessing to special feed content
            processed_facebook_feed = preprocess_feed_encoding(facebook_feed)
            if processed_facebook_feed != facebook_feed:
                logging.debug(
                    "   ---> [%-30s] ~FGApplied encoding correction to Facebook feed"
                    % (self.feed.log_title[:30])
                )
            self.fpf = feedparser.parse(processed_facebook_feed)
        elif self.feed.is_forbidden:
            # 10% chance to turn off is_forbidden flag before fetching
            if random.random() <= 0.1:
                logging.debug(
                    "   ---> [%-30s] ~FG~SBTurning off forbidden flag (~FB10%%~FG chance) and fetching normally"
                    % (self.feed.log_title[:30])
                )
                self.feed.is_forbidden = False
                self.feed = self.feed.save()
                # Skip this branch and continue with normal fetch flow
                # We don't need to do anything else here - just let the normal fetch flow continue
            else:
                # Regular forbidden feed fetch
                forbidden_status, forbidden_feed = self.fetch_forbidden()
                if forbidden_status == 304:
                    logging.debug(
                        "   ---> [%-30s] ~FGForbidden feed not modified (304)"
                        % (self.feed.log_title[:30])
                    )
                    self.feed = self.feed.save()
                    self.feed.save_feed_history(304, "Not modified")
                    return FEED_SAME, None
                if not forbidden_feed or not forbidden_status:
                    logging.debug(
                        "   ***> [%-30s] ~FRForbidden feed fetch failed: %s"
                        % (self.feed.log_title[:30], address)
                    )
                    return FEED_ERRHTTP, None
                # Apply encoding preprocessing to special feed content
                processed_forbidden_feed = preprocess_feed_encoding(forbidden_feed)
                if processed_forbidden_feed != forbidden_feed:
                    logging.debug(
                        "   ---> [%-30s] ~FGApplied encoding correction to forbidden feed"
                        % (self.feed.log_title[:30])
                    )
                self.fpf = feedparser.parse(processed_forbidden_feed)

        if not self.fpf and "json" in address:
            try:
                headers = self.feed.fetch_headers()
                if etag:
                    headers["If-None-Match"] = etag
                if modified:
                    # format into an RFC 1123-compliant timestamp. We can't use
                    # time.strftime() since the %a and %b directives can be affected
                    # by the current locale, but RFC 2616 states that dates must be
                    # in English.
                    short_weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                    months = [
                        "Jan",
                        "Feb",
                        "Mar",
                        "Apr",
                        "May",
                        "Jun",
                        "Jul",
                        "Aug",
                        "Sep",
                        "Oct",
                        "Nov",
                        "Dec",
                    ]
                    modified_header = "%s, %02d %s %04d %02d:%02d:%02d GMT" % (
                        short_weekdays[modified[6]],
                        modified[2],
                        months[modified[1] - 1],
                        modified[0],
                        modified[3],
                        modified[4],
                        modified[5],
                    )
                    headers["If-Modified-Since"] = modified_header
                if etag or modified:
                    headers["A-IM"] = "feed"
                try:
                    raw_feed = requests.get(address, headers=headers, timeout=15)
                except (requests.adapters.ConnectionError, TimeoutError):
                    raw_feed = None
                if not raw_feed or raw_feed.status_code >= 400:
                    if raw_feed:
                        logging.debug(
                            "   ***> [%-30s] ~FRFeed fetch was %s status code, trying fake user agent: %s"
                            % (self.feed.log_title[:30], raw_feed.status_code, raw_feed.headers)
                        )
                    else:
                        logging.debug(
                            "   ***> [%-30s] ~FRJson feed fetch timed out, trying fake headers: %s"
                            % (self.feed.log_title[:30], address)
                        )
                    raw_feed = requests.get(
                        self.feed.feed_address,
                        headers=self.feed.fetch_headers(fake=True),
                        timeout=15,
                    )

                json_feed_content_type = any(
                    json_feed in raw_feed.headers.get("Content-Type", "")
                    for json_feed in ["application/feed+json", "application/json"]
                )
                if raw_feed.content and json_feed_content_type:
                    # JSON Feed
                    json_feed = self.fetch_json_feed(address, raw_feed)
                    if not json_feed:
                        logging.debug(
                            "   ***> [%-30s] ~FRJSON fetch failed: %s" % (self.feed.log_title[:30], address)
                        )
                        return FEED_ERRHTTP, None
                    # Apply encoding preprocessing to JSON feed content
                    processed_json_feed = preprocess_feed_encoding(json_feed)
                    if processed_json_feed != json_feed:
                        logging.debug(
                            "   ---> [%-30s] ~FGApplied encoding correction to JSON feed"
                            % (self.feed.log_title[:30])
                        )
                    self.fpf = feedparser.parse(processed_json_feed)
                elif raw_feed.content and raw_feed.status_code < 400:
                    response_headers = raw_feed.headers
                    response_headers["Content-Location"] = raw_feed.url
                    self.raw_feed = smart_str(raw_feed.content)
                    # Preprocess feed to fix encoding issues before parsing with feedparser
                    processed_feed = preprocess_feed_encoding(self.raw_feed)
                    if processed_feed != self.raw_feed:
                        logging.debug(
                            "   ---> [%-30s] ~FGApplied encoding correction to feed with misencoded HTML entities"
                            % (self.feed.log_title[:30])
                        )
                    self.fpf = feedparser.parse(processed_feed, response_headers=response_headers)
                    if self.options["verbose"]:
                        logging.debug(
                            " ---> [%-30s] ~FBFeed fetch status %s: %s length / %s"
                            % (
                                self.feed.log_title[:30],
                                raw_feed.status_code,
                                len(smart_str(raw_feed.content)),
                                raw_feed.headers,
                            )
                        )
            except Exception as e:
                logging.debug(
                    "   ***> [%-30s] ~FRFeed failed to fetch with request, trying feedparser: %s"
                    % (self.feed.log_title[:30], str(e))
                )
                # raise e

        if not self.fpf or self.options.get("force_fp", False):
            try:
                # When feedparser fetches the URL itself, we cannot preprocess the content first
                # We'll have to rely on feedparser's built-in handling here
                self.fpf = feedparser.parse(address, agent=self.feed.user_agent, etag=etag, modified=modified)
            except (
                TypeError,
                ValueError,
                KeyError,
                EOFError,
                MemoryError,
                urllib.error.URLError,
                http.client.InvalidURL,
                http.client.BadStatusLine,
                http.client.IncompleteRead,
                ConnectionResetError,
                TimeoutError,
            ) as e:
                logging.debug("   ***> [%-30s] ~FRFeed fetch error: %s" % (self.feed.log_title[:30], e))
                pass

        if not self.fpf:
            try:
                logging.debug(
                    "   ***> [%-30s] ~FRTurning off headers: %s" % (self.feed.log_title[:30], address)
                )
                # Another direct URL fetch that bypasses our preprocessing
                self.fpf = feedparser.parse(address, agent=self.feed.user_agent)
            except (
                TypeError,
                ValueError,
                KeyError,
                EOFError,
                MemoryError,
                urllib.error.URLError,
                http.client.InvalidURL,
                http.client.BadStatusLine,
                http.client.IncompleteRead,
                ConnectionResetError,
            ) as e:
                logging.debug("   ***> [%-30s] ~FRFetch failed: %s." % (self.feed.log_title[:30], e))
                return FEED_ERRHTTP, None

        logging.debug(
            "   ---> [%-30s] ~FYFeed fetch in ~FM%.4ss" % (self.feed.log_title[:30], time.time() - start)
        )

        return FEED_OK, self.fpf

    def get_identity(self):
        identity = "X"

        current_process = multiprocessing.current_process()
        if current_process._identity:
            identity = current_process._identity[0]

        return identity

    def fetch_twitter(self, address=None):
        twitter_fetcher = TwitterFetcher(self.feed, self.options)
        return twitter_fetcher.fetch(address)

    def fetch_facebook(self):
        facebook_fetcher = FacebookFetcher(self.feed, self.options)
        return facebook_fetcher.fetch()

    def fetch_json_feed(self, address, headers):
        json_fetcher = JSONFetcher(self.feed, self.options)
        return json_fetcher.fetch(address, headers)

    def fetch_youtube(self):
        youtube_fetcher = YoutubeFetcher(self.feed, self.options)
        return youtube_fetcher.fetch()

    def fetch_scrapingbee(self, js_scrape=False):
        url = "https://app.scrapingbee.com/api/v1"
        params = {
            "api_key": settings.SCRAPINGBEE_API_KEY,
            "url": self.feed.feed_address,
            "render_js": "true" if js_scrape else "false",
            "return_page_source": "true",
        }

        # Add etag and last-modified headers for conditional requests
        # ScrapingBee requires spb- prefix and forward_headers enabled
        headers = {}
        if self.feed.etag or self.feed.last_modified:
            params["forward_headers"] = "true"

        if self.feed.etag:
            headers["spb-etag"] = self.feed.etag
        if self.feed.last_modified:
            modified = self.feed.last_modified.utctimetuple()[:7]
            short_weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            modified_header = "%s, %02d %s %04d %02d:%02d:%02d GMT" % (
                short_weekdays[modified[6]],
                modified[2],
                months[modified[1] - 1],
                modified[0],
                modified[3],
                modified[4],
                modified[5],
            )
            headers["spb-last-modified"] = modified_header

        logging.debug(
            "   ***> [%-30s] ~FRForbidden feed fetch with ScrapingBee%s: %s"
            % (self.feed.log_title[:30], " (JS enabled)" if js_scrape else "", self.feed.feed_address)
        )

        try:
            response = requests.get(url, params=params, headers=headers, timeout=15)

            if response.status_code == 304:
                logging.debug(
                    "   ***> [%-30s] ~FGScrapingBee returned 304 Not Modified"
                    % (self.feed.log_title[:30],)
                )
                return response.status_code, None

            if response.status_code != 200:
                logging.debug(
                    "   ***> [%-30s] ~FRScrapingBee fetch failed with status %s"
                    % (self.feed.log_title[:30], response.status_code)
                )
                return response.status_code, None

            body = smart_str(response.content)
            if not body:
                logging.debug(
                    "   ***> [%-30s] ~FRScrapingBee fetch failed: empty response" % (self.feed.log_title[:30],)
                )
                return response.status_code, None

            logging.debug(
                "   ***> [%-30s] ~FGScrapingBee fetch succeeded: %s bytes"
                % (self.feed.log_title[:30], len(body))
            )
            return response.status_code, body
        except Exception as e:
            logging.debug(
                "   ***> [%-30s] ~FRScrapingBee fetch error: %s" % (self.feed.log_title[:30], str(e))
            )
            return None, None

    def fetch_scrapeninja(self, js_scrape=False):
        url = "https://scrapeninja.p.rapidapi.com/scrape"
        if js_scrape:
            url = "https://scrapeninja.p.rapidapi.com/scrape-js"

        payload = {"url": self.feed.feed_address}

        # Add custom headers for conditional requests
        custom_headers = {}
        if self.feed.etag:
            custom_headers["If-None-Match"] = self.feed.etag
        if self.feed.last_modified:
            modified = self.feed.last_modified.utctimetuple()[:7]
            short_weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            modified_header = "%s, %02d %s %04d %02d:%02d:%02d GMT" % (
                short_weekdays[modified[6]],
                modified[2],
                months[modified[1] - 1],
                modified[0],
                modified[3],
                modified[4],
                modified[5],
            )
            custom_headers["If-Modified-Since"] = modified_header

        if custom_headers:
            payload["customHeaders"] = custom_headers

        headers = {
            "x-rapidapi-key": settings.SCRAPENINJA_API_KEY,
            "x-rapidapi-host": "scrapeninja.p.rapidapi.com",
            "Content-Type": "application/json",
        }
        logging.debug(
            "   ***> [%-30s] ~FRForbidden feed fetch with ScrapeNinja: %s -> %s"
            % (self.feed.log_title[:30], url, payload)
        )

        try:
            response = requests.post(url, json=payload, headers=headers, timeout=15)

            if response.status_code == 304:
                logging.debug(
                    "   ***> [%-30s] ~FGScrapeNinja returned 304 Not Modified" % (self.feed.log_title[:30],)
                )
                return response.status_code, None

            if response.status_code != 200:
                logging.debug(
                    "   ***> [%-30s] ~FRScrapeNinja fetch failed with status %s"
                    % (self.feed.log_title[:30], response.status_code)
                )
                return response.status_code, None

            body = response.json().get("body")
            if not body:
                logging.debug(
                    "   ***> [%-30s] ~FRScrapeNinja fetch failed: empty body in response"
                    % (self.feed.log_title[:30],)
                )
                return response.status_code, None

            if "enable JS" in body and not js_scrape:
                logging.debug(
                    "   ***> [%-30s] ~FYScrapeNinja requires JS, retrying with JS enabled"
                    % (self.feed.log_title[:30],)
                )
                return self.fetch_scrapeninja(js_scrape=True)

            logging.debug(
                "   ***> [%-30s] ~FGScrapeNinja fetch succeeded: %s bytes"
                % (self.feed.log_title[:30], len(body))
            )
            return response.status_code, body
        except Exception as e:
            logging.debug(
                "   ***> [%-30s] ~FRScrapeNinja fetch error: %s" % (self.feed.log_title[:30], str(e))
            )
            return None, None

    def fetch_forbidden(self, js_scrape=False):
        # Try ScrapingBee first
        status_code, body = self.fetch_scrapingbee(js_scrape=js_scrape)
        if status_code and (body or status_code == 304):
            return status_code, body

        # If ScrapingBee fails, try ScrapeNinja
        logging.debug(
            "   ***> [%-30s] ~FYScrapingBee failed, trying ScrapeNinja" % (self.feed.log_title[:30],)
        )

        return self.fetch_scrapeninja(js_scrape=js_scrape)


class ProcessFeed:
    def __init__(self, feed_id, fpf, options, raw_feed=None):
        self.feed_id = feed_id
        self.options = options
        self.fpf = fpf
        self.raw_feed = raw_feed
        self.feed_entries = []
        self.archive_seen_story_hashes = set()
        self.cache_control_max_age = None

    def refresh_feed(self):
        self.feed = Feed.get_by_id(self.feed_id)
        if self.feed_id != self.feed.pk:
            logging.debug(" ***> Feed has changed: from %s to %s" % (self.feed_id, self.feed.pk))
            self.feed_id = self.feed.pk

    def process(self):
        """Downloads and parses a feed."""
        start = time.time()
        self.refresh_feed()

        if not self.options.get("archive_page", None):
            feed_status, ret_values = self.verify_feed_integrity()
            if feed_status and ret_values:
                return feed_status, ret_values

            # Check for Cache-Control max-age and Retry-After in response headers
            if hasattr(self.fpf, "headers") and self.fpf.headers:
                # Check Cache-Control header
                cache_control = self.fpf.headers.get("Cache-Control")
                if cache_control:
                    max_age_match = re.search(r"max-age=(\d+)", cache_control)
                    if max_age_match:
                        self.cache_control_max_age = (
                            int(max_age_match.group(1)) / 60
                        )  # Convert seconds to minutes

                # Check Retry-After header
                retry_after = self.fpf.headers.get("Retry-After")
                if retry_after:
                    try:
                        # Retry-After can be seconds (integer) or HTTP-date
                        retry_seconds = int(retry_after)
                        retry_minutes = retry_seconds / 60
                        # Use retry-after if it's longer than cache-control (or if cache-control is not set)
                        if self.cache_control_max_age is None or retry_minutes > self.cache_control_max_age:
                            self.cache_control_max_age = retry_minutes
                            logging.debug(
                                f"   ---> [{self.feed.log_title[:30]:<30}] ~FYUsing Retry-After header: ~SB{retry_seconds} seconds ({retry_minutes:.1f} minutes)"
                            )
                    except ValueError:
                        # If it's not an integer, it might be an HTTP-date - skip for now
                        logging.debug(
                            f"   ---> [{self.feed.log_title[:30]:<30}] ~FRCouldn't parse Retry-After header: {retry_after}"
                        )

        self.feed_entries = self.fpf.entries

        # Check if this is a high-volume feed that can handle more stories
        max_entries = MAX_ENTRIES_TO_PROCESS
        feed_address_lower = self.feed.feed_address.lower()
        for high_volume_url in HIGH_VOLUME_FEED_URLS:
            if high_volume_url in feed_address_lower:
                max_entries = MAX_ENTRIES_HIGH_VOLUME
                logging.debug(
                    f"   ---> [{self.feed.log_title[:30]:<30}] High-volume feed detected ({high_volume_url}), allowing up to {max_entries} stories"
                )
                break

        # If there are more than max_entries, we should sort the entries in date descending order and cut them off
        if len(self.feed_entries) > max_entries:
            self.feed_entries = sorted(self.feed_entries, key=lambda x: extract_story_date(x), reverse=True)[
                :max_entries
            ]

        if not self.options.get("archive_page", None):
            self.compare_feed_attribute_changes()

        # Determine if stories aren't valid and replace broken guids
        guids_seen = set()
        permalinks_seen = set()
        for entry in self.feed_entries:
            guids_seen.add(entry.get("guid"))
            permalinks_seen.add(Feed.get_permalink(entry))
        guid_difference = len(guids_seen) != len(self.feed_entries)
        single_guid = len(guids_seen) == 1
        replace_guids = single_guid and guid_difference
        permalink_difference = len(permalinks_seen) != len(self.feed_entries)
        single_permalink = len(permalinks_seen) == 1
        replace_permalinks = single_permalink and permalink_difference

        # Compare new stories to existing stories, adding and updating
        start_date = datetime.datetime.utcnow()
        day_ago = datetime.datetime.now() - datetime.timedelta(days=1)
        story_hashes = []
        stories = []
        for entry in self.feed_entries:
            story = pre_process_story(entry, self.fpf.encoding)
            if not story["title"] and not story["story_content"]:
                continue
            if self.options.get("archive_page", None) and story.get("published") > day_ago:
                # Archive only: Arbitrary but necessary to prevent feeds from creating an unlimited number of stories
                # because they don't have a guid so it gets auto-generated based on the date, and if the story
                # is missing a date, then the latest date gets used. So reject anything newer than 24 hours old
                # when filling out the archive.
                # logging.debug(f"   ---> [%-30s] ~FBTossing story because it's too new for the archive: ~SB{story}")
                continue
            if story.get("published") < start_date:
                start_date = story.get("published")
            if replace_guids:
                if replace_permalinks:
                    new_story_guid = str(story.get("published"))
                    if self.options["verbose"]:
                        logging.debug(
                            "   ---> [%-30s] ~FBReplacing guid (%s) with timestamp: %s"
                            % (self.feed.log_title[:30], story.get("guid"), new_story_guid)
                        )
                    story["guid"] = new_story_guid
                else:
                    new_story_guid = Feed.get_permalink(story)
                    if self.options["verbose"]:
                        logging.debug(
                            "   ---> [%-30s] ~FBReplacing guid (%s) with permalink: %s"
                            % (self.feed.log_title[:30], story.get("guid"), new_story_guid)
                        )
                    story["guid"] = new_story_guid
            story["story_hash"] = MStory.feed_guid_hash_unsaved(self.feed.pk, story.get("guid"))
            stories.append(story)
            story_hashes.append(story.get("story_hash"))

        original_story_hash_count = len(story_hashes)
        story_hashes_in_unread_cutoff = self.feed.story_hashes_in_unread_cutoff[:original_story_hash_count]
        story_hashes.extend(story_hashes_in_unread_cutoff)
        story_hashes = list(set(story_hashes))
        if self.options["verbose"] or settings.DEBUG:
            logging.debug(
                "   ---> [%-30s] ~FBFound ~SB%s~SN guids, adding ~SB%s~SN/%s guids from db"
                % (
                    self.feed.log_title[:30],
                    original_story_hash_count,
                    len(story_hashes) - original_story_hash_count,
                    len(story_hashes_in_unread_cutoff),
                )
            )

        existing_stories = dict(
            (s.story_hash, s)
            for s in MStory.objects(
                story_hash__in=story_hashes,
                # story_date__gte=start_date,
                # story_feed_id=self.feed.pk
            )
        )
        # if len(existing_stories) == 0:
        #     existing_stories = dict((s.story_hash, s) for s in MStory.objects(
        #         story_date__gte=start_date,
        #         story_feed_id=self.feed.pk
        #     ))

        ret_values = self.feed.add_update_stories(
            stories,
            existing_stories,
            verbose=self.options["verbose"],
            updates_off=self.options["updates_off"],
        )

        # PubSubHubbub
        if not self.options.get("archive_page", None):
            self.check_feed_for_push()

        # Push notifications
        if ret_values["new"] > 0 and MUserFeedNotification.feed_has_users(self.feed.pk) > 0:
            QueueNotifications.delay(self.feed.pk, ret_values["new"])

        # All Done
        logging.debug(
            "   ---> [%-30s] ~FYParsed Feed: %snew=%s~SN~FY %sup=%s~SN same=%s%s~SN %serr=%s~SN~FY total=~SB%s"
            % (
                self.feed.log_title[:30],
                "~FG~SB" if ret_values["new"] else "",
                ret_values["new"],
                "~FY~SB" if ret_values["updated"] else "",
                ret_values["updated"],
                "~SB" if ret_values["same"] else "",
                ret_values["same"],
                "~FR~SB" if ret_values["error"] else "",
                ret_values["error"],
                len(self.feed_entries),
            )
        )
        if self.cache_control_max_age:
            logging.debug(
                f"   ---> [{self.feed.log_title[:30]:<30}] ~FYScheduling next fetch with delay: ~SB{self.cache_control_max_age:.1f} minutes"
            )
        self.feed.update_all_statistics(
            has_new_stories=bool(ret_values["new"]),
            force=self.options["force"],
            delay_fetch_sec=self.cache_control_max_age * 60 if self.cache_control_max_age else None,
        )
        fetch_date = datetime.datetime.now()
        if ret_values["new"]:
            if not getattr(settings, "TEST_DEBUG", False):
                self.feed.trim_feed()
                self.feed.expire_redis()
            if MStatistics.get("raw_feed", None) == self.feed.pk:
                self.feed.save_raw_feed(self.raw_feed, fetch_date)
        self.feed.save_feed_history(200, "OK", date=fetch_date)

        if self.options["verbose"]:
            logging.debug(
                "   ---> [%-30s] ~FBTIME: feed parse in ~FM%.4ss"
                % (self.feed.log_title[:30], time.time() - start)
            )

        if self.options.get("archive_page", None):
            self.archive_seen_story_hashes.update(story_hashes)

        return FEED_OK, ret_values

    def verify_feed_integrity(self):
        """Ensures stories come through and any abberant status codes get saved

        Returns:
            FEED_STATUS: enum
            ret_values: dictionary of counts of new, updated, same, and error stories
        """
        ret_values = dict(new=0, updated=0, same=0, error=0)

        if not self.feed:
            return FEED_ERREXC, ret_values

        if hasattr(self.fpf, "status"):
            if self.options["verbose"]:
                if self.fpf.bozo and self.fpf.status != 304:
                    logging.debug(
                        "   ---> [%-30s] ~FRBOZO exception: %s ~SB(%s entries)"
                        % (self.feed.log_title[:30], self.fpf.bozo_exception, len(self.feed_entries))
                    )

            if self.fpf.status == 304:
                self.feed = self.feed.save()
                self.feed.save_feed_history(304, "Not modified")
                return FEED_SAME, ret_values

            # 302 and 307: Temporary redirect: ignore
            # 301 and 308: Permanent redirect: save it (after 10 tries)
            if self.fpf.status == 301 or self.fpf.status == 308:
                if self.fpf.href.endswith("feedburner.com/atom.xml"):
                    return FEED_ERRHTTP, ret_values
                redirects, non_redirects = self.feed.count_redirects_in_history("feed")
                self.feed.save_feed_history(
                    self.fpf.status, "HTTP Redirect (%d to go)" % (10 - len(redirects))
                )
                if len(redirects) >= 10 or len(non_redirects) == 0:
                    address = self.fpf.href
                    if self.options["force"] and address:
                        address = qurl(address, remove=["_"])
                    self.feed.feed_address = strip_underscore_from_feed_address(address)
                if not self.feed.known_good:
                    self.feed.fetched_once = True
                    logging.debug(
                        "   ---> [%-30s] ~SB~SK~FRFeed is %s'ing. Refetching..."
                        % (self.feed.log_title[:30], self.fpf.status)
                    )
                    self.feed = self.feed.schedule_feed_fetch_immediately()
                if not self.feed_entries:
                    self.feed = self.feed.save()
                    self.feed.save_feed_history(self.fpf.status, "HTTP Redirect")
                    return FEED_ERRHTTP, ret_values
            if self.fpf.status >= 400:
                logging.debug(
                    "   ---> [%-30s] ~SB~FRHTTP Status code: %s. Checking address..."
                    % (self.feed.log_title[:30], self.fpf.status)
                )
                if self.fpf.status in [403] and not self.feed.is_forbidden:
                    self.feed = self.feed.set_is_forbidden()
                fixed_feed = None
                if not self.feed.known_good:
                    fixed_feed, feed = self.feed.check_feed_link_for_feed_address()
                if not fixed_feed:
                    self.feed.save_feed_history(self.fpf.status, "HTTP Error")
                else:
                    self.feed = feed
                self.feed = self.feed.save()
                return FEED_ERRHTTP, ret_values

        if not self.fpf:
            logging.debug(
                "   ---> [%-30s] ~SB~FRFeed is Non-XML. No feedparser feed either!"
                % (self.feed.log_title[:30])
            )
            self.feed.save_feed_history(551, "Broken feed")
            return FEED_ERRHTTP, ret_values

        if self.fpf and not self.fpf.entries:
            if self.fpf.bozo and isinstance(self.fpf.bozo_exception, feedparser.NonXMLContentType):
                logging.debug(
                    "   ---> [%-30s] ~SB~FRFeed is Non-XML. %s entries. Checking address..."
                    % (self.feed.log_title[:30], len(self.fpf.entries))
                )
                fixed_feed = None
                if not self.feed.known_good:
                    fixed_feed, feed = self.feed.check_feed_link_for_feed_address()
                if not fixed_feed:
                    self.feed.save_feed_history(552, "Non-xml feed", self.fpf.bozo_exception)
                else:
                    self.feed = feed
                self.feed = self.feed.save()
                return FEED_ERRPARSE, ret_values
            elif self.fpf.bozo and isinstance(self.fpf.bozo_exception, xml.sax._exceptions.SAXException):
                logging.debug(
                    "   ---> [%-30s] ~SB~FRFeed has SAX/XML parsing issues. %s entries. Checking address..."
                    % (self.feed.log_title[:30], len(self.fpf.entries))
                )
                fixed_feed = None
                if not self.feed.known_good:
                    fixed_feed, feed = self.feed.check_feed_link_for_feed_address()
                if not fixed_feed:
                    self.feed.save_feed_history(553, "Not an RSS feed", self.fpf.bozo_exception)
                    if not self.feed.is_forbidden:
                        self.feed = self.feed.set_is_forbidden()
                else:
                    self.feed = feed
                self.feed = self.feed.save()
                return FEED_ERRPARSE, ret_values
        return None, None

    def compare_feed_attribute_changes(self):
        """
        The feed has changed (or it is the first time we parse it)
        saving the etag and last_modified fields
        """
        if not self.feed:
            logging.debug(f"Missing feed: {self.feed}")
            return

        original_etag = self.feed.etag
        self.feed.etag = self.fpf.get("etag")
        if self.feed.etag:
            self.feed.etag = self.feed.etag[:255]
        # some times this is None (it never should) *sigh*
        if self.feed.etag is None:
            self.feed.etag = ""
        if self.feed.etag != original_etag:
            self.feed.save(update_fields=["etag"])

        original_last_modified = self.feed.last_modified
        if hasattr(self.fpf, "modified") and self.fpf.modified:
            try:
                self.feed.last_modified = datetime.datetime.strptime(
                    self.fpf.modified, "%a, %d %b %Y %H:%M:%S %Z"
                )
            except Exception as e:
                self.feed.last_modified = None
                logging.debug("Broken mtime %s: %s" % (self.feed.last_modified, e))
                pass
        if self.feed.last_modified != original_last_modified:
            self.feed.save(update_fields=["last_modified"])

        original_title = self.feed.feed_title
        if self.fpf.feed.get("title"):
            self.feed.feed_title = strip_tags(self.fpf.feed.get("title"))
        if self.feed.feed_title != original_title:
            self.feed.save(update_fields=["feed_title"])

        tagline = self.fpf.feed.get("tagline", self.feed.data.feed_tagline)
        if tagline:
            original_tagline = self.feed.data.feed_tagline
            self.feed.data.feed_tagline = smart_str(tagline)
            if self.feed.data.feed_tagline != original_tagline:
                self.feed.data.save(update_fields=["feed_tagline"])

        if not self.feed.feed_link_locked:
            new_feed_link = self.fpf.feed.get("link") or self.fpf.feed.get("id") or self.feed.feed_link
            if self.options["force"] and new_feed_link:
                new_feed_link = qurl(new_feed_link, remove=["_"])
            if new_feed_link != self.feed.feed_link:
                logging.debug(
                    "   ---> [%-30s] ~SB~FRFeed's page is different: %s to %s"
                    % (self.feed.log_title[:30], self.feed.feed_link, new_feed_link)
                )
                redirects, non_redirects = self.feed.count_redirects_in_history("page")
                self.feed.save_page_history(301, "HTTP Redirect (%s to go)" % (10 - len(redirects)))
                if len(redirects) >= 10 or len(non_redirects) == 0:
                    self.feed.feed_link = new_feed_link
                    self.feed.save(update_fields=["feed_link"])

    def check_feed_for_push(self):
        if not (hasattr(self.fpf, "feed") and hasattr(self.fpf.feed, "links") and self.fpf.feed.links):
            return

        hub_url = None
        self_url = self.feed.feed_address
        for link in self.fpf.feed.links:
            if link["rel"] == "hub" and not hub_url:
                hub_url = link["href"]
            elif link["rel"] == "self":
                self_url = link["href"]
        if not hub_url and "youtube.com" in self_url:
            hub_url = "https://pubsubhubbub.appspot.com/subscribe"
            channel_id = self_url.split("channel_id=")
            if len(channel_id) > 1:
                self_url = f"https://www.youtube.com/feeds/videos.xml?channel_id={channel_id[1]}"
        push_expired = False
        if self.feed.is_push:
            try:
                push_expired = self.feed.push.lease_expires < datetime.datetime.now()
            except PushSubscription.DoesNotExist:
                self.feed.is_push = False
        if (
            hub_url
            and self_url
            and not settings.DEBUG
            and self.feed.active_subscribers > 0
            and (push_expired or not self.feed.is_push or self.options.get("force"))
        ):
            logging.debug(
                "   ---> [%-30s] ~BB~FW%sSubscribing to PuSH hub: %s"
                % (self.feed.log_title[:30], "~SKRe-~SN" if push_expired else "", hub_url)
            )
            try:
                if settings.ENABLE_PUSH:
                    PushSubscription.objects.subscribe(self_url, feed=self.feed, hub=hub_url)
            except TimeoutError:
                logging.debug(
                    "   ---> [%-30s] ~BB~FW~FRTimed out~FW subscribing to PuSH hub: %s"
                    % (self.feed.log_title[:30], hub_url)
                )
        elif self.feed.is_push and (self.feed.active_subscribers <= 0 or not hub_url):
            logging.debug("   ---> [%-30s] ~BB~FWTurning off PuSH, no hub found" % (self.feed.log_title[:30]))
            self.feed.is_push = False
            self.feed = self.feed.save()


class FeedFetcherWorker:
    def __init__(self, options):
        self.options = options
        self.feed_stats = {
            FEED_OK: 0,
            FEED_SAME: 0,
            FEED_ERRPARSE: 0,
            FEED_ERRHTTP: 0,
            FEED_ERREXC: 0,
        }
        self.feed_trans = {
            FEED_OK: "ok",
            FEED_SAME: "unchanged",
            FEED_ERRPARSE: "cant_parse",
            FEED_ERRHTTP: "http_error",
            FEED_ERREXC: "exception",
        }
        self.feed_keys = sorted(self.feed_trans.keys())
        self.time_start = datetime.datetime.utcnow()

    def refresh_feed(self, feed_id):
        """Update feed, since it may have changed"""
        return Feed.get_by_id(feed_id)

    def reset_database_connections(self):
        connection._connections = {}
        connection._connection_settings = {}
        connection._dbs = {}
        settings.MONGODB = connect(settings.MONGO_DB_NAME, **settings.MONGO_DB)
        if "username" in settings.MONGO_ANALYTICS_DB:
            settings.MONGOANALYTICSDB = connect(
                db=settings.MONGO_ANALYTICS_DB["name"],
                host=f"mongodb://{settings.MONGO_ANALYTICS_DB['username']}:{settings.MONGO_ANALYTICS_DB['password']}@{settings.MONGO_ANALYTICS_DB['host']}/?authSource=admin",
                alias="nbanalytics",
            )
        else:
            settings.MONGOANALYTICSDB = connect(
                db=settings.MONGO_ANALYTICS_DB["name"],
                host=f"mongodb://{settings.MONGO_ANALYTICS_DB['host']}/",
                alias="nbanalytics",
            )

    def process_feed_wrapper(self, feed_queue):
        self.reset_database_connections()

        delta = None
        current_process = multiprocessing.current_process()
        identity = "X"
        feed = None

        if current_process._identity:
            identity = current_process._identity[0]

        # If fetching archive pages, come back once the archive scaffolding is built
        if self.options.get("archive_page", None):
            for feed_id in feed_queue:
                feed = self.refresh_feed(feed_id)
                try:
                    self.fetch_and_process_archive_pages(feed_id)
                except SoftTimeLimitExceeded:
                    logging.debug(
                        "   ---> [%-30s] ~FRTime limit reached while fetching ~FGarchive pages~FR. Made it to ~SB%s"
                        % (feed.log_title[:30], self.options["archive_page"])
                    )
                    pass
            if len(feed_queue) == 1:
                feed = self.refresh_feed(feed_queue[0])
                return feed
            return

        for feed_id in feed_queue:
            start_duration = time.time()
            feed_fetch_duration = None
            feed_process_duration = None
            page_duration = None
            icon_duration = None
            feed_code = None
            ret_entries = None
            start_time = time.time()
            ret_feed = FEED_ERREXC

            set_user({"id": feed_id})
            try:
                feed = self.refresh_feed(feed_id)
                set_user({"id": feed_id, "username": feed.feed_title})

                skip = False
                weight = "-"
                quick = "-"
                rand = "-"
                if self.options.get("fake"):
                    skip = True
                elif (
                    self.options.get("quick")
                    and not self.options["force"]
                    and feed.known_good
                    and feed.fetched_once
                    and not feed.is_push
                ):
                    weight = feed.stories_last_month * feed.num_subscribers
                    random_weight = random.randint(1, max(weight, 1))
                    quick = float(self.options.get("quick", 0))
                    rand = random.random()
                    if random_weight < 1000 and rand < quick:
                        skip = True
                elif False and feed.feed_address.startswith("http://news.google.com/news"):
                    skip = True

                # Check for openrss.org rate limiting
                if not skip and "openrss.org" in feed.feed_address and not self.options.get("force"):
                    r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
                    current_timestamp = int(time.time())
                    openrss_key = f"openrss_fetch:{current_timestamp}"

                    # Try to set the key with 5 minutes expiration, only if it doesn't exist
                    was_set = r.set(openrss_key, 1, nx=True, ex=300)

                    if not was_set:
                        # Another openrss.org feed was fetched in this same second
                        skip = True
                        logging.debug(
                            f"   ---> [{feed.log_title[:30]:<30}] ~FYSkipping openrss.org fetch, another openrss feed fetched in last second"
                        )
                    else:
                        logging.debug(
                            f"   ---> [{feed.log_title[:30]:<30}] ~FGProceeding with openrss.org fetch"
                        )

                if skip:
                    logging.debug(
                        "   ---> [%-30s] ~BGFaking fetch, skipping (%s/month, %s subs, %s < %s)..."
                        % (feed.log_title[:30], weight, feed.num_subscribers, rand, quick)
                    )
                    continue

                ffeed = FetchFeed(feed_id, self.options)
                ret_feed, fetched_feed = ffeed.fetch()

                feed_fetch_duration = time.time() - start_duration
                raw_feed = ffeed.raw_feed

                if fetched_feed and (ret_feed == FEED_OK or self.options["force"]):
                    pfeed = ProcessFeed(feed_id, fetched_feed, self.options, raw_feed=raw_feed)
                    ret_feed, ret_entries = pfeed.process()
                    feed = pfeed.feed
                    feed_process_duration = time.time() - start_duration

                    if (ret_entries and ret_entries["new"]) or self.options["force"]:
                        start = time.time()
                        if not feed.known_good or not feed.fetched_once:
                            feed.known_good = True
                            feed.fetched_once = True
                            feed = feed.save()
                        if self.options["force"] or random.random() <= 0.02:
                            logging.debug(
                                "   ---> [%-30s] ~FBPerforming feed cleanup..." % (feed.log_title[:30],)
                            )
                            start_cleanup = time.time()
                            feed.count_fs_size_bytes()
                            logging.debug(
                                "   ---> [%-30s] ~FBDone with feed cleanup. Took ~SB%.4s~SN sec."
                                % (feed.log_title[:30], time.time() - start_cleanup)
                            )
                        try:
                            self.count_unreads_for_subscribers(feed)
                        except TimeoutError:
                            logging.debug(
                                "   ---> [%-30s] Unread count took too long..." % (feed.log_title[:30],)
                            )
                        if self.options["verbose"]:
                            logging.debug(
                                "   ---> [%-30s] ~FBTIME: unread count in ~FM%.4ss"
                                % (feed.log_title[:30], time.time() - start)
                            )
            except (urllib.error.HTTPError, urllib.error.URLError) as e:
                logging.debug(
                    "   ---> [%-30s] ~FRFeed throws HTTP error: ~SB%s" % (str(feed_id)[:30], e.reason)
                )
                feed_code = 404
                feed.save_feed_history(feed_code, str(e.reason), e)
                fetched_feed = None
            except Feed.DoesNotExist:
                logging.debug("   ---> [%-30s] ~FRFeed is now gone..." % (str(feed_id)[:30]))
                continue
            except SoftTimeLimitExceeded as e:
                logging.debug(" ---> [%-30s] ~BR~FWTime limit hit!~SB~FR Moving on to next feed..." % feed)
                ret_feed = FEED_ERREXC
                fetched_feed = None
                feed_code = 559
                feed.save_feed_history(feed_code, "Timeout", e)
            except TimeoutError as e:
                logging.debug("   ---> [%-30s] ~FRFeed fetch timed out..." % (feed.log_title[:30]))
                feed_code = 505
                feed.save_feed_history(feed_code, "Timeout", e)
                fetched_feed = None
            except Exception as e:
                logging.debug("[%d] ! -------------------------" % (feed_id,))
                tb = traceback.format_exc()
                logging.error(tb)
                logging.debug("[%d] ! -------------------------" % (feed_id,))
                ret_feed = FEED_ERREXC
                feed = Feed.get_by_id(getattr(feed, "pk", feed_id))
                if not feed:
                    continue
                feed.save_feed_history(500, "Error", tb)
                feed_code = 500
                fetched_feed = None
                # mail_feed_error_to_admin(feed, e, local_vars=locals())
                if not settings.DEBUG and hasattr(settings, "SENTRY_DSN") and settings.SENTRY_DSN:
                    capture_exception(e)
                    flush()

            if not feed_code:
                if ret_feed == FEED_OK:
                    feed_code = 200
                elif ret_feed == FEED_SAME:
                    feed_code = 304
                elif ret_feed == FEED_ERRHTTP:
                    feed_code = 400
                if ret_feed == FEED_ERREXC:
                    feed_code = 500
                elif ret_feed == FEED_ERRPARSE:
                    feed_code = 550

            if not feed:
                continue
            feed = self.refresh_feed(feed.pk)
            if not feed:
                continue

            if (
                (self.options["force"])
                or (random.random() > 0.9)
                or (
                    fetched_feed
                    and feed.feed_link
                    and feed.has_page
                    and (ret_feed == FEED_OK or (ret_feed == FEED_SAME and feed.stories_last_month > 10))
                )
            ):
                logging.debug("   ---> [%-30s] ~FYFetching page: %s" % (feed.log_title[:30], feed.feed_link))
                page_importer = PageImporter(feed)
                try:
                    page_data = page_importer.fetch_page()
                    page_duration = time.time() - start_duration
                except SoftTimeLimitExceeded as e:
                    logging.debug(
                        " ---> [%-30s] ~BR~FWTime limit hit!~SB~FR Moving on to next feed..." % feed
                    )
                    page_data = None
                    feed.save_feed_history(557, "Timeout", e)
                except TimeoutError:
                    logging.debug("   ---> [%-30s] ~FRPage fetch timed out..." % (feed.log_title[:30]))
                    page_data = None
                    feed.save_page_history(555, "Timeout", "")
                except Exception as e:
                    logging.debug("[%d] ! -------------------------" % (feed_id,))
                    tb = traceback.format_exc()
                    logging.error(tb)
                    logging.debug("[%d] ! -------------------------" % (feed_id,))
                    feed.save_page_history(550, "Page Error", tb)
                    fetched_feed = None
                    page_data = None
                    # mail_feed_error_to_admin(feed, e, local_vars=locals())
                    if not settings.DEBUG and hasattr(settings, "SENTRY_DSN") and settings.SENTRY_DSN:
                        capture_exception(e)
                        flush()

                feed = self.refresh_feed(feed.pk)
                logging.debug("   ---> [%-30s] ~FYFetching icon: %s" % (feed.log_title[:30], feed.feed_link))
                force = self.options["force"]
                if random.random() > 0.99:
                    force = True
                icon_importer = IconImporter(feed, page_data=page_data, force=force)
                try:
                    icon_importer.save()
                    icon_duration = time.time() - start_duration
                except SoftTimeLimitExceeded as e:
                    logging.debug(
                        " ---> [%-30s] ~BR~FWTime limit hit!~SB~FR Moving on to next feed..." % feed
                    )
                    feed.save_feed_history(558, "Timeout", e)
                except TimeoutError:
                    logging.debug("   ---> [%-30s] ~FRIcon fetch timed out..." % (feed.log_title[:30]))
                    feed.save_page_history(556, "Timeout", "")
                except Exception as e:
                    logging.debug("[%d] ! -------------------------" % (feed_id,))
                    tb = traceback.format_exc()
                    logging.error(tb)
                    logging.debug("[%d] ! -------------------------" % (feed_id,))
                    # feed.save_feed_history(560, "Icon Error", tb)
                    # mail_feed_error_to_admin(feed, e, local_vars=locals())
                    if not settings.DEBUG and hasattr(settings, "SENTRY_DSN") and settings.SENTRY_DSN:
                        capture_exception(e)
                        flush()
            else:
                logging.debug(
                    "   ---> [%-30s] ~FBSkipping page fetch: (%s on %s stories) %s"
                    % (
                        feed.log_title[:30],
                        self.feed_trans[ret_feed],
                        feed.stories_last_month,
                        "" if feed.has_page else " [HAS NO PAGE]",
                    )
                )

            feed = self.refresh_feed(feed.pk)
            delta = time.time() - start_time

            feed.last_load_time = round(delta)
            feed.fetched_once = True
            try:
                feed = feed.save(update_fields=["last_load_time", "fetched_once"])
            except IntegrityError:
                logging.debug(
                    "   ***> [%-30s] ~FRIntegrityError on feed: %s"
                    % (
                        feed.log_title[:30],
                        feed.feed_address,
                    )
                )

            if ret_entries and ret_entries["new"]:
                self.publish_to_subscribers(feed, ret_entries["new"])

            done_msg = "%2s ---> [%-30s] ~FYProcessed in ~FM~SB%.4ss~FY~SN (~FB%s~FY) [%s]" % (
                identity,
                feed.log_title[:30],
                delta,
                feed.pk,
                self.feed_trans[ret_feed],
            )
            logging.debug(done_msg)
            total_duration = time.time() - start_duration
            MAnalyticsFetcher.add(
                feed_id=feed.pk,
                feed_fetch=feed_fetch_duration,
                feed_process=feed_process_duration,
                page=page_duration,
                icon=icon_duration,
                total=total_duration,
                feed_code=feed_code,
            )

            self.feed_stats[ret_feed] += 1

        if len(feed_queue) == 1:
            return feed

        # time_taken = datetime.datetime.utcnow() - self.time_start

    def fetch_and_process_archive_pages(self, feed_id):
        feed = Feed.get_by_id(feed_id)
        first_seen_feed = None
        original_starting_page = self.options["archive_page"]

        for archive_page_key in ["page", "paged", "rfc5005"]:
            seen_story_hashes = set()
            failed_pages = 0
            self.options["archive_page_key"] = archive_page_key

            if archive_page_key == "rfc5005":
                self.options["archive_page"] = "rfc5005"
                link_prev_archive = None
                if first_seen_feed:
                    for link in getattr(first_seen_feed.feed, "links", []):
                        if link["rel"] == "prev-archive" or link["rel"] == "next":
                            link_prev_archive = link["href"]
                            logging.debug(
                                "   ---> [%-30s] ~FGFeed has ~SBRFC5005~SN links, filling out archive: %s"
                                % (feed.log_title[:30], link_prev_archive)
                            )
                            break
                    else:
                        logging.debug(
                            "   ---> [%-30s] ~FBFeed has no RFC5005 links..." % (feed.log_title[:30])
                        )
                else:
                    self.options["archive_page_link"] = link_prev_archive
                    ffeed = FetchFeed(feed_id, self.options)
                    try:
                        ret_feed, fetched_feed = ffeed.fetch()
                    except TimeoutError:
                        logging.debug(
                            "   ---> [%-30s] ~FRArchive feed fetch timed out..." % (feed.log_title[:30])
                        )
                        # Timeout means don't bother to keep checking...
                        continue

                    raw_feed = ffeed.raw_feed

                    if fetched_feed and ret_feed == FEED_OK:
                        pfeed = ProcessFeed(feed_id, fetched_feed, self.options, raw_feed=raw_feed)
                        if not pfeed.fpf or not pfeed.fpf.entries:
                            continue
                        for link in getattr(pfeed.fpf.feed, "links", []):
                            if link["rel"] == "prev-archive" or link["rel"] == "next":
                                link_prev_archive = link["href"]

                if not link_prev_archive:
                    continue

                while True:
                    if not link_prev_archive:
                        break
                    if link_prev_archive == self.options.get("archive_page_link", None):
                        logging.debug(
                            "   ---> [%-30s] ~FRNo change in archive page link: %s"
                            % (feed.log_title[:30], link_prev_archive)
                        )
                        break
                    self.options["archive_page_link"] = link_prev_archive
                    link_prev_archive = None
                    ffeed = FetchFeed(feed_id, self.options)
                    try:
                        ret_feed, fetched_feed = ffeed.fetch()
                    except TimeoutError as e:
                        logging.debug(
                            "   ---> [%-30s] ~FRArchive feed fetch timed out..." % (feed.log_title[:30])
                        )
                        # Timeout means don't bother to keep checking...
                        break

                    raw_feed = ffeed.raw_feed

                    if fetched_feed and ret_feed == FEED_OK:
                        pfeed = ProcessFeed(feed_id, fetched_feed, self.options, raw_feed=raw_feed)
                        if not pfeed.fpf or not pfeed.fpf.entries:
                            logging.debug(
                                "   ---> [%-30s] ~FRFeed parse failed, no entries" % (feed.log_title[:30])
                            )
                            continue
                        for link in getattr(pfeed.fpf.feed, "links", []):
                            if link["rel"] == "prev-archive" or link["rel"] == "next":
                                link_prev_archive = link["href"]
                                logging.debug(
                                    "   ---> [%-30s] ~FGFeed still has ~SBRFC5005~SN links, continuing filling out archive: %s"
                                    % (feed.log_title[:30], link_prev_archive)
                                )
                                break
                        else:
                            logging.debug(
                                "   ---> [%-30s] ~FBFeed has no more RFC5005 links..." % (feed.log_title[:30])
                            )
                            break

                        before_story_hashes = len(seen_story_hashes)
                        pfeed.process()
                        seen_story_hashes.update(pfeed.archive_seen_story_hashes)
                        after_story_hashes = len(seen_story_hashes)

                        if before_story_hashes == after_story_hashes:
                            logging.debug(
                                "   ---> [%-30s] ~FRNo change in story hashes, but has archive link: %s"
                                % (feed.log_title[:30], link_prev_archive)
                            )

                failed_color = "~FR" if not link_prev_archive else ""
                logging.debug(
                    f"   ---> [{feed.log_title[:30]:<30}] ~FGStory hashes found, archive RFC5005 ~SB{link_prev_archive}~SN: ~SB~FG{failed_color}{len(seen_story_hashes):,} stories~SN~FB"
                )
            else:
                for page in range(3 if settings.DEBUG and False else 150):
                    if page < original_starting_page:
                        continue
                    if failed_pages >= 1:
                        break
                    self.options["archive_page"] = page + 1

                    ffeed = FetchFeed(feed_id, self.options)
                    try:
                        ret_feed, fetched_feed = ffeed.fetch()
                    except TimeoutError as e:
                        logging.debug(
                            "   ---> [%-30s] ~FRArchive feed fetch timed out..." % (feed.log_title[:30])
                        )
                        # Timeout means don't bother to keep checking...
                        break

                    raw_feed = ffeed.raw_feed

                    if fetched_feed and ret_feed == FEED_OK:
                        pfeed = ProcessFeed(feed_id, fetched_feed, self.options, raw_feed=raw_feed)
                        if not pfeed.fpf or not pfeed.fpf.entries:
                            failed_pages += 1
                            continue

                        if not first_seen_feed:
                            first_seen_feed = pfeed.fpf
                        before_story_hashes = len(seen_story_hashes)
                        pfeed.process()
                        seen_story_hashes.update(pfeed.archive_seen_story_hashes)
                        after_story_hashes = len(seen_story_hashes)

                        if before_story_hashes == after_story_hashes:
                            failed_pages += 1
                    else:
                        failed_pages += 1
                    failed_color = "~FR" if failed_pages > 0 else ""
                    logging.debug(
                        f"   ---> [{feed.log_title[:30]:<30}] ~FGStory hashes found, archive page ~SB{page+1}~SN: ~SB~FG{len(seen_story_hashes):,} stories~SN~FB, {failed_color}{failed_pages} failures"
                    )

    def publish_to_subscribers(self, feed, new_count):
        try:
            r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
            listeners_count = r.publish(str(feed.pk), "story:new_count:%s" % new_count)
            if listeners_count:
                logging.debug(
                    "   ---> [%-30s] ~FMPublished to %s subscribers" % (feed.log_title[:30], listeners_count)
                )
        except redis.ConnectionError:
            logging.debug("   ***> [%-30s] ~BMRedis is unavailable for real-time." % (feed.log_title[:30],))

    def count_unreads_for_subscribers(self, feed):
        subscriber_expire = datetime.datetime.now() - datetime.timedelta(days=settings.SUBSCRIBER_EXPIRE)

        user_subs = UserSubscription.objects.filter(
            feed=feed, active=True, user__profile__last_seen_on__gte=subscriber_expire
        ).order_by("-last_read_date")

        if not user_subs.count():
            return

        for sub in user_subs:
            if not sub.needs_unread_recalc:
                sub.needs_unread_recalc = True
                sub.save()

        if self.options["compute_scores"]:
            r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
            stories = MStory.objects(story_feed_id=feed.pk, story_date__gte=feed.unread_cutoff)
            stories = Feed.format_stories(stories, feed.pk)
            story_hashes = r.zrangebyscore(
                "zF:%s" % feed.pk,
                int(feed.unread_cutoff.strftime("%s")),
                int(time.time() + 60 * 60 * 24),
            )
            missing_story_hashes = set(story_hashes) - set([s["story_hash"] for s in stories])
            if missing_story_hashes:
                missing_stories = MStory.objects(
                    story_feed_id=feed.pk, story_hash__in=missing_story_hashes
                ).read_preference(pymongo.ReadPreference.PRIMARY)
                missing_stories = Feed.format_stories(missing_stories, feed.pk)
                stories = missing_stories + stories
                logging.debug(
                    "   ---> [%-30s] ~FYFound ~SB~FC%s(of %s)/%s~FY~SN un-secondaried stories while computing scores"
                    % (
                        feed.log_title[:30],
                        len(missing_stories),
                        len(missing_story_hashes),
                        len(stories),
                    )
                )
            cache.set("S:v3:%s" % feed.pk, stories, 60)
            logging.debug(
                "   ---> [%-30s] ~FYComputing scores: ~SB%s stories~SN with ~SB%s subscribers ~SN(%s/%s/%s)"
                % (
                    feed.log_title[:30],
                    len(stories),
                    user_subs.count(),
                    feed.num_subscribers,
                    feed.active_subscribers,
                    feed.premium_subscribers,
                )
            )
            self.calculate_feed_scores_with_stories(user_subs, stories)
        elif self.options.get("mongodb_replication_lag"):
            logging.debug(
                "   ---> [%-30s] ~BR~FYSkipping computing scores: ~SB%s seconds~SN of mongodb lag"
                % (feed.log_title[:30], self.options.get("mongodb_replication_lag"))
            )

    @timelimit(10)
    def calculate_feed_scores_with_stories(self, user_subs, stories):
        for sub in user_subs:
            silent = False if getattr(self.options, "verbose", 0) >= 2 else True
            sub.calculate_feed_scores(silent=silent, stories=stories)


class Dispatcher:
    def __init__(self, options, num_threads):
        self.options = options
        self.num_threads = num_threads
        self.workers = []

    def add_jobs(self, feeds_queue, feeds_count=1):
        """adds a feed processing job to the pool"""
        self.feeds_queue = feeds_queue
        self.feeds_count = feeds_count

    def run_jobs(self):
        if self.options["single_threaded"] or self.num_threads == 1:
            return dispatch_workers(self.feeds_queue[0], self.options)
        else:
            for i in range(self.num_threads):
                feed_queue = self.feeds_queue[i]
                self.workers.append(
                    multiprocessing.Process(target=dispatch_workers, args=(feed_queue, self.options))
                )
            for i in range(self.num_threads):
                self.workers[i].start()


def dispatch_workers(feed_queue, options):
    worker = FeedFetcherWorker(options)
    return worker.process_feed_wrapper(feed_queue)
