"""Newsletter models: process incoming email newsletters and manage newsletter feeds."""

import datetime
import html as html_module
import json
import re

import redis
from django.conf import settings
from django.contrib.sites.models import Site
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.urls import reverse
from django.utils.html import linebreaks

from apps.notifications.models import MUserFeedNotification
from apps.notifications.tasks import QueueNotifications
from apps.profile.models import MSentEmail, Profile
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.rss_feeds.models import Feed, MFetchHistory, MStory
from utils import log as logging
from utils.scrubber import Scrubber
from utils.story_functions import linkify


class EmailNewsletter:
    HEADER_NAMES_TO_SAVE = {
        "content-type",
        "date",
        "delivered-to",
        "from",
        "list-archive",
        "list-help",
        "list-id",
        "list-owner",
        "list-post",
        "list-subscribe",
        "list-unsubscribe",
        "message-id",
        "mime-version",
        "reply-to",
        "return-path",
        "sender",
        "subject",
        "to",
        "x-forwarded-for",
        "x-forwarded-to",
        "x-original-from",
        "x-original-to",
        "x-simplelogin-envelope-from",
        "x-simplelogin-original-from",
    }

    def receive_newsletter(self, params):
        logging.debug(f" ---> receive_newsletter called with recipient: {params.get('recipient')}")
        user = self._user_from_email(params["recipient"])
        if not user:
            logging.debug(" ***> receive_newsletter: No user found, returning early")
            return

        logging.debug(f" ---> receive_newsletter: Processing for user {user.username}")
        sender_name, sender_username, sender_domain = self._split_sender(params["from"])
        sender_email = "%s@%s" % (sender_username, sender_domain)
        newsletter_headers = self._extract_headers(params)
        newsletter_identity, newsletter_identity_source = self._newsletter_identity(
            sender_name, sender_email, newsletter_headers
        )
        feed_address = self._feed_address(user, newsletter_identity)
        feed_link = self._feed_link(newsletter_identity, sender_domain)

        try:
            usf = UserSubscriptionFolders.objects.get(user=user)
        except UserSubscriptionFolders.DoesNotExist:
            logging.user(user, "~FRUser does not have a USF, ignoring newsletter.")
            return
        usf.add_folder("", "Newsletters")

        feed = self._find_feed(user, feed_address, sender_name, sender_email)
        if feed and feed.feed_address != feed_address:
            feed = self._update_feed_address(feed, feed_address)

        # Create a new feed if it doesn't exist by stable newsletter identity.
        if not feed:
            feed = Feed.objects.create(
                feed_address=feed_address,
                feed_link=feed_link,
                feed_title=sender_name,
                fetched_once=True,
                known_good=True,
            )
            feed.update()
            logging.user(user, "~FCCreating newsletter feed: ~SB%s" % (feed))
            r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
            r.publish(user.username, "reload:%s" % feed.pk)
            self._check_if_first_newsletter(user)

        feed.last_update = datetime.datetime.now()
        feed.last_story_date = datetime.datetime.now()
        feed.save()

        if feed.feed_title != sender_name:
            feed.feed_title = sender_name
            feed.save()

        try:
            usersub = UserSubscription.objects.get(user=user, feed=feed)
        except UserSubscription.DoesNotExist:
            _, _, usersub = UserSubscription.add_subscription(
                user=user, feed_address=feed_address, folder="Newsletters"
            )
            r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
            r.publish(user.username, "reload:feeds")

        story_hash = MStory.ensure_story_hash(params["signature"], feed.pk)
        story_content = self._get_content(params)
        story_content = self._maybe_unescape_html(story_content)
        plain_story_content = self._get_content(params, force_plain=True)
        # apps/newsletters/models.py: Choose the longer content version if available
        # Handle plain-text-only newsletters where body-html may be None
        if story_content and plain_story_content and len(plain_story_content) > len(story_content):
            story_content = plain_story_content
        elif plain_story_content and not story_content:
            story_content = plain_story_content
        story_content = self._clean_content(story_content or "")
        story_params = {
            "story_feed_id": feed.pk,
            "story_date": self._clean_story_date(params.get("timestamp")),
            "story_title": params["subject"],
            "story_content": story_content,
            "story_author_name": params["from"],
            "story_permalink": "https://%s%s"
            % (
                Site.objects.get_current().domain,
                reverse("newsletter-story", kwargs={"story_hash": story_hash}),
            ),
            "story_guid": params["signature"],
            "newsletter_headers": newsletter_headers,
            "newsletter_identity": newsletter_identity,
            "newsletter_identity_source": newsletter_identity_source,
        }

        try:
            story = MStory.objects.get(story_hash=story_hash)
        except MStory.DoesNotExist:
            story = MStory(**story_params)
            story.save()
        else:
            updated = False
            if newsletter_headers and not story.newsletter_headers:
                story.newsletter_headers = newsletter_headers
                updated = True
            if newsletter_identity and not story.newsletter_identity:
                story.newsletter_identity = newsletter_identity
                story.newsletter_identity_source = newsletter_identity_source
                updated = True
            if updated:
                story.save()

        usersub.needs_unread_recalc = True
        usersub.save()

        self._publish_to_subscribers(feed, story.story_hash)

        MFetchHistory.add(feed_id=feed.pk, fetch_type="push")
        logging.user(user, "~FCNewsletter feed story: ~SB%s~SN / ~SB%s" % (story.story_title, feed))

        return story

    def _check_if_first_newsletter(self, user, force=False):
        if not user.email:
            return

        subs = UserSubscription.objects.filter(user=user)
        found_newsletter = False
        for sub in subs:
            if sub.feed.is_newsletter:
                found_newsletter = True
                break
        if not found_newsletter and not force:
            return

        params = dict(receiver_user_id=user.pk, email_type="first_newsletter")
        try:
            MSentEmail.objects.get(**params)
            if not force:
                # Return if email already sent
                return
        except MSentEmail.DoesNotExist:
            MSentEmail.objects.create(**params)

        text = render_to_string("mail/email_first_newsletter.txt", {"user": user})
        html = render_to_string("mail/email_first_newsletter.xhtml", {"user": user})
        subject = "Your email newsletters are now being sent to NewsBlur"
        msg = EmailMultiAlternatives(
            subject,
            text,
            from_email="NewsBlur <%s>" % settings.HELLO_EMAIL,
            to=["%s <%s>" % (user, user.email)],
            headers=user.profile.email_unsubscribe_headers(),
        )
        msg.attach_alternative(html, "text/html")
        msg.send()

        logging.user(user, "~BB~FM~SBSending first newsletter email to: %s" % user.email)

    def _user_from_email(self, email):
        # Support both @newsletters.newsblur.com and @improvmx.newsblur.com
        tokens = re.search(r"(\w+)[\+\-\.](\w+)@(?:newsletters|improvmx)\.newsblur\.com", email)
        if not tokens:
            logging.debug(f" ***> Newsletter email regex failed for: {email}")
            return

        username, secret_token = tokens.groups()
        logging.debug(f" ---> Newsletter parsed email: username={username}, secret_token={secret_token}")
        try:
            profiles = Profile.objects.filter(secret_token=secret_token)
            if not profiles:
                logging.debug(f" ***> No profile found for secret_token: {secret_token}")
                return
            profile = profiles[0]
        except Profile.DoesNotExist:
            logging.debug(f" ***> Profile.DoesNotExist for secret_token: {secret_token}")
            return

        logging.debug(f" ---> Newsletter found user: {profile.user.username}")
        return profile.user

    def _feed_address(self, user, sender_email):
        return "newsletter:%s:%s" % (user.pk, sender_email)

    def _feed_link(self, newsletter_identity, sender_domain):
        source = newsletter_identity.split(":", 1)[-1]
        if "@" in source:
            source = source.rsplit("@", 1)[1]
        if "." not in source:
            source = sender_domain
        return "http://" + source

    def _split_sender(self, sender):
        tokens = re.search("(.*?) <(.*?)@(.*?)>", sender)

        if not tokens:
            name, domain = sender.split("@")
            return name, sender, domain

        sender_name, sender_username, sender_domain = tokens.group(1), tokens.group(2), tokens.group(3)
        sender_name = sender_name.replace('"', "")

        return sender_name, sender_username, sender_domain

    def _find_feed(self, user, feed_address, sender_name, sender_email):
        candidate_addresses = [feed_address]
        legacy_feed_address = self._feed_address(user, sender_email)
        if legacy_feed_address not in candidate_addresses:
            candidate_addresses.append(legacy_feed_address)

        for candidate_address in candidate_addresses:
            try:
                return Feed.objects.get(feed_address=candidate_address)
            except Feed.MultipleObjectsReturned:
                feeds = Feed.objects.filter(feed_address=candidate_address)[:1]
                if feeds.count():
                    return feeds[0]
            except Feed.DoesNotExist:
                pass

        newsletter_subs = UserSubscription.objects.filter(
            user=user, feed__feed_address__contains="newsletter:"
        ).only("feed")
        newsletter_feed_ids = [us.feed.pk for us in newsletter_subs]
        feeds = Feed.objects.filter(feed_title__iexact=sender_name, pk__in=newsletter_feed_ids)
        if feeds.count():
            return feeds[0]

        return None

    def _update_feed_address(self, feed, feed_address):
        existing_feed = Feed.objects.filter(feed_address=feed_address).exclude(pk=feed.pk).first()
        if existing_feed:
            return existing_feed

        old_feed_address = feed.feed_address
        feed.feed_address = feed_address
        feed.save()
        logging.info(
            " ---> Updating newsletter feed address: %s -> %s (%s)"
            % (old_feed_address, feed_address, feed.pk)
        )
        return feed

    def _newsletter_identity(self, sender_name, sender_email, newsletter_headers):
        list_id = self._header_value(newsletter_headers, "List-ID")
        normalized_list_id = self._normalize_list_id(list_id)
        if normalized_list_id:
            return "list-id:%s" % normalized_list_id, "list-id"

        original_sender_email = self._original_sender_email(sender_name, sender_email, newsletter_headers)
        return self._normalize_sender_email(original_sender_email), "sender"

    def _extract_headers(self, params):
        headers = {}

        message_headers = params.get("message-headers")
        if message_headers:
            self._add_message_headers(headers, message_headers)

        raw_headers = params.get("headers")
        if raw_headers:
            self._add_message_headers(headers, raw_headers)

        for name, value in params.items():
            normalized_name = str(name).lower()
            if normalized_name in self.HEADER_NAMES_TO_SAVE or normalized_name.startswith("x-"):
                self._add_header(headers, name, value)

        if params.get("from"):
            self._add_header(headers, "From", params["from"])
        if params.get("recipient"):
            self._add_header(headers, "Delivered-To", params["recipient"])

        return headers

    def _add_message_headers(self, headers, message_headers):
        if isinstance(message_headers, str):
            try:
                message_headers = json.loads(message_headers)
            except (TypeError, ValueError):
                return

        if isinstance(message_headers, dict):
            for name, value in message_headers.items():
                self._add_header(headers, name, value)
        elif isinstance(message_headers, list):
            for header in message_headers:
                if isinstance(header, (list, tuple)) and len(header) >= 2:
                    self._add_header(headers, header[0], header[1])

    def _add_header(self, headers, name, value):
        if value is None:
            return

        name = self._normalize_header_name(name)
        value = self._normalize_header_value(value)
        if not name or not value:
            return

        if name not in headers:
            headers[name] = []
        if value not in headers[name]:
            headers[name].append(value)

    def _normalize_header_name(self, name):
        name = str(name).strip()
        if not name:
            return ""
        return "-".join(part[:1].upper() + part[1:].lower() for part in name.split("-"))

    def _normalize_header_value(self, value):
        if isinstance(value, dict):
            return json.dumps(value, sort_keys=True)
        if isinstance(value, (list, tuple)):
            return json.dumps(list(value))
        return str(value).strip()

    def _header_value(self, headers, name):
        normalized_name = self._normalize_header_name(name).lower()
        for header_name, values in headers.items():
            if header_name.lower() == normalized_name and values:
                return values[0]
        return None

    def _normalize_list_id(self, list_id):
        if not list_id:
            return None

        list_id = str(list_id).strip()
        tokens = re.search(r"<([^>]+)>", list_id)
        if tokens:
            list_id = tokens.group(1)
        else:
            list_id = list_id.split(";", 1)[0]

        list_id = list_id.strip().strip("<>").strip('"').strip("'").lower()
        list_id = re.sub(r"\s+", "", list_id)
        list_id = list_id.strip(".")
        if not list_id:
            return None
        return list_id[:500]

    def _original_sender_email(self, sender_name, sender_email, newsletter_headers):
        for header_name in [
            "X-Original-From",
            "X-SimpleLogin-Original-From",
            "X-SimpleLogin-Envelope-From",
        ]:
            value = self._header_value(newsletter_headers, header_name)
            email = self._email_from_text(value)
            if email:
                return email

        sender_from_name = self._email_from_text(sender_name)
        if sender_from_name:
            return sender_from_name

        for header_name in [
            "Reply-To",
            "From",
        ]:
            value = self._header_value(newsletter_headers, header_name)
            email = self._email_from_text(value)
            if email:
                return email

        return sender_email

    def _email_from_text(self, text):
        if not text:
            return None

        emails = re.findall(r"([A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,})", text, re.IGNORECASE)
        if emails:
            return emails[-1]

        at_emails = re.findall(
            r"([A-Z0-9._%+\-]+)\s+at\s+([A-Z0-9.\-]+\.[A-Z]{2,})",
            text,
            re.IGNORECASE,
        )
        if at_emails:
            local, domain = at_emails[-1]
            return "%s@%s" % (local, domain)

        return None

    def _normalize_sender_email(self, sender_email):
        sender_email = (sender_email or "").strip().lower()
        if sender_email.startswith("mailto:"):
            sender_email = sender_email[len("mailto:") :]
        if "@" not in sender_email:
            return sender_email

        local, domain = sender_email.rsplit("@", 1)
        local = local.split("+", 1)[0]
        return "%s@%s" % (local, domain)

    def _clean_story_date(self, timestamp):
        """
        apps/newsletters/models.py: Convert timestamp to datetime.
        If timestamp is empty or invalid, use current date.
        """
        if timestamp and str(timestamp).strip():
            try:
                return datetime.datetime.fromtimestamp(int(timestamp))
            except (ValueError, TypeError):
                return datetime.datetime.now()
        else:
            return datetime.datetime.now()

    def _get_content(self, params, force_plain=False):
        # apps/newsletters/models.py: Check for enriched, html, and plain content
        # Some newsletters only have plain text, so body-html may be None
        if "body-enriched" in params and params["body-enriched"] and not force_plain:
            return params["body-enriched"]
        if "body-html" in params and params["body-html"] and not force_plain:
            return params["body-html"]
        if "stripped-html" in params and params["stripped-html"] and not force_plain:
            return params["stripped-html"]
        if "body-plain" in params and params["body-plain"]:
            return linkify(linebreaks(params["body-plain"]))

        if force_plain:
            return self._get_content(params, force_plain=False)

        # apps/newsletters/models.py: No usable body. This is expected for forwarded
        # personal emails, auto-replies, and attachment-only mail, so log at debug
        # (not error) to avoid Sentry noise while keeping a local trace for debugging.
        logging.debug(
            f" ---> Newsletter content not found. force_plain={force_plain}, "
            f"recipient={params.get('recipient')}, from={params.get('from')}, "
            f"subject={params.get('subject')}, available_keys={list(params.keys())}"
        )
        return ""

    def _maybe_unescape_html(self, content):
        """Detect and fix entity-encoded HTML content from email providers.

        Some providers (e.g. ImprovMX) send HTML with entities encoded,
        e.g., &lt;table&gt; instead of <table>. BeautifulSoup treats these
        as text rather than tags, causing raw HTML to display to the user.
        """
        if not content:
            return content
        # apps/newsletters/models.py: Check for entity-encoded HTML tags
        entity_tag_pattern = r"&lt;/?(?:table|tr|td|th|div|span|p|a|img|br|hr|h[1-6]|ul|ol|li|strong|em|b|i|font|center|blockquote|html|head|body|style|meta)\b"
        if re.search(entity_tag_pattern, content, re.IGNORECASE):
            logging.debug(" ---> Unescaping entity-encoded HTML in newsletter content")
            return html_module.unescape(content)
        return content

    def _clean_content(self, content):
        original = content
        # Disable autolink since newsletter HTML already has proper anchor tags
        # apps/newsletters/models.py
        scrubber = Scrubber(autolink=False)
        content = scrubber.scrub(content)
        if len(content) < len(original) * 0.01:
            content = original
        content = content.replace("!important", "")
        return content

    def _publish_to_subscribers(self, feed, story_hash):
        try:
            r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
            listeners_count = r.publish("%s:story" % feed.pk, "story:new:%s" % story_hash)
            if listeners_count:
                logging.debug(
                    "   ---> [%-30s] ~FMPublished to %s subscribers" % (feed.log_title[:30], listeners_count)
                )
        except redis.ConnectionError:
            logging.debug("   ***> [%-30s] ~BMRedis is unavailable for real-time." % (feed.log_title[:30],))

        if MUserFeedNotification.feed_has_users(feed.pk) > 0:
            QueueNotifications.delay(feed.pk, 1)
