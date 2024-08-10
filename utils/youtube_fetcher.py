import datetime
import re
import urllib.error
import urllib.parse
import urllib.request

import dateutil.parser
import isodate
import requests
from django.conf import settings
from django.utils import feedgenerator
from django.utils.html import linebreaks

from apps.reader.models import UserSubscription
from apps.social.models import MSocialServices
from utils import json_functions as json
from utils import log as logging
from utils.story_functions import linkify


class YoutubeFetcher:
    def __init__(self, feed, options=None):
        self.feed = feed
        self.options = options or {}
        self.address = self.feed.feed_address

    def fetch(self):
        username = self.extract_username(self.address)
        channel_id = self.extract_channel_id(self.address)
        list_id = self.extract_list_id(self.address)
        video_ids = None

        if channel_id:
            video_ids, title, description = self.fetch_channel_videos(channel_id)
            channel_url = "https://www.youtube.com/channel/%s" % channel_id
        elif list_id:
            video_ids, title, description = self.fetch_playlist_videos(list_id)
            channel_url = "https://www.youtube.com/playlist?list=%s" % list_id
        elif username:
            video_ids, title, description = self.fetch_user_videos(username)
            channel_url = "https://www.youtube.com/user/%s" % username

        if not video_ids:
            return

        videos = self.fetch_videos(video_ids)
        data = {}
        if username:
            data["title"] = f"{username}'s YouTube Videos"
        else:
            data["title"] = title
        data["link"] = channel_url
        data["description"] = description
        data["lastBuildDate"] = datetime.datetime.utcnow()
        data["generator"] = "NewsBlur YouTube API v3 Decrapifier - %s" % settings.NEWSBLUR_URL
        data["docs"] = None
        data["feed_url"] = self.address
        rss = feedgenerator.Atom1Feed(**data)

        for video in videos["items"]:
            thumbnail = video["snippet"]["thumbnails"].get("maxres")
            if not thumbnail:
                thumbnail = video["snippet"]["thumbnails"].get("high")
            if not thumbnail:
                thumbnail = video["snippet"]["thumbnails"].get("medium")
            duration = ""
            if "duration" in video["contentDetails"]:
                duration_sec = isodate.parse_duration(video["contentDetails"]["duration"]).seconds
                duration_min, seconds = divmod(duration_sec, 60)
                hours, minutes = divmod(duration_min, 60)
                if hours >= 1:
                    duration = "%s:%s:%s" % (
                        hours,
                        "{0:02d}".format(minutes),
                        "{0:02d}".format(seconds),
                    )
                else:
                    duration = "%s:%s" % (minutes, "{0:02d}".format(seconds))
                duration = f"<b>Duration:</b> {duration}<br />"
            content = """<div class="NB-youtube-player">
                            <iframe allowfullscreen="true" src="%s?iv_load_policy=3"></iframe>
                         </div>
                         <div class="NB-youtube-stats"><small>
                             <b>From:</b> <a href="%s">%s</a><br />
                             %s
                         </small></div><hr>
                         <div class="NB-youtube-description">%s</div>
                         <img src="%s" style="display:none" />""" % (
                ("https://www.youtube.com/embed/" + video["id"]),
                channel_url,
                username or title,
                duration,
                linkify(linebreaks(video["snippet"]["description"])),
                thumbnail["url"] if thumbnail else "",
            )

            link = "http://www.youtube.com/watch?v=%s" % video["id"]
            story_data = {
                "title": video["snippet"]["title"],
                "link": link,
                "description": content,
                "author_name": username or title,
                "categories": [],
                "unique_id": "tag:youtube.com,2008:video:%s" % video["id"],
                "pubdate": dateutil.parser.parse(video["snippet"]["publishedAt"]),
            }
            rss.add_item(**story_data)

        return rss.writeString("utf-8")

    def extract_username(self, url):
        if "gdata.youtube.com" in url:
            try:
                #  Also handle usernames like `user-name`
                username_groups = re.search(r"gdata.youtube.com/feeds/\w+/users/([^/]+)/", url)
                if not username_groups:
                    return
                return username_groups.group(1)
            except IndexError:
                return
        elif "youtube.com/@" in url:
            try:
                return url.split("youtube.com/@")[1]
            except IndexError:
                return
        elif "youtube.com/feeds/videos.xml?user=" in url:
            try:
                return urllib.parse.parse_qs(urllib.parse.urlparse(url).query)["user"][0]
            except IndexError:
                return
        elif "youtube.com/user/" in url:
            username = re.findall(r"youtube.com/user/([^/]+)", url)
            if username:
                return username[0]

    def extract_channel_id(self, url):
        if "youtube.com/feeds/videos.xml?channel_id=" in url:
            try:
                return urllib.parse.parse_qs(urllib.parse.urlparse(url).query)["channel_id"][0]
            except (IndexError, KeyError):
                return

    def extract_list_id(self, url):
        if "youtube.com/playlist" in url:
            try:
                return urllib.parse.parse_qs(urllib.parse.urlparse(url).query)["list"][0]
            except IndexError:
                return
        elif "youtube.com/feeds/videos.xml?playlist_id" in url:
            try:
                return urllib.parse.parse_qs(urllib.parse.urlparse(url).query)["playlist_id"][0]
            except IndexError:
                return

    def fetch_videos(self, video_ids):
        videos_json = requests.get(
            "https://www.googleapis.com/youtube/v3/videos?part=contentDetails%%2Csnippet&id=%s&key=%s"
            % (",".join(video_ids), settings.YOUTUBE_API_KEY)
        )
        videos = json.decode(videos_json.content)
        if "error" in videos:
            logging.debug(" ***> ~FRYoutube returned an error: ~FM~SB%s" % (videos))
            return
        return videos

    def fetch_channel_videos(self, channel_id):
        logging.debug(" ***> ~FBFetching YouTube channel: ~SB%s" % channel_id)
        channel_json = requests.get(
            "https://www.googleapis.com/youtube/v3/channels?part=snippet,contentDetails&id=%s&key=%s"
            % (channel_id, settings.YOUTUBE_API_KEY)
        )
        channel = json.decode(channel_json.content)
        try:
            title = channel["items"][0]["snippet"]["title"]
            description = channel["items"][0]["snippet"]["description"]
            uploads_list_id = channel["items"][0]["contentDetails"]["relatedPlaylists"]["uploads"]
        except (IndexError, KeyError) as e:
            logging.debug(" ***> ~FRYoutube channel returned an error: ~FM~SB%s: %s" % (channel, e))
            return None, None, None

        return self.fetch_playlist_videos(uploads_list_id, title, description)

    def fetch_playlist_videos(self, list_id, title=None, description=None):
        logging.debug(" ***> ~FBFetching YouTube playlist: ~SB%s" % list_id)
        if not title and not description:
            playlist_json = requests.get(
                "https://www.googleapis.com/youtube/v3/playlists?part=snippet&id=%s&key=%s"
                % (list_id, settings.YOUTUBE_API_KEY)
            )
            playlist = json.decode(playlist_json.content)
            try:
                title = playlist["items"][0]["snippet"]["title"]
                description = playlist["items"][0]["snippet"]["description"]
            except (IndexError, KeyError):
                return None, None, None

        playlist_json = requests.get(
            "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=%s&key=%s"
            % (list_id, settings.YOUTUBE_API_KEY)
        )
        playlist = json.decode(playlist_json.content)
        try:
            video_ids = [video["snippet"]["resourceId"]["videoId"] for video in playlist["items"]]
        except (IndexError, KeyError):
            return None, None, None

        return video_ids, title, description

    def fetch_user_videos(self, username, username_key="forUsername"):
        logging.debug(" ***> ~FBFetching YouTube user: ~SB%s" % username)
        channel_json = requests.get(
            "https://www.googleapis.com/youtube/v3/channels?part=snippet,contentDetails&%s=%s&key=%s"
            % (username_key, username, settings.YOUTUBE_API_KEY)
        )
        channel = json.decode(channel_json.content)
        try:
            title = channel["items"][0]["snippet"]["title"]
            description = channel["items"][0]["snippet"]["description"]
            uploads_list_id = channel["items"][0]["contentDetails"]["relatedPlaylists"]["uploads"]
        except (IndexError, KeyError):
            uploads_list_id = None

        if not uploads_list_id:
            if username_key == "forUsername":
                return self.fetch_user_videos(username, username_key="forHandle")
            return None, None, None

        return self.fetch_playlist_videos(uploads_list_id, title, description)
