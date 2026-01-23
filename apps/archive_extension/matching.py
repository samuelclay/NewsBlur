"""
Story matching logic for the Archive Extension.

When a user visits a page, we check if it matches an existing story in their
NewsBlur feeds. If so, we can mark it as read and potentially use the existing
content instead of storing new content.
"""

import zlib
from dataclasses import dataclass
from typing import Optional
from urllib.parse import parse_qs, urlencode, urlparse

from apps.reader.models import UserSubscription
from apps.rss_feeds.models import MStory
from utils import log as logging


@dataclass
class MatchResult:
    """Result of a story matching operation."""

    story_hash: Optional[str] = None
    feed_id: Optional[int] = None
    story: Optional[object] = None

    @property
    def matched(self) -> bool:
        return self.story_hash is not None


# URL parameters that should be stripped during normalization
TRACKING_PARAMS = {
    # UTM parameters
    "utm_source",
    "utm_medium",
    "utm_campaign",
    "utm_term",
    "utm_content",
    "utm_id",
    # Facebook
    "fbclid",
    "fb_action_ids",
    "fb_action_types",
    "fb_ref",
    "fb_source",
    # Google
    "gclid",
    "gclsrc",
    "dclid",
    # Twitter
    "twclid",
    # Microsoft
    "msclkid",
    # HubSpot
    "hsa_acc",
    "hsa_cam",
    "hsa_grp",
    "hsa_ad",
    "hsa_src",
    "hsa_tgt",
    "hsa_kw",
    "hsa_mt",
    "hsa_net",
    "hsa_ver",
    # Other common tracking
    "ref",
    "ref_src",
    "source",
    "mc_cid",
    "mc_eid",
    "_ga",
    "_gl",
    "oly_enc_id",
    "oly_anon_id",
    "vero_id",
    "wickedid",
    "partner",
}


def normalize_url(url: str) -> str:
    """
    Normalize a URL by removing tracking parameters, fragments, and standardizing format.

    Args:
        url: URL string to normalize

    Returns:
        Normalized URL string
    """
    if not url:
        return ""

    try:
        parsed = urlparse(url)

        # Ensure we have a valid URL
        if not parsed.scheme or not parsed.netloc:
            return url

        # Lowercase domain
        domain = parsed.netloc.lower()

        # Remove www. prefix for consistency
        if domain.startswith("www."):
            domain = domain[4:]

        # Parse and filter query parameters
        params = parse_qs(parsed.query, keep_blank_values=False)
        filtered_params = {k: v for k, v in params.items() if k.lower() not in TRACKING_PARAMS}

        # Rebuild query string (sorted for consistency)
        query = urlencode(sorted(filtered_params.items()), doseq=True) if filtered_params else ""

        # Rebuild path (remove trailing slash unless it's the root)
        path = parsed.path
        if path != "/" and path.endswith("/"):
            path = path.rstrip("/")

        # Rebuild URL without fragment
        normalized = f"{parsed.scheme}://{domain}{path}"
        if query:
            normalized += f"?{query}"

        return normalized

    except Exception:
        return url


def extract_domain(url: str) -> str:
    """
    Extract the domain from a URL.

    Args:
        url: URL string

    Returns:
        Domain string (without www prefix and port)
    """
    if not url:
        return ""

    try:
        parsed = urlparse(url)
        domain = parsed.netloc.lower()

        # Remove port if present
        if ":" in domain:
            domain = domain.split(":")[0]

        # Remove www prefix
        if domain.startswith("www."):
            domain = domain[4:]

        return domain
    except Exception:
        return ""


def normalize_url_for_matching(url):
    """
    Normalize URL for matching against NewsBlur stories.
    Similar to MArchivedStory.normalize_url but focused on permalink matching.
    """
    from apps.archive_extension.models import MArchivedStory

    return MArchivedStory.normalize_url(url)


def find_matching_story(user, url):
    """
    Find a NewsBlur story that matches the given URL.

    Args:
        user: Django User object
        url: URL to match

    Returns:
        tuple: (MStory or None, feed_id or None)
    """
    normalized_url = normalize_url_for_matching(url)

    # Get all feed IDs the user is subscribed to
    feed_ids = list(UserSubscription.objects.filter(user=user, active=True).values_list("feed_id", flat=True))

    if not feed_ids:
        return None, None

    # Try to find story by permalink (most common match)
    # We search with both normalized and original URL variants
    url_variants = _get_url_variants(url)

    for variant in url_variants:
        try:
            story = MStory.objects(story_permalink__in=[variant], story_feed_id__in=feed_ids).first()
            if story:
                return story, story.story_feed_id
        except Exception as e:
            logging.debug(f"Error matching URL variant {variant}: {e}")

    # Try matching by story_guid (some feeds use URL as guid)
    for variant in url_variants:
        try:
            story = MStory.objects(story_guid__in=[variant], story_feed_id__in=feed_ids).first()
            if story:
                return story, story.story_feed_id
        except Exception as e:
            logging.debug(f"Error matching URL guid {variant}: {e}")

    return None, None


def _get_url_variants(url):
    """
    Generate URL variants to try for matching.
    Handles common differences between archived URLs and feed story URLs.
    """
    variants = [url]

    parsed = urlparse(url)

    # Try with and without www
    domain = parsed.netloc.lower()
    if domain.startswith("www."):
        no_www = url.replace(f"//{domain}", f"//{domain[4:]}", 1)
        variants.append(no_www)
    else:
        with_www = url.replace(f"//{domain}", f"//www.{domain}", 1)
        variants.append(with_www)

    # Try with and without trailing slash
    if url.endswith("/"):
        variants.append(url.rstrip("/"))
    else:
        variants.append(url + "/")

    # Try http vs https
    if url.startswith("https://"):
        variants.append(url.replace("https://", "http://", 1))
    elif url.startswith("http://"):
        variants.append(url.replace("http://", "https://", 1))

    # Remove duplicates while preserving order
    seen = set()
    unique_variants = []
    for v in variants:
        if v not in seen:
            seen.add(v)
            unique_variants.append(v)

    return unique_variants


def get_story_content_length(story):
    """
    Get the length of a story's content, checking both story_content and original_text.

    Args:
        story: MStory object

    Returns:
        int: Maximum content length from available sources
    """
    lengths = []

    # Check compressed story content
    if hasattr(story, "story_content_z") and story.story_content_z:
        try:
            content = zlib.decompress(story.story_content_z).decode("utf-8")
            lengths.append(len(content))
        except Exception:
            pass

    # Check original text (extracted full article)
    if hasattr(story, "original_text_z") and story.original_text_z:
        try:
            content = zlib.decompress(story.original_text_z).decode("utf-8")
            lengths.append(len(content))
        except Exception:
            pass

    # Fallback to uncompressed fields if they exist
    if hasattr(story, "story_content") and story.story_content:
        lengths.append(len(story.story_content))

    return max(lengths) if lengths else 0


def should_store_content(extension_content_length, story):
    """
    Determine if we should store the extension's content.

    We store the extension content if it's longer than what we already have,
    as the extension extracts full page content vs RSS truncated content.

    Args:
        extension_content_length: Length of content extracted by extension
        story: MStory object (or None if no match)

    Returns:
        bool: True if we should store the extension content
    """
    if not story:
        return True

    existing_length = get_story_content_length(story)

    # Store if extension content is meaningfully longer (>10% more)
    return extension_content_length > existing_length * 1.1


def mark_story_read(user, story, feed_id):
    """
    Mark a matched story as read in the user's feed.

    Args:
        user: Django User object
        story: MStory object
        feed_id: Feed ID
    """
    from apps.reader.models import UserSubscription

    try:
        usersub = UserSubscription.objects.get(user=user, feed_id=feed_id)
        usersub.mark_story_ids_as_read([story.story_hash], request=None)
        logging.debug(f"Marked story {story.story_hash} as read via Archive Extension")
    except UserSubscription.DoesNotExist:
        logging.warning(f"UserSubscription not found for user {user.pk} feed {feed_id}")
    except Exception as e:
        logging.error(f"Error marking story as read: {e}")


def match_and_process(user, url, title, content, content_length, **archive_kwargs):
    """
    Main entry point for matching and processing an archived page.

    This function:
    1. Checks if URL matches an existing NewsBlur story
    2. If matched, marks the story as read
    3. Determines if we should store the extension's content
    4. Creates/updates the archive record

    Args:
        user: Django User object
        url: Page URL
        title: Page title
        content: Extracted page content
        content_length: Length of content
        **archive_kwargs: Additional args for archive_page (browser, extension_version, etc.)

    Returns:
        dict: {
            'archive': MArchivedStory,
            'created': bool,
            'updated': bool,
            'matched': bool,
            'matched_story_hash': str or None,
            'matched_feed_id': int or None,
            'content_stored': bool
        }
    """
    from apps.archive_extension.models import MArchivedStory

    # Check for matching NewsBlur story
    matched_story, matched_feed_id = find_matching_story(user, url)

    matched = matched_story is not None
    matched_story_hash = matched_story.story_hash if matched_story else None

    # Mark as read if matched
    if matched_story and matched_feed_id:
        mark_story_read(user, matched_story, matched_feed_id)

    # Determine if we should store the content
    store_content = should_store_content(content_length, matched_story)

    # Determine content source
    if matched and store_content:
        content_source = "hybrid"  # Matched story but extension has better content
    elif matched:
        content_source = "newsblur"  # Using NewsBlur's content
    else:
        content_source = "extension"  # New page, extension content only

    # Create/update archive record
    archive, created, updated = MArchivedStory.archive_page(
        user_id=user.pk,
        url=url,
        title=title,
        content=content if store_content else None,
        matched_story_hash=matched_story_hash,
        matched_feed_id=matched_feed_id,
        content_source=content_source,
        **archive_kwargs,
    )

    return {
        "archive": archive,
        "created": created,
        "updated": updated,
        "matched": matched,
        "matched_story_hash": matched_story_hash,
        "matched_feed_id": matched_feed_id,
        "content_stored": store_content,
    }
