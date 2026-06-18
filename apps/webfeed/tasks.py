import hashlib
import json
import re
import time
import uuid
from urllib.parse import urljoin

import redis
import requests
from django.conf import settings
from django.contrib.auth.models import User
from lxml import html as lxml_html

from newsblur_web.celeryapp import app
from utils import log as logging
from utils.llm_costs import LLMCostTracker
from utils.url_safety import UnsafeUrlError, safe_requests_get, validate_public_url

from .prompts import get_analysis_messages

USER_AGENT = "NewsBlur Web Feed Analyzer (https://newsblur.com)"

# Regex to extract URL from CSS background-image: url(...)
_CSS_BG_IMAGE_RE = re.compile(
    r"""background-image\s*:\s*url\(\s*(['"]?)(.*?)\1\s*\)""",
    re.IGNORECASE,
)


def extract_image_url(raw_value):
    """Extract an image URL from a raw XPath result.

    If the value looks like a CSS style string containing background-image: url(...),
    extract and return just the URL. Otherwise return the value as-is.
    """
    if not raw_value:
        return None
    value = raw_value.strip()
    if "background-image" not in value.lower():
        return value
    match = _CSS_BG_IMAGE_RE.search(value)
    return match.group(2).strip() if match else None


def decode_response_text(response):
    """Decode HTTP response text with proper UTF-8 handling.

    The requests library defaults to ISO-8859-1 for text/html responses
    without an explicit charset in Content-Type, even when the HTML has
    <meta charset="utf-8">. This tries UTF-8 first in that case.
    """
    content_type = response.headers.get("Content-Type", "")
    if "charset" not in content_type.lower():
        try:
            return response.content.decode("utf-8")
        except UnicodeDecodeError:
            pass
    return response.text


# Class/id substrings that indicate non-content elements
NAV_INDICATORS = [
    "nav",
    "navigation",
    "topnav",
    "sidebar",
    "menu",
    "cookie",
    "popup",
    "modal",
    "drawer",
    "toolbar",
    "breadcrumb",
    "skip-link",
    "share-bar",
    "newsletter-signup",
    "banner",
]


def strip_navigation_elements(html_text, gentle=False):
    """Remove navigation, header, footer, and other non-content elements
    to help the LLM focus on main content patterns.

    When gentle=True (used when a story_hint is provided), keep nav/footer
    elements so the LLM can find content in sections that would normally
    be stripped. Only remove truly non-content tags like script/style/svg.
    """
    try:
        doc = lxml_html.fromstring(html_text)
    except Exception:
        return html_text

    # Always remove these non-content tags
    always_remove = ["script", "style", "noscript", "svg", "iframe"]
    for tag_name in always_remove:
        for el in doc.xpath(f"//{tag_name}"):
            if el.getparent() is not None:
                el.getparent().remove(el)

    if not gentle:
        # Aggressive stripping: remove nav, footer, and header elements
        for tag_name in ["nav", "footer"]:
            for el in doc.xpath(f"//{tag_name}"):
                if el.getparent() is not None:
                    el.getparent().remove(el)

        # Remove site-level <header> elements (direct children of body or top-level wrappers)
        for el in doc.xpath("//header"):
            if el.getparent() is not None and el.getparent().tag in ("body", "div", "html"):
                el.getparent().remove(el)

        # Remove elements whose class or id contains navigation indicators
        for el in doc.xpath("//*[@class or @id]"):
            classes = (el.get("class") or "").lower()
            el_id = (el.get("id") or "").lower()
            combined = classes + " " + el_id
            if any(indicator in combined for indicator in NAV_INDICATORS):
                # Protect main content containers from removal
                if el.tag not in ("main", "article", "section"):
                    if el.getparent() is not None:
                        el.getparent().remove(el)

    try:
        from lxml import etree

        return etree.tostring(doc, encoding="unicode", method="html")
    except Exception:
        return html_text


def fetch_page_html(url):
    """Fetch page HTML with fallback to scraping proxies."""
    headers = {"User-Agent": USER_AGENT}
    try:
        validate_public_url(url)
    except UnsafeUrlError:
        return None

    # Try direct fetch first
    try:
        response = safe_requests_get(url, headers=headers, timeout=15, allow_redirects=True)
        text = decode_response_text(response)
        if response.status_code == 200 and text:
            return text
    except requests.RequestException:
        pass

    # Fallback to ScrapingBee
    if getattr(settings, "SCRAPINGBEE_API_KEY", None):
        try:
            response = requests.get(
                "https://app.scrapingbee.com/api/v1",
                params={
                    "api_key": settings.SCRAPINGBEE_API_KEY,
                    "url": url,
                    "render_js": "false",
                    "return_page_source": "true",
                },
                timeout=15,
            )
            text = decode_response_text(response)
            if response.status_code == 200 and text:
                return text
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
                json={"url": url},
                timeout=15,
            )
            if response.status_code == 200:
                data = response.json()
                if data.get("body"):
                    return data["body"]
        except requests.RequestException:
            pass

    return None


def extract_preview_stories(html_text, variant, url):
    """Apply XPath expressions to HTML and extract preview stories."""
    try:
        doc = lxml_html.fromstring(html_text)
    except Exception:
        return []

    stories = []
    seen_keys = set()
    try:
        containers = doc.xpath(variant["story_container"])
    except Exception:
        return []

    for container in containers:
        if len(stories) >= 3:
            break

        story = {}
        try:
            titles = container.xpath(variant["title"])
            story["title"] = titles[0].strip() if titles else None
        except Exception:
            story["title"] = None

        try:
            links = container.xpath(variant["link"])
            link = links[0].strip() if links else None
            if link and not link.startswith("http"):
                link = urljoin(url, link)
            story["link"] = link
        except Exception:
            story["link"] = None

        if variant.get("content"):
            try:
                contents = container.xpath(variant["content"])
                story["content"] = contents[0].strip() if contents else None
            except Exception:
                story["content"] = None
        else:
            story["content"] = None

        if variant.get("image"):
            try:
                images = container.xpath(variant["image"])
                img_src = images[0].strip() if images else None
                img_src = extract_image_url(img_src)
                if img_src and not img_src.startswith("http"):
                    img_src = urljoin(url, img_src)
                story["image"] = img_src
            except Exception:
                story["image"] = None
        else:
            story["image"] = None

        if story.get("title") or story.get("link"):
            dedup_key = (story.get("title", ""), story.get("link", ""))
            if dedup_key in seen_keys:
                continue
            seen_keys.add(dedup_key)
            stories.append(story)

    return stories


def parse_variants_json(response_text):
    """Parse the LLM analysis response into a list of variant dicts.

    Tolerates markdown code fences around the JSON. Returns a list (possibly
    empty) on success, or None when the text is not valid JSON / not a list.
    """
    cleaned = response_text.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.split("\n", 1)[1] if "\n" in cleaned else cleaned[3:]
    if cleaned.endswith("```"):
        cleaned = cleaned[: cleaned.rfind("```")]
    cleaned = cleaned.strip()

    try:
        variants = json.loads(cleaned)
    except json.JSONDecodeError:
        return None
    if not isinstance(variants, list):
        return None
    return variants


def rank_variants_by_previews(variants):
    """Order variants best-first by how many preview stories they extracted.

    A variant's worth is judged by what it actually pulls off the page, not by
    the LLM's self-reported confidence order -- which is exactly the signal that
    fails on sites with churn-prone utility classes. Re-numbers each variant's
    `index` to match the new display order and returns (ranked, usable_count),
    where usable_count is how many variants produced at least one story.
    """
    ranked = sorted(variants, key=lambda v: len(v.get("preview_stories", [])), reverse=True)
    usable_count = 0
    for i, variant in enumerate(ranked):
        variant["index"] = i
        if variant.get("preview_stories"):
            usable_count += 1
    return ranked, usable_count


def choose_better_attempt(first, second):
    """Pick the better of two analysis attempts.

    Each attempt is a (variants, usable_count, response_text) tuple. Prefer the
    attempt that extracted more stories; if neither matched anything, fall back
    to whichever returned any variants at all so the user still has options.
    """
    first_variants, first_usable, _ = first
    second_variants, second_usable, _ = second
    if second_usable > first_usable:
        return second
    if first_usable > 0:
        return first
    # Neither attempt matched a story -- prefer a non-empty variant list.
    if first_variants:
        return first
    if second_variants:
        return second
    return first


@app.task(name="fetch-webfeed", time_limit=60, soft_time_limit=55)
def FetchWebFeed(feed_id, user_id):
    """Fetch stories for a web feed in the background, publishing progress via Redis PubSub."""
    from apps.rss_feeds.models import Feed

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    user = User.objects.get(pk=user_id)
    username = user.username
    feed = Feed.get_by_id(feed_id)
    if not feed:
        return {"code": -1, "message": "Feed not found"}

    def publish(stage, extra=None):
        payload = {"type": "subscribe_update", "feed_id": feed_id, "stage": stage}
        if extra:
            payload.update(extra)
        try:
            r.publish(username, f"webfeed:{json.dumps(payload, ensure_ascii=False)}")
        except redis.RedisError:
            pass

    try:
        publish("fetching")
        feed.count_subscribers()

        publish("processing")
        feed.update()

        feed = Feed.get_by_id(feed_id)
        publish("complete", {"feed": feed.canonical() if feed else None})

        logging.user(user, f"~BB~FWWeb Feed: Background fetch complete for ~SB{feed}~SN")
        return {"code": 1, "message": "Fetch complete"}

    except Exception as e:
        publish("error", {"error": str(e)})
        logging.user(user, f"~BB~FWWeb Feed: ~FR~SBBackground fetch error~SN~FW - {e}")
        return {"code": -1, "message": str(e)}


@app.task(name="analyze-webfeed-page", time_limit=120, soft_time_limit=110)
def AnalyzeWebFeedPage(user_id, url, request_id=None, story_hint=None):
    """Fetch a web page, analyze it with an LLM to find story patterns, and stream results via Redis PubSub."""

    start_time = time.time()
    publish_event = None
    user = None
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)

    try:
        user = User.objects.get(pk=user_id)
        username = user.username
        request_token = request_id or str(uuid.uuid4())

        def publish(event_type, extra=None):
            payload = {
                "type": event_type,
                "url": url,
                "request_id": request_token,
            }
            if extra:
                payload.update(extra)
            try:
                r.publish(username, f"webfeed:{json.dumps(payload, ensure_ascii=False)}")
            except redis.RedisError:
                logging.user(
                    user, f"~BB~FWWeb Feed: ~FR~SBPublish failure~SN~FW for event ~SB{event_type}~SN"
                )

        publish_event = publish
        publish_event("start")
        publish_event("progress", {"message": "Fetching page..."})

        logging.user(user, f"~BB~FWWeb Feed: Fetching page ~SB{url}~SN")

        # Step 1: Fetch page HTML
        from apps.statistics.rtrending_webfeeds import RTrendingWebFeed

        page_html = fetch_page_html(url)
        if not page_html:
            error_msg = "Could not fetch the page. The site may be blocking requests."
            publish_event("error", {"error": error_msg})
            logging.user(user, f"~BB~FWWeb Feed: ~FR~SBFetch failed~SN~FW for ~SB{url}~SN")
            RTrendingWebFeed.record_analysis_result(success=False)
            return {"code": -1, "message": error_msg}

        html_hash = hashlib.sha256(page_html[:10000].encode("utf-8", errors="replace")).hexdigest()[:16]

        logging.user(
            user,
            f"~BB~FWWeb Feed: Fetched ~SB{len(page_html)}~SN bytes, analyzing with Claude",
        )

        publish_event("progress", {"message": "Preparing page..."})

        # Pre-process HTML to strip navigation elements for LLM analysis
        # When a story_hint is provided, use gentle stripping to preserve nav/footer
        # content that might contain the sections the user is looking for
        cleaned_html = strip_navigation_elements(page_html, gentle=bool(story_hint))
        logging.user(
            user,
            f"~BB~FWWeb Feed: Cleaned HTML from ~SB{len(page_html)}~SN to ~SB{len(cleaned_html)}~SN bytes",
        )

        publish_event("progress", {"message": "Finding story patterns..."})

        # Step 2: Call Claude for XPath analysis. The model is non-deterministic
        # and sometimes returns selectors that match nothing (especially on
        # utility-class-heavy sites like Tailwind), so wrap the call in a helper
        # we can retry, and judge each pass by what its selectors actually
        # extract rather than by the model's self-reported confidence order.
        from apps.ask_ai.providers import LLM_EXCEPTIONS, get_briefing_provider

        provider, model_id = get_briefing_provider("haiku")

        if not provider.is_configured():
            error_msg = "Anthropic API key not configured"
            publish_event("error", {"error": error_msg})
            return {"code": -1, "message": error_msg}

        def request_variants(retry):
            """Run one analysis pass: call Claude, parse the JSON, attach preview
            stories, and rank best-first. Returns (variants, usable_count, text)
            where variants is None on a parse failure and usable_count is the
            number of variants that extracted at least one story."""
            messages = get_analysis_messages(url, cleaned_html, story_hint=story_hint, retry=retry)
            response_chunks = []
            for chunk in provider.stream_response(messages, model_id):
                response_chunks.append(chunk)
            text = "".join(response_chunks)

            input_tokens, output_tokens = provider.get_last_usage()
            LLMCostTracker.record_usage(
                provider="anthropic",
                model=model_id,
                feature="webfeed",
                input_tokens=input_tokens,
                output_tokens=output_tokens,
                user_id=user_id,
                request_id=f"{request_token}:retry" if retry else request_token,
                metadata={"url": url, "retry": retry},
            )

            parsed = parse_variants_json(text)
            if not parsed:
                return parsed, 0, text
            for variant in parsed:
                variant["preview_stories"] = extract_preview_stories(page_html, variant, url)
            ranked, usable = rank_variants_by_previews(parsed)
            return ranked, usable, text

        # Step 3: First analysis pass, plus a single retry when nothing matched.
        variants, usable_count, response_text = request_variants(retry=False)
        if usable_count == 0:
            publish_event("progress", {"message": "Refining story patterns..."})
            retry_attempt = request_variants(retry=True)
            variants, usable_count, response_text = choose_better_attempt(
                (variants, usable_count, response_text), retry_attempt
            )

        if variants is None:
            error_msg = "Failed to parse AI response. Please try again."
            publish_event("error", {"error": error_msg})
            logging.user(user, f"~BB~FWWeb Feed: ~FR~SBJSON parse failed~SN~FW: {response_text[:200]}")
            RTrendingWebFeed.record_analysis_result(success=False)
            return {"code": -1, "message": error_msg}

        if len(variants) == 0:
            error_msg = "No story patterns found on this page."
            publish_event("error", {"error": error_msg})
            RTrendingWebFeed.record_analysis_result(success=False)
            return {"code": -1, "message": error_msg}

        # Extract page title
        page_title = ""
        try:
            doc = lxml_html.fromstring(page_html)
            title_els = doc.xpath("//title/text()")
            if title_els:
                page_title = title_els[0].strip()
        except Exception:
            pass
        if not page_title:
            page_title = url.split("//")[-1].split("/")[0]

        # Extract favicon URL
        favicon_url = ""
        try:
            if not doc:
                doc = lxml_html.fromstring(page_html)
            for xpath in [
                '//link[@rel="icon"]/@href',
                '//link[@rel="shortcut icon"]/@href',
                '//link[@rel="apple-touch-icon"]/@href',
            ]:
                icons = doc.xpath(xpath)
                if icons:
                    favicon_url = icons[0].strip()
                    if favicon_url and not favicon_url.startswith("http"):
                        favicon_url = urljoin(url, favicon_url)
                    break
        except Exception:
            pass

        # Step 4: Variants already carry preview stories and are ranked best-first.
        # Show only the ones that actually extracted stories; if none did, fall
        # back to showing all so the user can still choose or refine with a hint.
        valid_variants = [v for v in variants if v.get("preview_stories")]
        if not valid_variants:
            valid_variants = variants

        logging.user(
            user,
            f"~BB~FWWeb Feed: Found ~SB{len(valid_variants)}~SN variants "
            f"in ~SB{time.time() - start_time:.2f}s~SN for ~SB{url}~SN",
        )

        publish_event(
            "variants",
            {
                "variants": valid_variants,
                "html_hash": html_hash,
                "page_title": page_title,
                "favicon_url": favicon_url,
            },
        )
        publish_event("complete")

        RTrendingWebFeed.record_analysis_result(success=True)

        return {
            "code": 1,
            "message": "Analysis complete",
            "variant_count": len(valid_variants),
            "duration": time.time() - start_time,
        }

    except LLM_EXCEPTIONS as e:
        error_msg = f"AI analysis error: {str(e)}"
        if publish_event:
            publish_event("error", {"error": error_msg})
        if user:
            logging.user(user, f"~BB~FWWeb Feed: ~FR~SBLLM error~SN~FW - {e}")
        try:
            from apps.statistics.rtrending_webfeeds import RTrendingWebFeed

            RTrendingWebFeed.record_analysis_result(success=False)
        except Exception:
            pass
        return {"code": -1, "message": error_msg}

    except Exception as e:
        error_msg = f"Unexpected error: {str(e)}"
        if publish_event:
            publish_event("error", {"error": error_msg})
        if user:
            logging.user(user, f"~BB~FWWeb Feed: ~FR~SBUnexpected error~SN~FW - {e}")
        try:
            from apps.statistics.rtrending_webfeeds import RTrendingWebFeed

            RTrendingWebFeed.record_analysis_result(success=False)
        except Exception:
            pass
        return {"code": -1, "message": error_msg}
