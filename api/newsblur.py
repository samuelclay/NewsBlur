# Original API work by Dananjaya Ramanayake <dananjaya86@gmail.com>
# Retooled by Samuel Clay, August 2011
# Modified by Luke Hagan, 2011-11-05

import urllib, urllib2
import cookielib
import json

__author__ = "Dananjaya Ramanayake <dananjaya86@gmail.com>, Samuel Clay <samuel@newsblur.com>"
__version__ = "1.0"

API_URL = "http://www.newsblur.com/"
# API_URL = "http://nb.local.host:8000/"


class request():
    
    opener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cookielib.CookieJar()))
    
    def __init__(self, endpoint=None, method='get'):
        self.endpoint = endpoint
        self.method = method

    def __call__(self, func):
        def wrapped(*args, **kwargs):
            params = func(*args, **kwargs) or {}
            url    = self.endpoint if self.endpoint else params.pop('url')
            params = urllib.urlencode(params)
            url    = "%s%s" % (API_URL, url)
            
            response = self.opener.open(url, params).read()
            
            return json.loads(response)
        return wrapped

class API:

    @request('api/login', method='post')
    def login(self, username, password):
        '''
        Login as an existing user.
        If a user has no password set, you cannot just send any old password. 
        Required parameters, username and password, must be of string type.
        '''
        return {
            'username': username,
            'password': password
        }

    @request('api/logout')
    def logout(self):
        '''
        Logout the currently logged in user.
        '''
        return

    @request('api/signup')
    def signup(self, username, password, email):
        '''
        Create a new user.
        All three required parameters must be of type string.
        '''
        return {
            'signup_username': username,
            'signup_password': password,
            'signup_email': email
        }

    @request('rss_feeds/search_feed')
    def search_feed(self, address, offset=0):
        '''
        Retrieve information about a feed from its website or RSS address.
        Parameter address must be of type string while parameter offset must be an integer.
        Will return a feed.
        '''
        return {
            'address': address,
            'offset': offset
        }

    @request('reader/feeds')
    def feeds(self, include_favicons=True, flat=False):
        '''
        Retrieve a list of feeds to which a user is actively subscribed.
        Includes the 3 unread counts (positive, neutral, negative), as well as optional favicons.
        '''
        return {
            'include_favicons': include_favicons,
            'flat': flat
        }

    @request('reader/favicons')
    def favicons(self, feeds=None):
        '''
        Retrieve a list of favicons for a list of feeds. 
        Used when combined with /reader/feeds and include_favicons=false, so the feeds request contains far less data. 
        Useful for mobile devices, but requires a second request. 
        '''
        data = []
        for feed in feeds:
            data.append( ("feeds", feed) )
        return data

    @request()
    def page(self, feed_id):
        '''
        Retrieve the original page from a single feed.
        '''
        return {
            'url': 'reader/page/%s' % feed_id
        }

    @request()
    def feed(self, feed_id, page=1):
        '''
        Retrieve the stories from a single feed.
        '''
        return {
            'url': 'reader/feed/%s' % feed_id,
            'page': page,
        }

    @request('reader/refresh_feeds')
    def refresh_feeds(self):
        '''
        Up-to-the-second unread counts for each active feed.
            Poll for these counts no more than once a minute.
        '''
        return

    @request('reader/feeds_trainer')
    def feeds_trainer(self, feed_id=None):
        '''
         Retrieves all popular and known intelligence classifiers.
            Also includes user's own classifiers.
        '''
        return {
            'feed_id': feed_id,
        }
        
    @request()
    def statistics(self, feed_id=None):
        '''
        If you only want a user's classifiers, use /classifiers/:id.
            Omit the feed_id to get all classifiers for all subscriptions.
        '''
        return {
            'url': 'rss_feeds/statistics/%d' % feed_id
        }
        
    @request('rss_feeds/feed_autocomplete')
    def feed_autocomplete(self, term):
        '''
        Get a list of feeds that contain a search phrase.
        Searches by feed address, feed url, and feed title, in that order.
        Will only show sites with 2+ subscribers.
        '''
        return {
            'term': term
        }

    @request('reader/starred_stories')
    def starred_stories(self, page=1):
        '''
        Retrieve a user's starred stories.
        '''
        return {
            'page': page,
        }

    @request('reader/river_stories')
    def river_stories(self, feeds, page=1, read_stories_count=0):
        '''
        Retrieve stories from a collection of feeds. This is known as the River of News.
        Stories are ordered in reverse chronological order.
        `read_stories_count` is the number of stories that have been read in this
        continuation, so NewsBlur can efficiently skip those stories when retrieving
        new stories. Takes an array of feed ids.
        '''
        
        data = [ ('page', page), ('read_stories_count', read_stories_count) ]
        for feed in feeds:
            data.append( ("feeds", feed) )
        return data
    
    @request('reader/mark_story_hashes_as_read')
    def mark_story_hashes_as_read(self, story_hashes):
        '''
         Mark stories as read using their unique story_hash.
        '''

        data = []
        for hash in story_hashes:
            data.append( ("story_hash", hash) )
        return data

    @request('reader/mark_story_as_read')
    def mark_story_as_read(self, feed_id, story_ids):
        '''
         Mark stories as read.
            Multiple story ids can be sent at once.
            Each story must be from the same feed.
            Takes an array of story ids.
        '''
        
        data = [ ('feed_id', feed_id) ]
        for story_id in story_ids:
            data.append( ("story_id", story_id) )
        return data

    @request('reader/mark_story_as_starred')
    def mark_story_as_starred(self, feed_id, story_id):
        '''
        Mark a story as starred (saved).
        '''
        return {
            'feed_id': feed_id,
            'story_id': story_id,
        }

    @request('reader/mark_all_as_read')
    def mark_all_as_read(self, days=0):
        '''
        Mark all stories in a feed or list of feeds as read.
        '''
        return {
            'days': days,
        }

    @request('reader/add_url')
    def add_url(self, url, folder=''):
        '''
        Add a feed by its URL. 
        Can be either the RSS feed or the website itself.
        '''
        return {
            'url': url,
            'folder': folder,
        }

    @request('reader/add_folder')
    def add_folder(self, folder, parent_folder=''):
        '''
        Add a new folder.
        '''
        return {
            'folder': folder,
            'parent_folder': parent_folder,
        }
    
    @request('reader/rename_feed')
    def rename_feed(self, feed_id, feed_title):
        '''
        Rename a feed title. Only the current user will see the new title.
        '''
        return {
            'feed_id': feed_id,
            'feed_title': feed_title,
        }
    
    @request('reader/delete_feed')
    def delete_feed(self, feed_id, in_folder):
        '''
        Unsubscribe from a feed. Removes it from the folder.
        Set the in_folder parameter to remove a feed from the correct 
        folder, in case the user is subscribed to the feed in multiple folders.
        ''' 
        return {
            'feed_id': feed_id,
            'in_folder': in_folder,
        }
    
    @request('reader/rename_folder')
    def rename_folder(self, folder_to_rename, new_folder_name, in_folder):
        '''
        Rename a folder.
        '''
        return {
            'folder_to_rename': folder_to_rename,
            'new_folder_name': new_folder_name,
            'in_folder': in_folder,
        }
    
    @request('reader/delete_folder')
    def delete_folder(self, folder_to_delete, in_folder):
        '''
        Delete a folder and unsubscribe from all feeds inside.
        '''
        return {
            'folder_to_delete': folder_to_delete,
            'in_folder': in_folder,
        }
    
    @request('reader/mark_feed_as_read')
    def mark_feed_as_read(self, feed_ids):
        '''
        Mark a list of feeds as read.
        Takes an array of feeds.
        '''
        data = []
        for feed in feed_ids:
            data.append( ("feed_id", feed) )
        return data

    @request('reader/save_feed_order')
    def save_feed_order(self, folders):
        '''
        Reorder feeds and move them around between folders.
            The entire folder structure needs to be serialized.
        '''
        return {
            'folders': folders,
        }

    @request()
    def classifier(self, feed_id):
        '''
            Get the intelligence classifiers for a user's site.
            Only includes the user's own classifiers. 
            Use /reader/feeds_trainer for popular classifiers.
        '''
        return {
            'url': '/classifier/%d' % feed_id,
        }

    @request('classifier/save')
    def classifier_save(self, like_type, dislike_type, remove_like_type, remove_dislike_type):
        '''
        Save intelligence classifiers (tags, titles, authors, and the feed) for a feed.
        
        TODO: Make this usable.
        '''
        raise NotImplemented

    
    @request('import/opml_export')
    def opml_export(self):
        '''
        Download a backup of feeds and folders as an OPML file.
        Contains folders and feeds in XML; useful for importing in another RSS reader.
        '''
        return
    
    @request('import/opml_upload')
    def opml_upload(self, opml_file):
        '''
        Upload an OPML file.
        '''
        f = open(opml_file)
        return {
            'file': f
        }
    

