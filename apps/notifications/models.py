"""Notification models: per-feed and per-classifier notification settings and device token storage.

MUserFeedNotification configures which feeds trigger push notifications and
at what frequency. MUserClassifierNotification configures which individual
classifiers (title, author, tag, text, url) trigger push notifications.
MUserNotificationTokens stores iOS APNS and Android push tokens for delivering
notifications.
"""

import datetime
import enum
import html
import os
import re
import urllib.parse
from collections import defaultdict

import mongoengine as mongo
import redis
from bs4 import BeautifulSoup
from django.conf import settings
from django.contrib.auth.models import User
from django.contrib.sites.models import Site
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from pyapns_client import (
    APNSClient,
    APNSDeviceException,
    APNSProgrammingException,
    APNSServerException,
    IOSNotification,
    IOSPayload,
    IOSPayloadAlert,
    UnregisteredException,
)

from apps.analyzer.models import (
    MClassifierAuthor,
    MClassifierFeed,
    MClassifierTag,
    MClassifierText,
    MClassifierTitle,
    compute_story_score,
)
from apps.reader.models import UserSubscription

# from django.utils.html import strip_tags
from apps.rss_feeds.models import Feed, MStory
from utils import log as logging
from utils import mongoengine_fields
from utils.story_functions import truncate_chars
from utils.view_functions import is_true


class NotificationFrequency(enum.Enum):
    immediately = 1
    hour_1 = 2
    hour_6 = 3
    hour_12 = 4
    hour_24 = 5


class MUserNotificationTokens(mongo.Document):
    """A user's push notification tokens"""

    user_id = mongo.IntField()
    ios_tokens = mongo.ListField(mongo.StringField(max_length=1024))
    use_sandbox = mongo.BooleanField(default=False)

    meta = {
        "collection": "notification_tokens",
        "indexes": [
            {
                "fields": ["user_id"],
                "unique": True,
            }
        ],
        "allow_inheritance": False,
    }

    @classmethod
    def get_tokens_for_user(cls, user_id):
        try:
            tokens = cls.objects.get(user_id=user_id)
        except cls.DoesNotExist:
            tokens = cls.objects.create(user_id=user_id)

        return tokens


class MUserFeedNotification(mongo.Document):
    """A user's notifications of a single feed."""

    user_id = mongo.IntField()
    feed_id = mongo.IntField()
    frequency = mongoengine_fields.IntEnumField(NotificationFrequency)
    is_focus = mongo.BooleanField()
    last_notification_date = mongo.DateTimeField(default=datetime.datetime.now)
    is_email = mongo.BooleanField()
    is_web = mongo.BooleanField()
    is_ios = mongo.BooleanField()
    is_android = mongo.BooleanField()
    ios_tokens = mongo.ListField(mongo.StringField(max_length=1024))

    meta = {
        "collection": "notifications",
        "indexes": [
            "feed_id",
            {
                "fields": ["user_id", "feed_id"],
                "unique": True,
            },
        ],
        "allow_inheritance": False,
    }

    def __str__(self):
        notification_types = []
        if self.is_email:
            notification_types.append("email")
        if self.is_web:
            notification_types.append("web")
        if self.is_ios:
            notification_types.append("ios")
        if self.is_android:
            notification_types.append("android")

        return "%s/%s: %s -> %s" % (
            User.objects.get(pk=self.user_id).username,
            Feed.get_by_id(self.feed_id),
            ",".join(notification_types),
            self.last_notification_date,
        )

    @classmethod
    def feed_has_users(cls, feed_id):
        return cls.users_for_feed(feed_id).count()

    @classmethod
    def users_for_feed(cls, feed_id):
        notifications = cls.objects.filter(feed_id=feed_id)

        return notifications

    @classmethod
    def feeds_for_user(cls, user_id):
        notifications = cls.objects.filter(user_id=user_id)
        notifications_by_feed = {}

        for feed in notifications:
            notifications_by_feed[feed.feed_id] = {
                "notification_types": [],
                "notification_filter": "focus" if feed.is_focus else "unread",
            }
            if feed.is_email:
                notifications_by_feed[feed.feed_id]["notification_types"].append("email")
            if feed.is_web:
                notifications_by_feed[feed.feed_id]["notification_types"].append("web")
            if feed.is_ios:
                notifications_by_feed[feed.feed_id]["notification_types"].append("ios")
            if feed.is_android:
                notifications_by_feed[feed.feed_id]["notification_types"].append("android")

        return notifications_by_feed

    @classmethod
    def switch_feed(cls, original_feed_id, duplicate_feed_id):
        """Migrate notification settings from duplicate feed to original feed."""
        duplicate_notifications = cls.objects.filter(feed_id=duplicate_feed_id)
        count = duplicate_notifications.count()
        if count:
            logging.info(
                " ---> Switching %s notification settings from feed %s to %s"
                % (count, duplicate_feed_id, original_feed_id)
            )
            for notification in duplicate_notifications:
                # Check if user already has notifications for the original feed
                try:
                    existing = cls.objects.get(user_id=notification.user_id, feed_id=original_feed_id)
                    # Merge notification settings - keep any enabled setting
                    existing.is_email = existing.is_email or notification.is_email
                    existing.is_web = existing.is_web or notification.is_web
                    existing.is_ios = existing.is_ios or notification.is_ios
                    existing.is_android = existing.is_android or notification.is_android
                    existing.is_focus = existing.is_focus or notification.is_focus
                    if notification.frequency and not existing.frequency:
                        existing.frequency = notification.frequency
                    if notification.last_notification_date and (
                        not existing.last_notification_date
                        or notification.last_notification_date > existing.last_notification_date
                    ):
                        existing.last_notification_date = notification.last_notification_date
                    # Merge iOS tokens
                    if notification.ios_tokens:
                        existing_tokens = set(existing.ios_tokens or [])
                        existing_tokens.update(notification.ios_tokens)
                        existing.ios_tokens = list(existing_tokens)
                    existing.save()
                    notification.delete()
                except cls.DoesNotExist:
                    # No existing notification, just update feed_id
                    notification.feed_id = original_feed_id
                    notification.save()
        return count

    @classmethod
    def push_feed_notifications(cls, feed_id, new_stories, force=False):
        feed = Feed.get_by_id(feed_id)
        notifications = MUserFeedNotification.users_for_feed(feed.pk)
        logging.debug(
            "   ---> [%-30s] ~FCPushing out notifications to ~SB%s users~SN for ~FB~SB%s stories"
            % (feed, len(notifications), new_stories)
        )
        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)

        latest_story_hashes = r.zrange("zF:%s" % feed.pk, -1 * new_stories, -1)
        mstories = MStory.objects.filter(story_hash__in=latest_story_hashes).order_by("-story_date")
        stories = Feed.format_stories(mstories)
        total_sent_count = 0

        for user_feed_notification in notifications:
            sent_count = 0
            try:
                user = User.objects.get(pk=user_feed_notification.user_id)
            except User.DoesNotExist:
                continue
            months_ago = datetime.datetime.now() - datetime.timedelta(days=90)
            if user.profile.last_seen_on < months_ago:
                logging.user(user, f"~FBSkipping notifications, last seen: ~SB{user.profile.last_seen_on}")
                continue
            last_notification_date = user_feed_notification.last_notification_date
            try:
                usersub = UserSubscription.objects.get(
                    user=user_feed_notification.user_id, feed=user_feed_notification.feed_id
                )
            except UserSubscription.DoesNotExist:
                continue
            classifiers = user_feed_notification.classifiers(usersub)

            if classifiers is None:
                if settings.DEBUG:
                    logging.debug("Has no usersubs")
                continue

            for story in stories:
                if sent_count >= 3:
                    if settings.DEBUG:
                        logging.debug("Sent too many, ignoring...")
                    continue
                if story["story_date"] <= last_notification_date and not force:
                    if settings.DEBUG:
                        logging.debug(
                            "Story date older than last notification date: %s <= %s"
                            % (story["story_date"], last_notification_date)
                        )
                    continue

                if story["story_date"] > user_feed_notification.last_notification_date:
                    user_feed_notification.last_notification_date = story["story_date"]
                    user_feed_notification.save()

                story["story_content"] = html.unescape(story["story_content"])

                sent = user_feed_notification.push_story_notification(story, classifiers, usersub)
                if sent:
                    sent_count += 1
                    total_sent_count += 1
        return total_sent_count, len(notifications)

    def classifiers(self, usersub):
        classifiers = {}
        if usersub.is_trained:
            classifiers["feeds"] = list(
                MClassifierFeed.objects(user_id=self.user_id, feed_id=self.feed_id, social_user_id=0)
            )
            classifiers["authors"] = list(
                MClassifierAuthor.objects(user_id=self.user_id, feed_id=self.feed_id)
            )
            classifiers["titles"] = list(MClassifierTitle.objects(user_id=self.user_id, feed_id=self.feed_id))
            classifiers["tags"] = list(MClassifierTag.objects(user_id=self.user_id, feed_id=self.feed_id))
            user = User.objects.get(pk=self.user_id)
            if user.profile.premium_available_text_classifiers:
                classifiers["texts"] = list(
                    MClassifierText.objects(user_id=self.user_id, feed_id=self.feed_id)
                )
            else:
                classifiers["texts"] = []

        return classifiers

    def title_and_body(self, story, usersub, notification_title_only=False):
        def replace_with_newlines(element):
            text = ""
            for elem in element.recursiveChildGenerator():
                if isinstance(elem, (str,)):
                    text += elem
                elif elem.name == "br":
                    text += "\n"
                elif elem.name == "p":
                    text += "\n\n"
            text = re.sub(r" +", " ", text).strip()
            return text

        feed_title = usersub.user_title or usersub.feed.feed_title
        # title = "%s: %s" % (feed_title, story['story_title'])
        title = feed_title
        soup = BeautifulSoup(story["story_content"].strip(), features="lxml")
        # if notification_title_only:
        subtitle = None
        body_title = html.unescape(story["story_title"]).strip()
        body_content = replace_with_newlines(soup)
        if body_content:
            if body_title == body_content[: len(body_title)] or body_content[:100] == body_title[:100]:
                body_content = ""
            else:
                body_content = f"\n※ {body_content}"
        body = f"{body_title}{body_content}"
        # else:
        #     subtitle = html.unescape(story['story_title'])
        #     body = replace_with_newlines(soup)
        body = truncate_chars(body.strip(), 3600)
        if not body:
            body = " "

        if not usersub.user.profile.is_premium:
            body = "Please upgrade to a premium subscription to receive full push notifications."

        return title, subtitle, body

    def push_story_notification(self, story, classifiers, usersub):
        story_score = self.story_score(story, classifiers)
        if self.is_focus and story_score <= 0:
            if settings.DEBUG:
                logging.debug("Is focus, but story is hidden")
            return False
        elif story_score < 0:
            if settings.DEBUG:
                logging.debug("Is unread, but story is hidden")
            return False

        user = User.objects.get(pk=self.user_id)
        logging.user(
            user,
            "~FCSending push notification: %s/%s (score: %s)"
            % (story["story_title"][:40], story["story_hash"], story_score),
        )

        self.send_web(story, user)
        self.send_ios(story, user, usersub)
        self.send_android(story)
        self.send_email(story, usersub)

        # Mark channels as sent so classifier notifications don't re-send this story
        MUserClassifierNotification.mark_story_sent(
            self.user_id,
            story["story_hash"],
            is_email=self.is_email,
            is_web=self.is_web,
            is_ios=self.is_ios,
            is_android=self.is_android,
        )

        return True

    def send_web(self, story, user):
        if not self.is_web:
            return

        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        r.publish(user.username, "notification:%s,%s" % (story["story_hash"], story["story_title"]))

    def send_ios(self, story, user, usersub):
        if not self.is_ios:
            return

        tokens = MUserNotificationTokens.get_tokens_for_user(self.user_id)
        # Using APNS with Token-based authentication (recommended by Apple):
        # 1. Go to Apple Developer Portal -> Certificates, Identifiers & Profiles -> Keys
        # 2. Create a new key with APNS enabled
        # 3. Download the .p8 key file (only available once)
        # 4. Save the key file to secrets/certificates/ios/apns_key.p8
        # 5. Note your Team ID and Key ID
        # 6. Deploy: aps -l work -t apns,repo,celery

        # Legacy certificate method (kept for reference):
        # 0. Upgrade to latest openssl: brew install openssl
        # 1. Create certificate signing request in Keychain Access
        # 2. Upload to https://developer.apple.com/account/resources/certificates/list
        # 3. Download to secrets/certificates/ios/aps.cer
        # 4. Open in Keychain Access, Under "My Certificates":
        #    - export "Apple Push Service: com.newsblur.NewsBlur" as aps.p12 (or just use aps.cer in #5)
        #    - export private key as aps_key.p12 WITH A PASSPHRASE (removed later)
        # 5. openssl x509 -in aps.cer -inform DER -out aps.pem -outform PEM
        # 6. openssl pkcs12 -in aps_key.p12 -out aps_key.pem -nodes -legacy
        # 7. openssl rsa -out aps_key.noenc.pem -in aps_key.pem
        # 7. cat aps.pem aps_key.noenc.pem > aps.p12.pem
        # 8. Verify: openssl s_client -connect gateway.push.apple.com:2195 -cert aps.p12.pem
        # 9. Deploy: aps -l work -t apns,repo,celery

        # Using token-based authentication (modern method with pyapns-client)
        key_file_path = "/srv/newsblur/config/certificates/apns_key.p8"

        notification_title_only = is_true(user.profile.preference_value("notification_title_only"))
        title, subtitle, body = self.title_and_body(story, usersub, notification_title_only)
        image_url = None
        if len(story["image_urls"]):
            image_url = story["image_urls"][0]

        # Create APNS client
        apns = APNSClient(
            mode=APNSClient.MODE_DEV if tokens.use_sandbox else APNSClient.MODE_PROD,
            root_cert_path=None,
            auth_key_path=key_file_path,
            auth_key_id=settings.APNS_KEY_ID,
            team_id=settings.APNS_TEAM_ID,
        )

        confirmed_ios_tokens = []
        for token in tokens.ios_tokens:
            logging.user(
                user,
                "~BMStory notification by iOS: ~FY~SB%s~SN~BM~FY/~SB%s"
                % (story["story_title"][:50], usersub.feed.feed_title[:50]),
            )

            # Create payload using helper classes
            alert = IOSPayloadAlert(title=title, subtitle=subtitle, body=body)
            custom_data = {
                "story_hash": story["story_hash"],
                "story_feed_id": story["story_feed_id"],
            }
            if image_url:
                custom_data["image_url"] = image_url

            payload = IOSPayload(
                alert=alert,
                custom=custom_data,
                category="STORY_CATEGORY",
                mutable_content=True,
            )
            notification = IOSNotification(payload=payload, topic="com.newsblur.NewsBlur")

            try:
                apns.push(notification=notification, device_token=token)
                confirmed_ios_tokens.append(token)
                if settings.DEBUG:
                    logging.user(
                        user,
                        "~BMiOS token good: ~FB~SB%s / %s" % (token[:50], len(confirmed_ios_tokens)),
                    )
            except UnregisteredException as e:
                logging.user(
                    user,
                    "~BMiOS token unregistered: ~FR~SB%s (since %s)" % (token[:50], e.timestamp_datetime),
                )
            except APNSDeviceException as e:
                logging.user(user, "~BMiOS token invalid: ~FR~SB%s" % (token[:50]))
            except APNSServerException as e:
                logging.user(user, "~BMiOS notification server error: ~FR~SB%s - %s" % (token[:50], str(e)))
            except APNSProgrammingException as e:
                logging.user(
                    user, "~BMiOS notification programming error: ~FR~SB%s - %s" % (token[:50], str(e))
                )
            except Exception as e:
                logging.user(user, "~BMiOS notification error: ~FR~SB%s - %s" % (token[:50], str(e)))
            finally:
                apns.close()

        if len(confirmed_ios_tokens) < len(tokens.ios_tokens):
            tokens.ios_tokens = confirmed_ios_tokens
            tokens.save()

    def send_android(self, story):
        if not self.is_android:
            return

    def send_email(self, story, usersub):
        if not self.is_email:
            return

        # Increment the daily email counter for this user
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        emails_sent_date_key = f"emails_sent:{datetime.datetime.now().strftime('%Y%m%d')}"
        r.hincrby(emails_sent_date_key, usersub.user_id, 1)
        r.expire(emails_sent_date_key, 60 * 60 * 24)  # Keep for a day
        count = int(r.hget(emails_sent_date_key, usersub.user_id) or 0)
        if count > settings.MAX_EMAILS_SENT_PER_DAY_PER_USER:
            logging.user(
                usersub.user,
                "~BMSent too many email Story notifications by email: ~FR~SB%s~SN~FR emails" % (count),
            )
            return

        feed = usersub.feed
        story_content = self.sanitize_story(story["story_content"])

        # models.py: Use briefing.svg icon for daily briefing feeds (no MFeedIcon data)
        if feed.is_daily_briefing:
            favicon_url = "https://%s/media/img/icons/nouns/briefing.svg" % (
                Site.objects.get_current().domain,
            )
        else:
            favicon_url = feed.favicon_url_fqdn

        params = {
            "story": story,
            "story_content": story_content,
            "feed": feed,
            "feed_title": usersub.user_title or feed.feed_title,
            "favicon_border": feed.favicon_color,
            "favicon_url": favicon_url,
        }
        from_address = "notifications@newsblur.com"
        to_address = "%s <%s>" % (usersub.user.username, usersub.user.email)
        text = render_to_string("mail/email_story_notification.txt", params)
        html = render_to_string("mail/email_story_notification.xhtml", params)
        subject = "%s: %s" % (usersub.user_title or usersub.feed.feed_title, story["story_title"])
        subject = subject.replace("\n", " ")
        msg = EmailMultiAlternatives(
            subject, text, from_email="NewsBlur <%s>" % from_address, to=[to_address]
        )
        msg.attach_alternative(html, "text/html")
        # try:
        msg.send()
        # except BotoServerError as e:
        #     logging.user(usersub.user, '~BMStory notification by email error: ~FR%s' % e)
        #     return
        logging.user(
            usersub.user,
            "~BMStory notification by email: ~FY~SB%s~SN~BM~FY/~SB%s"
            % (story["story_title"][:50], usersub.feed.feed_title[:50]),
        )

    def sanitize_story(self, story_content):
        soup = BeautifulSoup(story_content.strip(), features="lxml")
        fqdn = Site.objects.get_current().domain

        # Convert videos in newsletters to images
        for iframe in soup("iframe"):
            url = dict(iframe.attrs).get("src", "")
            youtube_id = self.extract_youtube_id(url)
            if youtube_id:
                a = soup.new_tag("a", href=url)
                img = soup.new_tag(
                    "img",
                    style="display: block; 'background-image': \"url(https://%s/img/reader/youtube_play.png), url(http://img.youtube.com/vi/%s/0.jpg)\""
                    % (fqdn, youtube_id),
                    src="http://img.youtube.com/vi/%s/0.jpg" % youtube_id,
                )
                a.insert(0, img)
                iframe.replaceWith(a)
            else:
                iframe.extract()

        return str(soup)

    def extract_youtube_id(self, url):
        youtube_id = None

        if "youtube.com" in url:
            youtube_parts = urllib.parse.urlparse(url)
            if "/embed/" in youtube_parts.path:
                youtube_id = youtube_parts.path.replace("/embed/", "")

        return youtube_id

    def story_score(self, story, classifiers):
        score = compute_story_score(
            story,
            classifier_titles=classifiers.get("titles", []),
            classifier_authors=classifiers.get("authors", []),
            classifier_tags=classifiers.get("tags", []),
            classifier_texts=classifiers.get("texts", []),
            classifier_feeds=classifiers.get("feeds", []),
            classifier_urls=classifiers.get("urls", []),
        )

        return score


class MUserClassifierNotification(mongo.Document):
    """A user's notification settings for a specific classifier (title, author, tag, text, url).

    When a new story matches this classifier, a notification is sent via the
    selected channels. Premium Archive only. Coexists with per-feed notifications
    and deduplicates per story+channel via Redis keys.
    """

    user_id = mongo.IntField()
    classifier_type = mongo.StringField()  # title, author, tag, text, url
    classifier_value = mongo.StringField(max_length=2048)
    scope = mongo.StringField(default="feed")  # feed, folder, global
    feed_id = mongo.IntField(default=0)  # non-zero for feed-scoped classifiers
    folder_name = mongo.StringField(default="")  # non-empty for folder-scoped
    is_email = mongo.BooleanField(default=False)
    is_web = mongo.BooleanField(default=False)
    is_ios = mongo.BooleanField(default=False)
    is_android = mongo.BooleanField(default=False)
    last_notification_date = mongo.DateTimeField(default=datetime.datetime.now)

    meta = {
        "collection": "classifier_notifications",
        "indexes": [
            "feed_id",
            "user_id",
            ("user_id", "scope"),
            {
                "fields": [
                    "user_id",
                    "classifier_type",
                    "classifier_value",
                    "scope",
                    "feed_id",
                    "folder_name",
                ],
                "unique": True,
            },
        ],
        "allow_inheritance": False,
    }

    def __str__(self):
        types = []
        if self.is_email:
            types.append("email")
        if self.is_web:
            types.append("web")
        if self.is_ios:
            types.append("ios")
        if self.is_android:
            types.append("android")
        return "User %s: %s/%s (%s/%s) -> %s" % (
            self.user_id,
            self.classifier_type,
            self.classifier_value[:30],
            self.scope,
            self.feed_id or self.folder_name or "global",
            ",".join(types),
        )

    @property
    def notification_types(self):
        types = []
        if self.is_email:
            types.append("email")
        if self.is_web:
            types.append("web")
        if self.is_ios:
            types.append("ios")
        if self.is_android:
            types.append("android")
        return types

    # ------------------------------------------------------------------
    # Lookup helpers
    # ------------------------------------------------------------------

    @classmethod
    def feed_has_users(cls, feed_id):
        """Check if any classifier notification could fire for stories in this feed."""
        # Fast path: feed-scoped notifications with this exact feed_id
        if cls.objects.filter(scope="feed", feed_id=feed_id).limit(1).count():
            return True

        # Slower path: check if any user with folder/global scoped notifications
        # is subscribed to this feed. Since classifier notifications are Archive-only,
        # the count of scoped_user_ids is expected to be very small.
        scoped_user_ids = list(
            cls.objects.filter(scope__in=["folder", "global"]).distinct("user_id")
        )
        if not scoped_user_ids:
            return False

        return UserSubscription.objects.filter(
            feed_id=feed_id, user_id__in=scoped_user_ids
        ).exists()

    @classmethod
    def for_user(cls, user_id):
        """Return all classifier notifications for a user, keyed for frontend consumption."""
        notifications = cls.objects.filter(user_id=user_id)
        result = {}
        for notif in notifications:
            key = "%s:%s:%s:%s:%s" % (
                notif.classifier_type,
                notif.classifier_value,
                notif.scope,
                notif.feed_id,
                notif.folder_name,
            )
            result[key] = {
                "classifier_type": notif.classifier_type,
                "classifier_value": notif.classifier_value,
                "scope": notif.scope,
                "feed_id": notif.feed_id,
                "folder_name": notif.folder_name,
                "notification_types": notif.notification_types,
            }
        return result

    # ------------------------------------------------------------------
    # Dedup helpers (shared between feed and classifier notifications)
    # ------------------------------------------------------------------

    @classmethod
    def mark_story_sent(cls, user_id, story_hash, is_email=False, is_web=False,
                        is_ios=False, is_android=False):
        """Mark channels as sent for a story so classifier notifications don't re-send."""
        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        channels = []
        if is_email:
            channels.append("email")
        if is_web:
            channels.append("web")
        if is_ios:
            channels.append("ios")
        if is_android:
            channels.append("android")
        for channel in channels:
            key = "story_notified:%s:%s:%s" % (user_id, story_hash, channel)
            r.setex(key, 60 * 60 * 24, 1)

    @classmethod
    def check_story_sent(cls, user_id, story_hash, channel):
        """Check if a notification was already sent for this story+channel."""
        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        key = "story_notified:%s:%s:%s" % (user_id, story_hash, channel)
        return r.exists(key)

    # ------------------------------------------------------------------
    # Classifier matching
    # ------------------------------------------------------------------

    def matches_story(self, story, story_feed_id, folder_feed_ids=None):
        """Check if this classifier notification matches a story.

        Args:
            story: Story dict with standard fields
            story_feed_id: The feed_id of the story
            folder_feed_ids: Dict of {folder_name: set(feed_ids)} for scope resolution
        """
        # Check scope applicability
        if self.scope == "feed" and self.feed_id != story_feed_id:
            return False
        if self.scope == "folder":
            if not folder_feed_ids:
                return False
            feeds_in_folder = folder_feed_ids.get(self.folder_name, set())
            if story_feed_id not in feeds_in_folder:
                return False
        # scope == "global" always applies

        # Check classifier value match
        if self.classifier_type == "title":
            story_title = story.get("story_title", "")
            return bool(story_title and self.classifier_value.lower() in story_title.lower())
        elif self.classifier_type == "author":
            return story.get("story_authors", "") == self.classifier_value
        elif self.classifier_type == "tag":
            return self.classifier_value in (story.get("story_tags") or [])
        elif self.classifier_type == "text":
            story_content = story.get("story_content", "")
            original_text = story.get("original_text", "")
            combined = (story_content + " " + original_text).lower()
            return bool(combined and self.classifier_value.lower() in combined)
        elif self.classifier_type == "url":
            story_permalink = story.get("story_permalink", "")
            return bool(
                story_permalink and self.classifier_value.lower() in story_permalink.lower()
            )
        return False

    # ------------------------------------------------------------------
    # Notification processing
    # ------------------------------------------------------------------

    @classmethod
    def push_classifier_notifications(cls, feed_id, new_stories, force=False):
        """Process classifier notifications for new stories in a feed."""
        from apps.reader.models import UserSubscriptionFolders

        feed = Feed.get_by_id(feed_id)
        if not feed:
            return 0, 0

        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)

        # Get new stories
        latest_story_hashes = r.zrange("zF:%s" % feed.pk, -1 * new_stories, -1)
        mstories = MStory.objects.filter(story_hash__in=latest_story_hashes).order_by(
            "-story_date"
        )
        stories = Feed.format_stories(mstories)
        if not stories:
            return 0, 0

        # Collect applicable classifier notifications for this feed
        # 1. Feed-scoped: direct index lookup
        feed_scoped = list(cls.objects.filter(scope="feed", feed_id=feed_id))

        # 2. Folder/global-scoped: find users subscribed to this feed who have
        #    folder or global classifier notifications
        subscriber_user_ids = list(
            UserSubscription.objects.filter(feed_id=feed_id).values_list(
                "user_id", flat=True
            )
        )
        scoped_notifs = []
        if subscriber_user_ids:
            scoped_notifs = list(
                cls.objects.filter(
                    scope__in=["folder", "global"],
                    user_id__in=subscriber_user_ids,
                )
            )

        all_notifs = feed_scoped + scoped_notifs
        if not all_notifs:
            return 0, 0

        # Group by user
        by_user = defaultdict(list)
        for notif in all_notifs:
            by_user[notif.user_id].append(notif)

        logging.debug(
            "   ---> [%-30s] ~FCPushing classifier notifications to ~SB%s users~SN "
            "for ~FB~SB%s stories" % (feed, len(by_user), new_stories)
        )

        total_sent_count = 0

        for user_id, user_notifs in by_user.items():
            try:
                user = User.objects.get(pk=user_id)
            except User.DoesNotExist:
                continue

            # Archive gating
            if not user.profile.is_archive:
                continue

            # Skip inactive users
            months_ago = datetime.datetime.now() - datetime.timedelta(days=90)
            if user.profile.last_seen_on < months_ago:
                continue

            # Resolve folder scope
            folder_feed_ids = None
            has_folder_scope = any(n.scope == "folder" for n in user_notifs)
            if has_folder_scope:
                try:
                    usf = UserSubscriptionFolders.objects.get(user_id=user_id)
                    folder_feed_ids = usf.flatten_folders()
                except UserSubscriptionFolders.DoesNotExist:
                    pass

            # Get usersub for notification formatting
            try:
                usersub = UserSubscription.objects.get(user=user_id, feed=feed_id)
            except UserSubscription.DoesNotExist:
                continue

            for story in stories:
                story["story_content"] = html.unescape(story.get("story_content", ""))

                # Find all matching classifiers for this story
                matched = []
                for notif in user_notifs:
                    if notif.matches_story(story, feed_id, folder_feed_ids):
                        matched.append(notif)

                if not matched:
                    continue

                # Aggregate channels across all matched classifiers
                channels = {
                    "email": any(n.is_email for n in matched),
                    "web": any(n.is_web for n in matched),
                    "ios": any(n.is_ios for n in matched),
                    "android": any(n.is_android for n in matched),
                }

                # Dedup: skip channels already sent by feed notifications
                story_hash = story["story_hash"]
                channels_to_send = {}
                for channel, active in channels.items():
                    if active and not cls.check_story_sent(user_id, story_hash, channel):
                        channels_to_send[channel] = True

                if not any(channels_to_send.values()):
                    continue

                # Build match description for notification body
                match_parts = []
                for notif in matched:
                    match_parts.append("%s: %s" % (notif.classifier_type, notif.classifier_value))
                match_desc = ", ".join(match_parts)

                logging.user(
                    user,
                    "~FCSending classifier notification: %s/%s (matched: %s)"
                    % (story["story_title"][:40], story_hash, match_desc[:60]),
                )

                # Send notifications using a temporary MUserFeedNotification-like sender
                # We create a transient instance to reuse the send_* methods
                sender = MUserFeedNotification(
                    user_id=user_id,
                    feed_id=feed_id,
                    is_email=channels_to_send.get("email", False),
                    is_web=channels_to_send.get("web", False),
                    is_ios=channels_to_send.get("ios", False),
                    is_android=channels_to_send.get("android", False),
                )
                sender.send_web(story, user)
                sender.send_ios(story, user, usersub)
                sender.send_android(story)
                sender.send_email(story, usersub)

                # Mark as sent for dedup
                cls.mark_story_sent(
                    user_id, story_hash,
                    is_email=channels_to_send.get("email", False),
                    is_web=channels_to_send.get("web", False),
                    is_ios=channels_to_send.get("ios", False),
                    is_android=channels_to_send.get("android", False),
                )
                total_sent_count += 1

                # Update last_notification_date on matched notifications
                for notif in matched:
                    if story["story_date"] > notif.last_notification_date:
                        notif.last_notification_date = story["story_date"]
                        notif.save()

        return total_sent_count, len(by_user)
