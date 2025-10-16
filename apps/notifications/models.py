import datetime
import enum
import html
import os
import re
import urllib.parse

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
                mutable_content=image_url is not None,
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

        params = {
            "story": story,
            "story_content": story_content,
            "feed": feed,
            "feed_title": usersub.user_title or feed.feed_title,
            "favicon_border": feed.favicon_color,
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
            classifier_feeds=classifiers.get("feeds", []),
        )

        return score
