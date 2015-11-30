import time
import datetime
import traceback
import multiprocessing
import urllib2
import xml.sax
import redis
import random
import pymongo
import re
import requests
import dateutil.parser
import isodate
import urlparse
from django.conf import settings
from django.db import IntegrityError
from django.core.cache import cache
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed, MStory
from apps.rss_feeds.page_importer import PageImporter
from apps.rss_feeds.icon_importer import IconImporter
from apps.push.models import PushSubscription
from apps.statistics.models import MAnalyticsFetcher
# from utils import feedparser
from utils import feedparser
from utils.story_functions import pre_process_story, strip_tags, linkify
from utils import log as logging
from utils.feed_functions import timelimit, TimeoutError, utf8encode, cache_bust_url
from BeautifulSoup import BeautifulSoup
from django.utils import feedgenerator
from django.utils.html import linebreaks
from utils import json_functions as json
# from utils.feed_functions import mail_feed_error_to_admin


# Refresh feed code adapted from Feedjack.
# http://feedjack.googlecode.com

FEED_OK, FEED_SAME, FEED_ERRPARSE, FEED_ERRHTTP, FEED_ERREXC = range(5)

def mtime(ttime):
    """ datetime auxiliar function.
    """
    return datetime.datetime.fromtimestamp(time.mktime(ttime))
    
    
class FetchFeed:
    def __init__(self, feed_id, options):
        self.feed = Feed.get_by_id(feed_id)
        self.options = options
        self.fpf = None
    
    @timelimit(30)
    def fetch(self):
        """ 
        Uses feedparser to download the feed. Will be parsed later.
        """
        start = time.time()
        identity = self.get_identity()
        log_msg = u'%2s ---> [%-30s] ~FYFetching feed (~FB%d~FY), last update: %s' % (identity,
                                                            self.feed.title[:30],
                                                            self.feed.id,
                                                            datetime.datetime.now() - self.feed.last_update)
        logging.debug(log_msg)
                                                 
        etag=self.feed.etag
        modified = self.feed.last_modified.utctimetuple()[:7] if self.feed.last_modified else None
        address = self.feed.feed_address
        
        if (self.options.get('force') or random.random() <= .01):
            modified = None
            etag = None
            address = cache_bust_url(address)
            logging.debug(u'   ---> [%-30s] ~FBForcing fetch: %s' % (
                          self.feed.title[:30], address))
        elif (not self.feed.fetched_once or not self.feed.known_good):
            modified = None
            etag = None
        
        USER_AGENT = ('NewsBlur Feed Fetcher - %s subscriber%s - %s '
                      '(Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_1) '
                      'AppleWebKit/534.48.3 (KHTML, like Gecko) Version/5.1 '
                      'Safari/534.48.3)' % (
                          self.feed.num_subscribers,
                          's' if self.feed.num_subscribers != 1 else '',
                          self.feed.permalink,
                     ))
        if self.options.get('feed_xml'):
            logging.debug(u'   ---> [%-30s] ~FM~BKFeed has been fat pinged. Ignoring fat: %s' % (
                          self.feed.title[:30], len(self.options.get('feed_xml'))))
        
        if self.options.get('fpf'):
            self.fpf = self.options.get('fpf')
            logging.debug(u'   ---> [%-30s] ~FM~BKFeed fetched in real-time with fat ping.' % (
                          self.feed.title[:30]))
            return FEED_OK, self.fpf
        
        if 'youtube.com' in address:
            try:
                youtube_feed = self.fetch_youtube(address)
            except (requests.adapters.ConnectionError):
                youtube_feed = None
            if not youtube_feed:
                logging.debug(u'   ***> [%-30s] ~FRYouTube fetch failed: %s.' % 
                              (self.feed.title[:30], address))
                return FEED_ERRHTTP, None
            self.fpf = feedparser.parse(youtube_feed)

        if not self.fpf:
            try:
                self.fpf = feedparser.parse(address,
                                            agent=USER_AGENT,
                                            etag=etag,
                                            modified=modified)
            except (TypeError, ValueError, KeyError, EOFError), e:
                logging.debug(u'   ***> [%-30s] ~FRFeed fetch error: %s' % 
                              (self.feed.title[:30], e))
                pass
                
        if not self.fpf:
            try:
                logging.debug(u'   ***> [%-30s] ~FRTurning off headers...' % 
                              (self.feed.title[:30]))
                self.fpf = feedparser.parse(address, agent=USER_AGENT)
            except (TypeError, ValueError, KeyError, EOFError), e:
                logging.debug(u'   ***> [%-30s] ~FRFetch failed: %s.' % 
                              (self.feed.title[:30], e))
                return FEED_ERRHTTP, None
            
        logging.debug(u'   ---> [%-30s] ~FYFeed fetch in ~FM%.4ss' % (
                      self.feed.title[:30], time.time() - start))

        return FEED_OK, self.fpf
        
    def get_identity(self):
        identity = "X"

        current_process = multiprocessing.current_process()
        if current_process._identity:
            identity = current_process._identity[0]

        return identity
    
    def fetch_youtube(self, address):
        username = None
        channel_id = None
        list_id = None
        
        if 'gdata.youtube.com' in address:
            try:
                username_groups = re.search('gdata.youtube.com/feeds/\w+/users/(\w+)/', address)
                if not username_groups:
                    return
                username = username_groups.group(1)
            except IndexError:
                return
        elif 'youtube.com/feeds/videos.xml?user=' in address:
            try:
                username = urlparse.parse_qs(urlparse.urlparse(address).query)['user'][0]
            except IndexError:
                return            
        elif 'youtube.com/feeds/videos.xml?channel_id=' in address:
            try:
                channel_id = urlparse.parse_qs(urlparse.urlparse(address).query)['channel_id'][0]
            except IndexError:
                return            
        elif 'youtube.com/playlist' in address:
            try:
                list_id = urlparse.parse_qs(urlparse.urlparse(address).query)['list'][0]
            except IndexError:
                return            
        
        if channel_id:
            video_ids_xml = requests.get("https://www.youtube.com/feeds/videos.xml?channel_id=%s" % channel_id)
            channel_json = requests.get("https://www.googleapis.com/youtube/v3/channels?part=snippet&id=%s&key=%s" %
                                       (channel_id, settings.YOUTUBE_API_KEY))
            channel = json.decode(channel_json.content)
            try:
                username = channel['items'][0]['snippet']['title']
                description = channel['items'][0]['snippet']['description']
            except (IndexError, KeyError):
                return
        elif list_id:
            playlist_json = requests.get("https://www.googleapis.com/youtube/v3/playlists?part=snippet&id=%s&key=%s" %
                                       (list_id, settings.YOUTUBE_API_KEY))
            playlist = json.decode(playlist_json.content)
            try:
                username = playlist['items'][0]['snippet']['title']
                description = playlist['items'][0]['snippet']['description']
            except (IndexError, KeyError):
                return
            channel_url = "https://www.youtube.com/playlist?list=%s" % list_id
        elif username:
            video_ids_xml = requests.get("https://www.youtube.com/feeds/videos.xml?user=%s" % username)
            description = "YouTube videos uploaded by %s" % username
        else:
            return
                    
        if list_id:
            playlist_json = requests.get("https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=%s&key=%s" %
                                       (list_id, settings.YOUTUBE_API_KEY))
            playlist = json.decode(playlist_json.content)
            try:
                video_ids = [video['snippet']['resourceId']['videoId'] for video in playlist['items']]
            except (IndexError, KeyError):
                return
        else:    
            if video_ids_xml.status_code != 200:
                return
            video_ids_soup = BeautifulSoup(video_ids_xml.content)
            channel_url = video_ids_soup.find('author').find('uri').getText()
            video_ids = []
            for video_id in video_ids_soup.findAll('yt:videoid'):
                video_ids.append(video_id.getText())
        
        videos_json = requests.get("https://www.googleapis.com/youtube/v3/videos?part=contentDetails%%2Csnippet&id=%s&key=%s" %
             (','.join(video_ids), settings.YOUTUBE_API_KEY))
        videos = json.decode(videos_json.content)

        data = {}
        data['title'] = ("%s's YouTube Videos" % username if 'Uploads' not in username else username)
        data['link'] = channel_url
        data['description'] = description
        data['lastBuildDate'] = datetime.datetime.utcnow()
        data['generator'] = 'NewsBlur YouTube API v3 Decrapifier - %s' % settings.NEWSBLUR_URL
        data['docs'] = None
        data['feed_url'] = address
        rss = feedgenerator.Atom1Feed(**data)

        for video in videos['items']:
            thumbnail = video['snippet']['thumbnails'].get('maxres')
            if not thumbnail:
                thumbnail = video['snippet']['thumbnails'].get('high')
            if not thumbnail:
                thumbnail = video['snippet']['thumbnails'].get('medium')
            duration_sec = isodate.parse_duration(video['contentDetails']['duration']).seconds
            if duration_sec >= 3600:
                hours = (duration_sec / 3600)
                minutes = (duration_sec - (hours*3600)) / 60
                seconds = duration_sec - (hours*3600) - (minutes*60)
                duration = "%s:%s:%s" % (hours, '{0:02d}'.format(minutes), '{0:02d}'.format(seconds))
            else:
                minutes = duration_sec / 60
                seconds = duration_sec - (minutes*60)
                duration = "%s:%s" % ('{0:02d}'.format(minutes), '{0:02d}'.format(seconds))
            content = """<div class="NB-youtube-player"><iframe allowfullscreen="true" src="%s?iv_load_policy=3"></iframe></div>
                         <div class="NB-youtube-stats"><small>
                             <b>From:</b> <a href="%s">%s</a><br />
                             <b>Duration:</b> %s<br />
                         </small></div><hr>
                         <div class="NB-youtube-description">%s</div>
                         <img src="%s" style="display:none" />""" % (
                ("https://www.youtube.com/embed/" + video['id']),
                channel_url, username,
                duration,
                linkify(linebreaks(video['snippet']['description'])),
                thumbnail['url'] if thumbnail else "",
            )

            link = "http://www.youtube.com/watch?v=%s" % video['id']
            story_data = {
                'title': video['snippet']['title'],
                'link': link,
                'description': content,
                'author_name': username,
                'categories': [],
                'unique_id': "tag:youtube.com,2008:video:%s" % video['id'],
                'pubdate': dateutil.parser.parse(video['snippet']['publishedAt']),
            }
            rss.add_item(**story_data)
        
        return rss.writeString('utf-8')
        
class ProcessFeed:
    def __init__(self, feed_id, fpf, options):
        self.feed_id = feed_id
        self.options = options
        self.fpf = fpf
    
    def refresh_feed(self):
        self.feed = Feed.get_by_id(self.feed_id)
        if self.feed_id != self.feed.pk:
            logging.debug(" ***> Feed has changed: from %s to %s" % (self.feed_id, self.feed.pk))
            self.feed_id = self.feed.pk
    
    def process(self):
        """ Downloads and parses a feed.
        """
        start = time.time()
        self.refresh_feed()
        
        ret_values = dict(new=0, updated=0, same=0, error=0)

        if hasattr(self.fpf, 'status'):
            if self.options['verbose']:
                if self.fpf.bozo and self.fpf.status != 304:
                    logging.debug(u'   ---> [%-30s] ~FRBOZO exception: %s ~SB(%s entries)' % (
                                  self.feed.title[:30],
                                  self.fpf.bozo_exception,
                                  len(self.fpf.entries)))
                    
            if self.fpf.status == 304:
                self.feed = self.feed.save()
                self.feed.save_feed_history(304, "Not modified")
                return FEED_SAME, ret_values
            
            # 302: Temporary redirect: ignore
            # 301: Permanent redirect: save it (after 20 tries)
            if self.fpf.status == 301:
                if self.fpf.href.endswith('feedburner.com/atom.xml'):
                    return FEED_ERRHTTP, ret_values
                redirects, non_redirects = self.feed.count_redirects_in_history('feed')
                self.feed.save_feed_history(self.fpf.status, "HTTP Redirect (%d to go)" % (20-len(redirects)))
                if len(redirects) >= 20 or len(non_redirects) == 0:
                    self.feed.feed_address = self.fpf.href
                if not self.feed.known_good:
                    self.feed.fetched_once = True
                    logging.debug("   ---> [%-30s] ~SB~SK~FRFeed is %s'ing. Refetching..." % (self.feed.title[:30], self.fpf.status))
                    self.feed = self.feed.schedule_feed_fetch_immediately()
                if not self.fpf.entries:
                    self.feed = self.feed.save()
                    self.feed.save_feed_history(self.fpf.status, "HTTP Redirect")
                    return FEED_ERRHTTP, ret_values
            if self.fpf.status >= 400:
                logging.debug("   ---> [%-30s] ~SB~FRHTTP Status code: %s. Checking address..." % (self.feed.title[:30], self.fpf.status))
                fixed_feed = None
                if not self.feed.known_good:
                    fixed_feed, feed = self.feed.check_feed_link_for_feed_address()
                if not fixed_feed:
                    self.feed.save_feed_history(self.fpf.status, "HTTP Error")
                else:
                    self.feed = feed
                self.feed = self.feed.save()
                return FEED_ERRHTTP, ret_values

        if not self.fpf.entries:
            if self.fpf.bozo and isinstance(self.fpf.bozo_exception, feedparser.NonXMLContentType):
                logging.debug("   ---> [%-30s] ~SB~FRFeed is Non-XML. %s entries. Checking address..." % (self.feed.title[:30], len(self.fpf.entries)))
                fixed_feed = None
                if not self.feed.known_good:
                    fixed_feed, feed = self.feed.check_feed_link_for_feed_address()
                if not fixed_feed:
                    self.feed.save_feed_history(552, 'Non-xml feed', self.fpf.bozo_exception)
                else:
                    self.feed = feed
                self.feed = self.feed.save()
                return FEED_ERRPARSE, ret_values
            elif self.fpf.bozo and isinstance(self.fpf.bozo_exception, xml.sax._exceptions.SAXException):
                logging.debug("   ---> [%-30s] ~SB~FRFeed has SAX/XML parsing issues. %s entries. Checking address..." % (self.feed.title[:30], len(self.fpf.entries)))
                fixed_feed = None
                if not self.feed.known_good:
                    fixed_feed, feed = self.feed.check_feed_link_for_feed_address()
                if not fixed_feed:
                    self.feed.save_feed_history(553, 'SAX Exception', self.fpf.bozo_exception)
                else:
                    self.feed = feed
                self.feed = self.feed.save()
                return FEED_ERRPARSE, ret_values
                
        # the feed has changed (or it is the first time we parse it)
        # saving the etag and last_modified fields
        original_etag = self.feed.etag
        self.feed.etag = self.fpf.get('etag')
        if self.feed.etag:
            self.feed.etag = self.feed.etag[:255]
        # some times this is None (it never should) *sigh*
        if self.feed.etag is None:
            self.feed.etag = ''
        if self.feed.etag != original_etag:
            self.feed.save(update_fields=['etag'])
            
        original_last_modified = self.feed.last_modified
        try:
            self.feed.last_modified = mtime(self.fpf.modified)
        except:
            self.feed.last_modified = None
            pass
        if self.feed.last_modified != original_last_modified:
            self.feed.save(update_fields=['last_modified'])
        
        self.fpf.entries = self.fpf.entries[:100]
        
        original_title = self.feed.feed_title
        if self.fpf.feed.get('title'):
            self.feed.feed_title = strip_tags(self.fpf.feed.get('title'))
        if self.feed.feed_title != original_title:
            self.feed.save(update_fields=['feed_title'])
        
        tagline = self.fpf.feed.get('tagline', self.feed.data.feed_tagline)
        if tagline:
            original_tagline = self.feed.data.feed_tagline
            self.feed.data.feed_tagline = utf8encode(tagline)
            if self.feed.data.feed_tagline != original_tagline:
                self.feed.data.save(update_fields=['feed_tagline'])

        if not self.feed.feed_link_locked:
            new_feed_link = self.fpf.feed.get('link') or self.fpf.feed.get('id') or self.feed.feed_link
            if new_feed_link != self.feed.feed_link:
                logging.debug("   ---> [%-30s] ~SB~FRFeed's page is different: %s to %s" % (self.feed.title[:30], self.feed.feed_link, new_feed_link))               
                redirects, non_redirects = self.feed.count_redirects_in_history('page')
                self.feed.save_page_history(301, "HTTP Redirect (%s to go)" % (20-len(redirects)))
                if len(redirects) >= 20 or len(non_redirects) == 0:
                    self.feed.feed_link = new_feed_link
                    self.feed.save(update_fields=['feed_link'])
        
        # Determine if stories aren't valid and replace broken guids
        guids_seen = set()
        permalinks_seen = set()
        for entry in self.fpf.entries:
            guids_seen.add(entry.get('guid'))
            permalinks_seen.add(Feed.get_permalink(entry))
        guid_difference = len(guids_seen) != len(self.fpf.entries)
        single_guid = len(guids_seen) == 1
        replace_guids = single_guid and guid_difference
        permalink_difference = len(permalinks_seen) != len(self.fpf.entries)
        single_permalink = len(permalinks_seen) == 1
        replace_permalinks = single_permalink and permalink_difference
        
        # Compare new stories to existing stories, adding and updating
        start_date = datetime.datetime.utcnow()
        story_hashes = []
        stories = []
        for entry in self.fpf.entries:
            story = pre_process_story(entry)
            if story.get('published') < start_date:
                start_date = story.get('published')
            if replace_guids:
                if replace_permalinks:
                    new_story_guid = unicode(story.get('published'))
                    if self.options['verbose']:
                        logging.debug(u'   ---> [%-30s] ~FBReplacing guid (%s) with timestamp: %s' % (
                                      self.feed.title[:30],
                                      story.get('guid'), new_story_guid))
                    story['guid'] = new_story_guid
                else:
                    new_story_guid = Feed.get_permalink(story)
                    if self.options['verbose']:
                        logging.debug(u'   ---> [%-30s] ~FBReplacing guid (%s) with permalink: %s' % (
                                      self.feed.title[:30],
                                      story.get('guid'), new_story_guid))
                    story['guid'] = new_story_guid
            story['story_hash'] = MStory.feed_guid_hash_unsaved(self.feed.pk, story.get('guid'))
            stories.append(story)
            story_hashes.append(story.get('story_hash'))

        existing_stories = dict((s.story_hash, s) for s in MStory.objects(
            story_hash__in=story_hashes,
            # story_date__gte=start_date,
            # story_feed_id=self.feed.pk
        ))

        ret_values = self.feed.add_update_stories(stories, existing_stories,
                                                  verbose=self.options['verbose'],
                                                  updates_off=self.options['updates_off'])

        if (hasattr(self.fpf, 'feed') and 
            hasattr(self.fpf.feed, 'links') and self.fpf.feed.links):
            hub_url = None
            self_url = self.feed.feed_address
            for link in self.fpf.feed.links:
                if link['rel'] == 'hub' and not hub_url:
                    hub_url = link['href']
                elif link['rel'] == 'self':
                    self_url = link['href']
            push_expired = False
            if self.feed.is_push:
                try:
                    push_expired = self.feed.push.lease_expires < datetime.datetime.now()
                except PushSubscription.DoesNotExist:
                    self.feed.is_push = False
            if (hub_url and self_url and not settings.DEBUG and
                self.feed.active_subscribers > 0 and
                (push_expired or not self.feed.is_push or self.options.get('force'))):
                logging.debug(u'   ---> [%-30s] ~BB~FW%sSubscribing to PuSH hub: %s' % (
                              self.feed.title[:30],
                              "~SKRe-~SN" if push_expired else "", hub_url))
                try:
                    PushSubscription.objects.subscribe(self_url, feed=self.feed, hub=hub_url)
                except TimeoutError:
                    logging.debug(u'   ---> [%-30s] ~BB~FW~FRTimed out~FW subscribing to PuSH hub: %s' % (
                                  self.feed.title[:30], hub_url))                    
            elif (self.feed.is_push and 
                  (self.feed.active_subscribers <= 0 or not hub_url)):
                logging.debug(u'   ---> [%-30s] ~BB~FWTurning off PuSH, no hub found' % (
                              self.feed.title[:30]))
                self.feed.is_push = False
                self.feed = self.feed.save()

        logging.debug(u'   ---> [%-30s] ~FYParsed Feed: %snew=%s~SN~FY %sup=%s~SN same=%s%s~SN %serr=%s~SN~FY total=~SB%s' % (
                      self.feed.title[:30], 
                      '~FG~SB' if ret_values['new'] else '', ret_values['new'],
                      '~FY~SB' if ret_values['updated'] else '', ret_values['updated'],
                      '~SB' if ret_values['same'] else '', ret_values['same'],
                      '~FR~SB' if ret_values['error'] else '', ret_values['error'],
                      len(self.fpf.entries)))
        self.feed.update_all_statistics(has_new_stories=bool(ret_values['new']), force=self.options['force'])
        if ret_values['new']:
            self.feed.trim_feed()
            self.feed.expire_redis()
        self.feed.save_feed_history(200, "OK")

        if self.options['verbose']:
            logging.debug(u'   ---> [%-30s] ~FBTIME: feed parse in ~FM%.4ss' % (
                          self.feed.title[:30], time.time() - start))
        
        return FEED_OK, ret_values

        
class Dispatcher:
    def __init__(self, options, num_threads):
        self.options = options
        self.feed_stats = {
            FEED_OK:0,
            FEED_SAME:0,
            FEED_ERRPARSE:0,
            FEED_ERRHTTP:0,
            FEED_ERREXC:0}
        self.feed_trans = {
            FEED_OK:'ok',
            FEED_SAME:'unchanged',
            FEED_ERRPARSE:'cant_parse',
            FEED_ERRHTTP:'http_error',
            FEED_ERREXC:'exception'}
        self.feed_keys = sorted(self.feed_trans.keys())
        self.num_threads = num_threads
        self.time_start = datetime.datetime.utcnow()
        self.workers = []

    def refresh_feed(self, feed_id):
        """Update feed, since it may have changed"""
        try:
            return Feed.objects.using('default').get(pk=feed_id)
        except Feed.DoesNotExist:
            return
        
    def process_feed_wrapper(self, feed_queue):
        delta = None
        current_process = multiprocessing.current_process()
        identity = "X"
        feed = None
        
        if current_process._identity:
            identity = current_process._identity[0]
            
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
            try:
                feed = self.refresh_feed(feed_id)
                
                skip = False
                if self.options.get('fake'):
                    skip = True
                    weight = "-"
                    quick = "-"
                    rand = "-"
                elif (self.options.get('quick') and not self.options['force'] and 
                      feed.known_good and feed.fetched_once and not feed.is_push):
                    weight = feed.stories_last_month * feed.num_subscribers
                    random_weight = random.randint(1, max(weight, 1))
                    quick = float(self.options.get('quick', 0))
                    rand = random.random()
                    if random_weight < 100 and rand < quick:
                        skip = True
                elif False and feed.feed_address.startswith("http://news.google.com/news"):
                    skip = True
                    weight = "-"
                    quick = "-"
                    rand = "-"
                if skip:
                    logging.debug('   ---> [%-30s] ~BGFaking fetch, skipping (%s/month, %s subs, %s < %s)...' % (
                        feed.title[:30],
                        weight,
                        feed.num_subscribers,
                        rand, quick))
                    continue
                    
                ffeed = FetchFeed(feed_id, self.options)
                ret_feed, fetched_feed = ffeed.fetch()
                feed_fetch_duration = time.time() - start_duration
                
                if ((fetched_feed and ret_feed == FEED_OK) or self.options['force']):
                    pfeed = ProcessFeed(feed_id, fetched_feed, self.options)
                    ret_feed, ret_entries = pfeed.process()
                    feed = pfeed.feed
                    feed_process_duration = time.time() - start_duration
                    
                    if (ret_entries and ret_entries['new']) or self.options['force']:
                        start = time.time()
                        if not feed.known_good or not feed.fetched_once:
                            feed.known_good = True
                            feed.fetched_once = True
                            feed = feed.save()
                        if self.options['force'] or random.random() <= 0.02:
                            logging.debug('   ---> [%-30s] ~FBPerforming feed cleanup...' % (feed.title[:30],))
                            start_cleanup = time.time()
                            feed.sync_redis()
                            logging.debug('   ---> [%-30s] ~FBDone with feed cleanup. Took ~SB%.4s~SN sec.' % (feed.title[:30], time.time() - start_cleanup))
                        try:
                            self.count_unreads_for_subscribers(feed)
                        except TimeoutError:
                            logging.debug('   ---> [%-30s] Unread count took too long...' % (feed.title[:30],))
                        if self.options['verbose']:
                            logging.debug(u'   ---> [%-30s] ~FBTIME: unread count in ~FM%.4ss' % (
                                          feed.title[:30], time.time() - start))
            except urllib2.HTTPError, e:
                logging.debug('   ---> [%-30s] ~FRFeed throws HTTP error: ~SB%s' % (unicode(feed_id)[:30], e.fp.read()))
                feed.save_feed_history(e.code, e.msg, e.fp.read())
                fetched_feed = None
            except Feed.DoesNotExist, e:
                logging.debug('   ---> [%-30s] ~FRFeed is now gone...' % (unicode(feed_id)[:30]))
                continue
            except TimeoutError, e:
                logging.debug('   ---> [%-30s] ~FRFeed fetch timed out...' % (feed.title[:30]))
                feed.save_feed_history(505, 'Timeout', e)
                feed_code = 505
                fetched_feed = None
            except Exception, e:
                logging.debug('[%d] ! -------------------------' % (feed_id,))
                tb = traceback.format_exc()
                logging.error(tb)
                logging.debug('[%d] ! -------------------------' % (feed_id,))
                ret_feed = FEED_ERREXC 
                feed = Feed.get_by_id(getattr(feed, 'pk', feed_id))
                if not feed: continue
                feed.save_feed_history(500, "Error", tb)
                feed_code = 500
                fetched_feed = None
                # mail_feed_error_to_admin(feed, e, local_vars=locals())
                if (not settings.DEBUG and hasattr(settings, 'RAVEN_CLIENT') and
                    settings.RAVEN_CLIENT):
                    settings.RAVEN_CLIENT.captureException()

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
                
            if not feed: continue
            feed = self.refresh_feed(feed.pk)
            if not feed: continue
            
            if ((self.options['force']) or 
                (random.random() > .9) or
                (fetched_feed and
                 feed.feed_link and
                 feed.has_page and
                 (ret_feed == FEED_OK or
                  (ret_feed == FEED_SAME and feed.stories_last_month > 10)))):
                  
                logging.debug(u'   ---> [%-30s] ~FYFetching page: %s' % (feed.title[:30], feed.feed_link))
                page_importer = PageImporter(feed)
                try:
                    page_data = page_importer.fetch_page()
                    page_duration = time.time() - start_duration
                except TimeoutError, e:
                    logging.debug('   ---> [%-30s] ~FRPage fetch timed out...' % (feed.title[:30]))
                    page_data = None
                    feed.save_page_history(555, 'Timeout', '')
                except Exception, e:
                    logging.debug('[%d] ! -------------------------' % (feed_id,))
                    tb = traceback.format_exc()
                    logging.error(tb)
                    logging.debug('[%d] ! -------------------------' % (feed_id,))
                    feed.save_page_history(550, "Page Error", tb)
                    fetched_feed = None
                    page_data = None
                    # mail_feed_error_to_admin(feed, e, local_vars=locals())
                    if (not settings.DEBUG and hasattr(settings, 'RAVEN_CLIENT') and
                        settings.RAVEN_CLIENT):
                        settings.RAVEN_CLIENT.captureException()
                
                feed = self.refresh_feed(feed.pk)
                logging.debug(u'   ---> [%-30s] ~FYFetching icon: %s' % (feed.title[:30], feed.feed_link))
                force = self.options['force']
                if random.random() > .99:
                    force = True
                icon_importer = IconImporter(feed, page_data=page_data, force=force)
                try:
                    icon_importer.save()
                    icon_duration = time.time() - start_duration
                except TimeoutError, e:
                    logging.debug('   ---> [%-30s] ~FRIcon fetch timed out...' % (feed.title[:30]))
                    feed.save_page_history(556, 'Timeout', '')
                except Exception, e:
                    logging.debug('[%d] ! -------------------------' % (feed_id,))
                    tb = traceback.format_exc()
                    logging.error(tb)
                    logging.debug('[%d] ! -------------------------' % (feed_id,))
                    # feed.save_feed_history(560, "Icon Error", tb)
                    # mail_feed_error_to_admin(feed, e, local_vars=locals())
                    if (not settings.DEBUG and hasattr(settings, 'RAVEN_CLIENT') and
                        settings.RAVEN_CLIENT):
                        settings.RAVEN_CLIENT.captureException()
            else:
                logging.debug(u'   ---> [%-30s] ~FBSkipping page fetch: (%s on %s stories) %s' % (feed.title[:30], self.feed_trans[ret_feed], feed.stories_last_month, '' if feed.has_page else ' [HAS NO PAGE]'))
            
            feed = self.refresh_feed(feed.pk)
            delta = time.time() - start_time
            
            feed.last_load_time = round(delta)
            feed.fetched_once = True
            try:
                feed = feed.save(update_fields=['last_load_time', 'fetched_once'])
            except IntegrityError:
                logging.debug("   ---> [%-30s] ~FRIntegrityError on feed: %s" % (feed.title[:30], feed.feed_address,))
            
            if ret_entries and ret_entries['new']:
                self.publish_to_subscribers(feed)
                
            done_msg = (u'%2s ---> [%-30s] ~FYProcessed in ~FM~SB%.4ss~FY~SN (~FB%s~FY) [%s]' % (
                identity, feed.title[:30], delta,
                feed.pk, self.feed_trans[ret_feed],))
            logging.debug(done_msg)
            total_duration = time.time() - start_duration
            MAnalyticsFetcher.add(feed_id=feed.pk, feed_fetch=feed_fetch_duration,
                                  feed_process=feed_process_duration, 
                                  page=page_duration, icon=icon_duration,
                                  total=total_duration, feed_code=feed_code)
            
            self.feed_stats[ret_feed] += 1
            
        if len(feed_queue) == 1:
            return feed
        
        # time_taken = datetime.datetime.utcnow() - self.time_start
    
    def publish_to_subscribers(self, feed):
        try:
            r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
            listeners_count = r.publish(str(feed.pk), 'story:new')
            if listeners_count:
                logging.debug("   ---> [%-30s] ~FMPublished to %s subscribers" % (feed.title[:30], listeners_count))
        except redis.ConnectionError:
            logging.debug("   ***> [%-30s] ~BMRedis is unavailable for real-time." % (feed.title[:30],))
        
    def count_unreads_for_subscribers(self, feed):
        user_subs = UserSubscription.objects.filter(feed=feed, 
                                                    active=True,
                                                    user__profile__last_seen_on__gte=feed.unread_cutoff)\
                                            .order_by('-last_read_date')
        
        if not user_subs.count():
            return
            
        for sub in user_subs:
            if not sub.needs_unread_recalc:
                sub.needs_unread_recalc = True
                sub.save()

        if self.options['compute_scores']:
            r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
            stories = MStory.objects(story_feed_id=feed.pk,
                                     story_date__gte=feed.unread_cutoff)
            stories = Feed.format_stories(stories, feed.pk)
            story_hashes = r.zrangebyscore('zF:%s' % feed.pk, int(feed.unread_cutoff.strftime('%s')),
                                           int(time.time() + 60*60*24))
            missing_story_hashes = set(story_hashes) - set([s['story_hash'] for s in stories])
            if missing_story_hashes:
                missing_stories = MStory.objects(story_feed_id=feed.pk,
                                                 story_hash__in=missing_story_hashes)\
                                        .read_preference(pymongo.ReadPreference.PRIMARY)
                missing_stories = Feed.format_stories(missing_stories, feed.pk)
                stories = missing_stories + stories
                logging.debug(u'   ---> [%-30s] ~FYFound ~SB~FC%s(of %s)/%s~FY~SN un-secondaried stories while computing scores' % (feed.title[:30], len(missing_stories), len(missing_story_hashes), len(stories)))
            cache.set("S:%s" % feed.pk, stories, 60)
            logging.debug(u'   ---> [%-30s] ~FYComputing scores: ~SB%s stories~SN with ~SB%s subscribers ~SN(%s/%s/%s)' % (
                          feed.title[:30], len(stories), user_subs.count(),
                          feed.num_subscribers, feed.active_subscribers, feed.premium_subscribers))        
            self.calculate_feed_scores_with_stories(user_subs, stories)
        elif self.options.get('mongodb_replication_lag'):
            logging.debug(u'   ---> [%-30s] ~BR~FYSkipping computing scores: ~SB%s seconds~SN of mongodb lag' % (
              feed.title[:30], self.options.get('mongodb_replication_lag')))
    
    @timelimit(10)
    def calculate_feed_scores_with_stories(self, user_subs, stories):
        for sub in user_subs:
            silent = False if self.options['verbose'] >= 2 else True
            sub.calculate_feed_scores(silent=silent, stories=stories)
            
    def add_jobs(self, feeds_queue, feeds_count=1):
        """ adds a feed processing job to the pool
        """
        self.feeds_queue = feeds_queue
        self.feeds_count = feeds_count
            
    def run_jobs(self):
        if self.options['single_threaded']:
            return self.process_feed_wrapper(self.feeds_queue[0])
        else:
            for i in range(self.num_threads):
                feed_queue = self.feeds_queue[i]
                self.workers.append(multiprocessing.Process(target=self.process_feed_wrapper,
                                                            args=(feed_queue,)))
            for i in range(self.num_threads):
                self.workers[i].start()

                