import datetime
import logging
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
from utils.story_functions import linkify


class YoutubeFetcher:
    def __init__(self, feed, options=None):
        self.feed = feed
        self.options = options or {}
        self.address = self.feed.feed_address
        self._video_details_cache = {}  # Cache for video details

    def fetch(self):
        username = self.extract_username(self.address)
        channel_id = self.extract_channel_id(self.address)
        list_id = self.extract_list_id(self.address)
        video_ids = None

        # For archive pages, we want to fetch all pages up to the target page
        target_page = self.options.get("archive_page", 1)

        if channel_id:
            video_ids, title, description = self.fetch_channel_videos(channel_id, target_page=target_page)
            channel_url = "https://www.youtube.com/channel/%s" % channel_id
        elif list_id:
            video_ids, title, description = self.fetch_playlist_videos(list_id, target_page=target_page)
            channel_url = "https://www.youtube.com/playlist?list=%s" % list_id
        elif username:
            video_ids, title, description = self.fetch_user_videos(username, target_page=target_page)
            channel_url = "https://www.youtube.com/user/%s" % username

        if not video_ids:
            return

        videos = self.fetch_videos(video_ids)
        if not videos:
            return

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

            # Add view count if available
            view_count = ""
            if "statistics" in video and "viewCount" in video["statistics"]:
                views = int(video["statistics"]["viewCount"])
                view_count = f"<b>Views:</b> {'{:,}'.format(views)}<br />"

            content = """<div class="NB-youtube-player">
                            <iframe allowfullscreen="true" src="%s?iv_load_policy=3"></iframe>
                         </div>
                         <div class="NB-youtube-stats"><small>
                             <b>From:</b> <a href="%s">%s</a><br />
                             %s
                             %s
                         </small></div><hr>
                         <div class="NB-youtube-description">%s</div>
                         <img src="%s" style="display:none" />""" % (
                ("https://www.youtube.com/embed/" + video["id"]),
                channel_url,
                username or title,
                duration,
                view_count,
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
        """Fetch video details in batches of 50, using cache."""
        all_videos = {"items": []}
        uncached_video_ids = [vid for vid in video_ids if vid not in self._video_details_cache]

        # Add cached videos first
        cached_videos = [
            self._video_details_cache[vid] for vid in video_ids if vid in self._video_details_cache
        ]
        all_videos["items"].extend(cached_videos)
        if cached_videos:
            logging.debug(" ***> Using %d cached video details" % len(cached_videos))

        # Split uncached video_ids into chunks of 50
        for i in range(0, len(uncached_video_ids), 50):
            chunk = uncached_video_ids[i : i + 50]
            videos_json = requests.get(
                "https://www.googleapis.com/youtube/v3/videos?part=contentDetails%%2Csnippet%%2Cstatistics&id=%s&key=%s"
                % (",".join(chunk), settings.YOUTUBE_API_KEY)
            )
            videos = json.decode(videos_json.content)
            if "error" in videos:
                logging.debug(
                    " ***> ~FRYoutube returned an error for chunk %d-%d: ~FM~SB%s" % (i, i + 50, videos)
                )
                continue
            if "items" in videos:
                # Cache the new video details
                for video in videos["items"]:
                    self._video_details_cache[video["id"]] = video
                all_videos["items"].extend(videos["items"])
                logging.debug(
                    " ***> Fetched details for %d videos (total: %d)"
                    % (len(videos["items"]), len(all_videos["items"]))
                )

        if not all_videos["items"]:
            logging.debug(" ***> ~FRNo video details could be fetched")
            return None

        return all_videos

    def fetch_channel_videos(self, channel_id, target_page=1):
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

        return self.fetch_playlist_videos(uploads_list_id, title, description, target_page=target_page)

    def fetch_playlist_videos(self, list_id, title=None, description=None, page_token=None, target_page=None):
        """Fetch videos from a playlist."""
        logging.debug(" ***> ~FBFetching YouTube playlist: ~SB%s with page token: %s" % (list_id, page_token))
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

        video_ids = []
        current_page_token = page_token
        current_page = 1
        target_page = target_page or 1  # Default to 1 if target_page is None

        while current_page <= target_page:
            url = (
                "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=%s&key=%s&maxResults=50"
                % (list_id, settings.YOUTUBE_API_KEY)
            )
            if current_page_token:
                url += "&pageToken=%s" % current_page_token

            logging.debug(
                "   ---> [Playlist] Fetching videos from: %s (page %s/%s)" % (url, current_page, target_page)
            )
            playlist_json = requests.get(url)
            playlist = json.decode(playlist_json.content)

            if "error" in playlist:
                logging.debug("   ---> [Playlist] Error fetching videos: %s" % playlist["error"])
                return None, None, None

            try:
                page_video_ids = [video["snippet"]["resourceId"]["videoId"] for video in playlist["items"]]
                video_ids.extend(page_video_ids)
                logging.debug(
                    "   ---> [Playlist] Found %s videos on page %s" % (len(page_video_ids), current_page)
                )

                current_page_token = playlist.get("nextPageToken")
                if current_page == target_page or not current_page_token:
                    logging.debug(
                        "   ---> [Playlist] %s at page %s"
                        % (
                            (
                                "Target page reached"
                                if current_page == target_page
                                else "No more pages available"
                            ),
                            current_page,
                        )
                    )
                    break

                current_page += 1

            except (IndexError, KeyError):
                logging.debug("   ---> [Playlist] Failed to extract video IDs from response")
                return None, None, None

        logging.debug(
            "   ---> [Playlist] Retrieved total of %s videos across %s pages" % (len(video_ids), current_page)
        )
        return video_ids, title, description

    def fetch_user_videos(self, username, username_key="forUsername", target_page=1):
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
                return self.fetch_user_videos(username, username_key="forHandle", target_page=target_page)
            return None, None, None

        return self.fetch_playlist_videos(uploads_list_id, title, description, target_page=target_page)

    def get_next_page_token(self, channel_id=None, list_id=None, username=None, page_token=None):
        """Get the next page token for pagination."""
        if channel_id:
            channel_json = requests.get(
                "https://www.googleapis.com/youtube/v3/channels?part=snippet,contentDetails&id=%s&key=%s"
                % (channel_id, settings.YOUTUBE_API_KEY)
            )
            channel = json.decode(channel_json.content)
            try:
                uploads_list_id = channel["items"][0]["contentDetails"]["relatedPlaylists"]["uploads"]
                return self._get_playlist_page_token(uploads_list_id, page_token)
            except (IndexError, KeyError):
                return None
        elif list_id:
            return self._get_playlist_page_token(list_id, page_token)
        elif username:
            channel_json = requests.get(
                "https://www.googleapis.com/youtube/v3/channels?part=contentDetails&forUsername=%s&key=%s"
                % (username, settings.YOUTUBE_API_KEY)
            )
            channel = json.decode(channel_json.content)
            try:
                uploads_list_id = channel["items"][0]["contentDetails"]["relatedPlaylists"]["uploads"]
                return self._get_playlist_page_token(uploads_list_id, page_token)
            except (IndexError, KeyError):
                return None
        return None

    def _get_playlist_page_token(self, list_id, page_token=None):
        """Helper method to get next page token for a playlist."""
        url = (
            "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=%s&key=%s&maxResults=50"
            % (
                list_id,
                settings.YOUTUBE_API_KEY,
            )
        )
        if page_token:
            url += "&pageToken=%s" % page_token

        logging.debug("   ---> [Playlist] Fetching next page token from: %s" % url)
        playlist_json = requests.get(url)
        playlist = json.decode(playlist_json.content)

        next_token = playlist.get("nextPageToken")
        logging.debug("   ---> [Playlist] Next page token: %s" % next_token)

        if "error" in playlist:
            logging.debug("   ---> [Playlist] Error getting next page token: %s" % playlist["error"])
            return None

        return next_token
