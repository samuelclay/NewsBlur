# Original API work by Dananjaya Ramanayake <dananjaya86@gmail.com>
# Retooled by Samuel Clay, August 2011

import urllib, urllib2
import cookielib
import json

__author__ = "Dananjaya Ramanayake <dananjaya86@gmail.com>, Samuel Clay <samuel@ofbrooklyn.com>"
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
            params   = func(*args, **kwargs) or {}
            url      = self.endpoint
            if not url:
                url  = params['url']
                del params['url']
            params   = urllib.urlencode(params)
            url      = "%s%s" % (API_URL, url)
            
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
        return {
            'feeds': feeds
        }

    @request(None)
    def page(self, feed_id):
        '''
        Retrieve the original page from a single feed.
        '''
        return {
            'url': 'reader/page/%s' % feed_id
        }

    @request(None)
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

    def statistics(self, id_no):
        '''
    
        If you only want a user's classifiers, use /classifiers/:id.
            Omit the feed_id to get all classifiers for all subscriptions.
        
        '''

        url = 'http://www.newsblur.com/rss_feeds/statistics/%d' % id_no
        return urllib.urlopen(url).read()

    def feed_autocomplete(self, term):
        '''
    
        Get a list of feeds that contain a search phrase.
        Searches by feed address, feed url, and feed title, in that order.
        Will only show sites with 2+ subscribers.

        '''
        url = 'http://www.newsblur.com/rss_feeds/feed_autocomplete'
        params = urllib.urlencode({'term':term})
        return urllib.urlopen(url,params).read()

    def read(self, page=1):
        '''
    
        Retrieve stories from a single feed.
    
        '''
        url = 'http://www.newsblur.com/reader/feed/%d' % page
        return urllib.urlopen(url).read()

    def starred_stories(self, page=1):
        '''
    
        Retrieve a user's starred stories.
    
        '''
        url = 'http://www.newsblur.com/reader/starred_stories'
        params = urllib.urlencode({'page':page})
        return urllib.urlopen(url,params).read()

    def river_stories(self, feeds,page=1,read_stories_count=0):
        '''
    
        Retrieve stories from a collection of feeds. This is known as the River of News.
        Stories are ordered in reverse chronological order.
        
        '''

        url = 'http://www.newsblur.com/reader/river_stories'
        params = urllib.urlencode({'feeds':feeds,'page':page,'read_stories_count':read_stories_count})
        return urllib.urlopen(url,params).read()

    def mark_story_as_read(self, story_id,feed_id):
        '''
    
         Mark stories as read.
            Multiple story ids can be sent at once.
            Each story must be from the same feed.
        
            '''

        url = 'http://www.newsblur.com/reader/mark_story_as_read'
        params = urllib.urlencode({'story_id':story_id,'feed_id':feed_id})
        return urllib.urlopen(url,params).read()

    def mark_story_as_starred(self, story_id,feed_id):
        '''
    
        Mark a story as starred (saved).
    
        '''
        url = 'http://www.newsblur.com/reader/mark_story_as_starred'
        params = urllib.urlencode({'story_id':story_id,'feed_id':feed_id})
        return urllib.urlopen(url,params).read()

    def mark_all_as_read(self, days=0):
        '''
    
        Mark all stories in a feed or list of feeds as read.
    
        '''
        url = 'http://www.newsblur.com/reader/mark_all_as_read'
        params = urllib.urlencode({'days':days})
        return urllib.urlopen(url,params).read()

    def add_url(self, url,folder='[Top Level]'):
        '''
    
        Add a feed by its URL. 
        Can be either the RSS feed or the website itself.
    
        '''
        url = 'http://www.newsblur.com/reader/add_url'
        params = urllib.urlencode({'url':url,'folder':folder})
        return urllib.urlopen(url,params).read()


    def add_folder(self, folder,parent_folder='[Top Level]'):
        '''
    
        Add a new folder.
    
        '''
    
        url = 'http://www.newsblur.com/reader/add_folder'
        params = urllib.urlencode({'folder':folder,'parent_folder':parent_folder})
        return urllib.urlopen(url,params).read()

    def rename_feed(self, feed_title,feed_id):
        '''
    
        Rename a feed title. Only the current user will see the new title.
    
        '''
        url = 'http://www.newsblur.com/reader/rename_feed'
        params = urllib.urlencode({'feed_title':feed_title,'feed_id':feed_id})
        return urllib.urlopen(url,params).read()

    def delete_feed(self, feed_id,in_folder):
        '''
    
        Unsubscribe from a feed. Removes it from the folder.
        Set the in_folder parameter to remove a feed from the correct 
        folder, in case the user is subscribed to the feed in multiple folders.

        ''' 
        url = 'http://www.newsblur.com/reader/delete_feed'
        params = urllib.urlencode({'feed_id':feed_id,'in_folder':in_folder})
        return urllib.urlopen(url,params).read()

    def rename_folder(self, folder_to_rename,new_folder_name,in_folder):
        '''
    
        Rename a folder.
    
        '''
        url = 'http://www.newsblur.com/reader/rename_folder'
        params = urllib.urlencode({'folder_to_rename':folder_to_rename,'new_folder_name':new_folder_name,'in_folder':in_folder})
        return urllib.urlopen(url,params).read()

    def delete_folder(self, folder_to_delete,in_folder,feed_id):
        '''
    
        Delete a folder and unsubscribe from all feeds inside.
    
        '''
        url = 'http://www.newsblur.com/reader/delete_folder'
        params = urllib.urlencode({'folder_to_delete':folder_to_delete,'in_folder':in_folder,'feed_id':feed_id})
        return urllib.urlopen(url,params).read()


    def mark_feed_as_read(self, feed_id):
        '''
    
        Mark a list of feeds as read.
    
        '''
        url = 'http://www.newsblur.com/reader/mark_feed_as_read'
        params = urllib.urlencode({'feed_id':feed_id})
        return urllib.urlopen(url,params).read()


    def save_feed_order(self, folders):
        '''
    
        Reorder feeds and move them around between folders.
            The entire folder structure needs to be serialized.
        
        '''

        url = 'http://www.newsblur.com/reader/save_feed_order'
        params = urllib.urlencode({'folders':folders})
        return urllib.urlopen(url,params).read()


    def classifier(self, id_no):
        '''
    
            Get the intelligence classifiers for a user's site.
            Only includes the user's own classifiers. 
            Use /reader/feeds_trainer for popular classifiers.
        
        '''

        url = 'http://www.newsblur.com/classifier/%d' % id_no
        return urllib.urlopen(url).read()


    def classifier_save(self, like_type,dislike_type,remove_like_type,remove_dislike_type):
        '''
    
        Save intelligence classifiers (tags, titles, authors, and the feed) for a feed.
    
        '''
        url = 'http://www.newsblur.com/classifier/save'
        params = urllib.urlencode({'like_[TYPE]':like_type,
                       'dislike_[TYPE]':dislike_type,
                       'remove_like_[TYPE]':remove_like_type,
                       'remove_dislike_[TYPE]':remove_dislike_type})
        return urllib.urlopen(url,params).read()


    def opml_export(self):
        '''
    
        Download a backup of feeds and folders as an OPML file.
        Contains folders and feeds in XML; useful for importing in another RSS reader.
    
        '''
        url = 'http://www.newsblur.com/import/opml_export'
        return urllib.urlopen(url).read()



    def opml_upload(self, opml_file):
        '''
    
        Upload an OPML file.
    
        '''
        url = 'http://www.newsblur.com/import/opml_upload'
        f = open(opml_file)
        params = urllib.urlencode({'file':f})
        f.close()
        return urllib.urlopen(url,params).read()
    

