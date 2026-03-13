import datetime
from urllib.parse import urlparse

import dateutil.parser
from django.conf import settings
from django.utils import feedgenerator

from utils import log as logging
from utils.json_functions import decode


class JSONFetcher:
    def __init__(self, feed, options=None):
        self.feed = feed
        self.options = options or {}

    def fetch(self, address, raw_feed):
        if not address:
            address = self.feed.feed_address

        json_feed = decode(raw_feed.content)
        if not json_feed:
            logging.debug("   ***> [%-30s] ~FRJSON fetch failed: %s" % (self.feed.log_title[:30], address))
            return

        if self.is_wp_json(json_feed):
            return self.fetch_wp_json(json_feed, address)

        data = {}
        data["title"] = json_feed.get("title", "[Untitled]")
        data["link"] = json_feed.get("home_page_url", "")
        data["description"] = json_feed.get("title", "")
        data["lastBuildDate"] = datetime.datetime.utcnow()
        data["generator"] = "NewsBlur JSON Feed - %s" % settings.NEWSBLUR_URL
        data["docs"] = None
        data["feed_url"] = json_feed.get("feed_url")

        rss = feedgenerator.Atom1Feed(**data)

        for item in json_feed.get("items", []):
            story_data = self.json_feed_story(item)
            rss.add_item(**story_data)

        return rss.writeString("utf-8")

    def is_wp_json(self, json_data):
        """Detect if parsed JSON is a WordPress REST API response."""
        if not isinstance(json_data, list) or not json_data:
            return False
        first = json_data[0]
        return (
            isinstance(first, dict)
            and isinstance(first.get("title"), dict)
            and "rendered" in first["title"]
            and "link" in first
        )

    def fetch_wp_json(self, posts, address):
        """Convert WordPress REST API posts array to Atom feed XML."""
        parsed = urlparse(address)
        site_url = f"{parsed.scheme}://{parsed.netloc}"

        data = {
            "title": parsed.netloc,
            "link": site_url,
            "description": f"WordPress posts from {parsed.netloc}",
            "lastBuildDate": datetime.datetime.utcnow(),
            "generator": "NewsBlur WordPress JSON Feed - %s" % settings.NEWSBLUR_URL,
            "docs": None,
            "feed_url": address,
        }

        rss = feedgenerator.Atom1Feed(**data)

        for post in posts:
            story_data = self.wp_json_story(post)
            rss.add_item(**story_data)

        logging.debug(
            "   ---> [%-30s] ~FGConverted %s WordPress JSON posts to Atom feed"
            % (self.feed.log_title[:30], len(posts))
        )

        return rss.writeString("utf-8")

    def wp_json_story(self, post):
        """Convert a single WordPress REST API post to a feed story dict."""
        date_published = datetime.datetime.now()
        pubdate = post.get("date_gmt") or post.get("date")
        if pubdate:
            date_published = dateutil.parser.parse(pubdate)

        title_obj = post.get("title", {})
        title = title_obj.get("rendered", "") if isinstance(title_obj, dict) else str(title_obj)

        content_obj = post.get("content", {})
        content = content_obj.get("rendered", "") if isinstance(content_obj, dict) else str(content_obj)
        if not content:
            excerpt_obj = post.get("excerpt", {})
            content = excerpt_obj.get("rendered", "") if isinstance(excerpt_obj, dict) else str(excerpt_obj)

        embedded = post.get("_embedded", {})

        # Prepend featured image if available and not already in content
        featured_media = embedded.get("wp:featuredmedia", []) if embedded else []
        if featured_media and isinstance(featured_media, list):
            media = featured_media[0]
            image_url = media.get("source_url", "")
            alt_text = media.get("alt_text", "")
            if image_url and image_url not in content:
                content = f'<img src="{image_url}" alt="{alt_text}" />' + content

        author_name = ""
        if embedded:
            authors = embedded.get("author", [])
            if authors and isinstance(authors, list):
                author_name = authors[0].get("name", "")

        categories = []
        if embedded:
            for term_group in embedded.get("wp:term", []):
                if isinstance(term_group, list):
                    for term in term_group:
                        if isinstance(term, dict) and term.get("name"):
                            categories.append(term["name"])

        return {
            "title": title,
            "link": post.get("link", ""),
            "description": content,
            "author_name": author_name,
            "categories": categories,
            "unique_id": str(post.get("id", post.get("link", ""))),
            "pubdate": date_published,
        }

    def json_feed_story(self, item):
        date_published = datetime.datetime.now()
        pubdate = item.get("date_published") or item.get("date_modified")
        if pubdate:
            date_published = dateutil.parser.parse(pubdate)
        authors = item.get("authors", item.get("author", {}))
        if isinstance(authors, list):
            author_name = ", ".join([author.get("name", "") for author in authors])
        else:
            author_name = authors.get("name", "")
        story = {
            "title": item.get("title", ""),
            "link": item.get("external_url", item.get("url", "")),
            "description": item.get("content_html", item.get("content_text", "")),
            "author_name": author_name,
            "categories": item.get("tags", []),
            "unique_id": str(item.get("id", item.get("url", ""))),
            "pubdate": date_published,
        }

        return story
