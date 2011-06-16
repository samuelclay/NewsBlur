#!/usr/bin/python

"""newsblur.py - An API wrapper library for newsblur.com"""

import urllib

__author__ = 'Dananjaya Ramanayake <dananjaya86@gmail.com>'
__version__ = "0.1"

def login(username,password):
	'''
	
	Login as an existing user.
	If a user has no password set, you cannot just send any old password. 
	Required parameters, username and password, must be of string type.
	
	'''
	url = 'http://www.newsblur.com/api/login'
	params = urllib.urlencode({'username':username,'password':password})
	return urllib.urlopen(url,params).read()

def logout():
	'''
	
	Logout the currently logged in user.
	
	'''
	url = 'http://www.newsblur.com/api/logout'
	return urllib.urlopen(url).read()

def signup(username,password,email):
	'''
	
	Create a new user.
	All three required parameters must be of type string.
	
	'''
	url = 'http://www.newsblur.com/api/signup'
	params = urllib.urlencode({'signup_username':username,'signup_password':password,'signup_email':email})
	return urllib.urlopen(url,params).read()

def search_feed(address,offset=1):
	'''
	
	Retrieve information about a feed from its website or RSS address.
	Parameter address must be of type string while parameter offset must be an integer.
	Will return a feed.
	
	'''
	url = 'http://www.newsblur.com/rss_feeds/search_feed'
	params = urllib.urlencode({'address':address,'offset':offset})
	return urllib.urlopen(url,params).read()

def feeds(include_favicons=True,flat=False):
	'''
	
	Retrieve a list of feeds to which a user is actively subscribed.
        Includes the 3 unread counts (positive, neutral, negative), as well as optional favicons.

        '''
	
	url = 'http://www.newsblur.com/reader/feeds'
	params = urllib.urlencode({'include_favicons':include_favicons,'flat':flat})
	return urllib.urlopen(url,params).read()


def favicons(feeds=[1,2,3]):
	'''
	
	Retrieve a list of favicons for a list of feeds. 
	Used when combined with /reader/feeds and include_favicons=false, so the feeds request contains far less data. 
	Useful for mobile devices, but requires a second request. 
	
	'''
	url = 'http://www.newsblur.com/reader/favicons'
	params = urllib.urlencode({'feeds':feeds})
	return urllib.urlopen(url,params).read()
	
def id(id_no):
	'''
	
	Retrieve the original page from a single feed.
	
	'''
	url = 'http://www.newsblur.com/reader/page/%d' % id_no
	return urllib.urlopen(url).read()

def refresh_feeds():
	'''
	
	Up-to-the-second unread counts for each active feed.
        Poll for these counts no more than once a minute.
        
        '''

	url = 'http://www.newsblur.com/reader/refresh_feeds'
	return urllib.urlopen(url).read()

def feeds_trainer(feed_id):
	'''
	
	 Retrieves all popular and known intelligence classifiers.
        Also includes user's own classifiers.
        
        '''

	url = 'http://www.newsblur.com/reader/feeds_trainer'
	params = urllib.urlencode({'feed_id':feed_id})
	return urllib.urlopen(url,params).read()

def statistics(id_no):
	'''
	
	If you only want a user's classifiers, use /classifiers/:id.
        Omit the feed_id to get all classifiers for all subscriptions.
        
        '''

	url = 'http://www.newsblur.com/rss_feeds/statistics/%d' % id_no
	return urllib.urlopen(url).read()

def feed_autocomplete(term):
	'''
	
	Get a list of feeds that contain a search phrase.
        Searches by feed address, feed url, and feed title, in that order.
        Will only show sites with 2+ subscribers.
        
        '''
	url = 'http://www.newsblur.com/rss_feeds/feed_autocomplete'
	params = urllib.urlencode({'term':term})
	return urllib.urlopen(url,params).read()

def read(page=1):
	'''
	
	Retrieve stories from a single feed.
	
	'''
	url = 'http://www.newsblur.com/reader/feed/%d' % page
	return urllib.urlopen(url).read()

def starred_stories(page=1):
	'''
	
	Retrieve a user's starred stories.
	
	'''
	url = 'http://www.newsblur.com/reader/starred_stories'
	params = urllib.urlencode({'page':page})
	return urllib.urlopen(url,params).read()

def river_stories(feeds,page=1,read_stories_count=0):
	'''
	
	Retrieve stories from a collection of feeds. This is known as the River of News.
        Stories are ordered in reverse chronological order.
        
        '''

	url = 'http://www.newsblur.com/reader/river_stories'
	params = urllib.urlencode({'feeds':feeds,'page':page,'read_stories_count':read_stories_count})
	return urllib.urlopen(url,params).read()

def mark_story_as_read(story_id,feed_id):
	'''
	
	 Mark stories as read.
        Multiple story ids can be sent at once.
        Each story must be from the same feed.
        
        '''

	url = 'http://www.newsblur.com/reader/mark_story_as_read'
	params = urllib.urlencode({'story_id':story_id,'feed_id':feed_id})
	return urllib.urlopen(url,params).read()

def mark_story_as_starred(story_id,feed_id):
	'''
	
	Mark a story as starred (saved).
	
	'''
	url = 'http://www.newsblur.com/reader/mark_story_as_starred'
	params = urllib.urlencode({'story_id':story_id,'feed_id':feed_id})
	return urllib.urlopen(url,params).read()

def mark_all_as_read(days=0):
	'''
	
	Mark all stories in a feed or list of feeds as read.
	
	'''
	url = 'http://www.newsblur.com/reader/mark_all_as_read'
	params = urllib.urlencode({'days':days})
	return urllib.urlopen(url,params).read()

def add_url(url,folder='[Top Level]'):
	'''
	
	Add a feed by its URL. 
	Can be either the RSS feed or the website itself.
	
	'''
	url = 'http://www.newsblur.com/reader/add_url'
	params = urllib.urlencode({'url':url,'folder':folder})
	return urllib.urlopen(url,params).read()


def add_folder(folder,parent_folder='[Top Level]'):
	'''
	
	Add a new folder.
	
	'''
	
	url = 'http://www.newsblur.com/reader/add_folder'
	params = urllib.urlencode({'folder':folder,'parent_folder':parent_folder})
	return urllib.urlopen(url,params).read()

def rename_feed(feed_title,feed_id):
	'''
	
	Rename a feed title. Only the current user will see the new title.
	
	'''
	url = 'http://www.newsblur.com/reader/rename_feed'
	params = urllib.urlencode({'feed_title':feed_title,'feed_id':feed_id})
	return urllib.urlopen(url,params).read()

def delete_feed(feed_id,in_folder):
	'''
	
	Unsubscribe from a feed. Removes it from the folder.
        Set the in_folder parameter to remove a feed from the correct folder, in case the user is subscribed to the feed in multiple folders.

        '''	
	url = 'http://www.newsblur.com/reader/delete_feed'
	params = urllib.urlencode({'feed_id':feed_id,'in_folder':in_folder})
	return urllib.urlopen(url,params).read()

def rename_folder(folder_to_rename,new_folder_name,in_folder):
	'''
	
	Rename a folder.
	
	'''
	url = 'http://www.newsblur.com/reader/rename_folder'
	params = urllib.urlencode({'folder_to_rename':folder_to_rename,'new_folder_name':new_folder_name,'in_folder':in_folder})
	return urllib.urlopen(url,params).read()

def delete_folder(folder_to_delete,in_folder,feed_id):
	'''
	
	Delete a folder and unsubscribe from all feeds inside.
	
	'''
	url = 'http://www.newsblur.com/reader/delete_folder'
	params = urllib.urlencode({'folder_to_delete':folder_to_delete,'in_folder':in_folder,'feed_id':feed_id})
	return urllib.urlopen(url,params).read()


def mark_feed_as_read(feed_id):
	'''
	
	Mark a list of feeds as read.
	
	'''
	url = 'http://www.newsblur.com/reader/mark_feed_as_read'
	params = urllib.urlencode({'feed_id':feed_id})
	return urllib.urlopen(url,params).read()


def save_feed_order(folders):
	'''
	
	Reorder feeds and move them around between folders.
        The entire folder structure needs to be serialized.
        
        '''

	url = 'http://www.newsblur.com/reader/save_feed_order'
	params = urllib.urlencode({'folders':folders})
	return urllib.urlopen(url,params).read()


def classifier(id_no):
	'''
	
        Get the intelligence classifiers for a user's site.
        Only includes the user's own classifiers. 
        Use /reader/feeds_trainer for popular classifiers.
        
        '''

	url = 'http://www.newsblur.com/classifier/%d' % id_no
	return urllib.urlopen(url).read()


def classifier_save(like_type,dislike_type,remove_like_type,remove_dislike_type):
	'''
	
	Save intelligence classifiers (tags, titles, authors, and the feed) for a feed.
	
        '''
	url = 'http://www.newsblur.com/classifier/save'
	params = urllib.urlencode({'like_[TYPE]':like_type,
				   'dislike_[TYPE]':dislike_type,
		 		   'remove_like_[TYPE]':remove_like_type,
				   'remove_dislike_[TYPE]':remove_dislike_type})
	return urllib.urlopen(url,params).read()


def opml_export():
	'''
	
	Download a backup of feeds and folders as an OPML file.
        Contains folders and feeds in XML; useful for importing in another RSS reader.
        
        '''
	url = 'http://www.newsblur.com/import/opml_export'
	return urllib.urlopen(url).read()



def opml_upload(opml_file):
	'''
	
	Upload an OPML file.
	
	'''
	url = 'http://www.newsblur.com/import/opml_upload'
	f = open(opml_file)
	params = urllib.urlencode({'file':opml_file})
	f.close()
	return urllib.urlopen(url,params).read()
	

