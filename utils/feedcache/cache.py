#!/usr/bin/env python
#
# Copyright 2007 Doug Hellmann.
#
#
#                         All Rights Reserved
#
# Permission to use, copy, modify, and distribute this software and
# its documentation for any purpose and without fee is hereby
# granted, provided that the above copyright notice appear in all
# copies and that both that copyright notice and this permission
# notice appear in supporting documentation, and that the name of Doug
# Hellmann not be used in advertising or publicity pertaining to
# distribution of the software without specific, written prior
# permission.
#
# DOUG HELLMANN DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
# INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN
# NO EVENT SHALL DOUG HELLMANN BE LIABLE FOR ANY SPECIAL, INDIRECT OR
# CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
# OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
# NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
# CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

"""

"""

__module_id__ = "$Id: cache.py 1153 2007-11-25 16:06:36Z dhellmann $"

#
# Import system modules
#
from utils import feedparser

import time
import datetime

#
# Import local modules
#


#
# Module
#

class Cache:
    """A class to wrap Mark Pilgrim's Universal Feed Parser module
    (http://www.feedparser.org) so that parameters can be used to
    cache the feed results locally instead of fetching the feed every
    time it is requested. Uses both etag and modified times for
    caching.
    """

    def __init__(self, storage, timeToLiveSeconds=300, userAgent='feedcache'):
        """
        Arguments:

          storage -- Backing store for the cache.  It should follow
          the dictionary API, with URLs used as keys.  It should
          persist data.

          timeToLiveSeconds=300 -- The length of time content should
          live in the cache before an update is attempted.

          userAgent='feedcache' -- User agent string to be used when
          fetching feed contents.

        """
        self.storage = storage
        self.time_to_live = timeToLiveSeconds
        self.user_agent = userAgent
        return

    def purge(self, olderThanSeconds):
        """Remove cached data from the storage if the data is older than the
        date given.  If olderThanSeconds is None, the entire cache is purged.
        """
        if olderThanSeconds is None:
            print 'purging the entire cache'
            for key in self.storage.keys():
                del self.storage[key]
        else:
            now = time.time()
            # Iterate over the keys and load each item one at a time
            # to avoid having the entire cache loaded into memory
            # at one time.
            for url in self.storage.keys():
                (cached_time, cached_data) = self.storage[url]
                age = now - cached_time
                if age >= olderThanSeconds:
                    print 'removing %s with age %d' % (url, age)
                    del self.storage[url]
        return

    def fetch(self, url, force_update = False, offline = False, decay_time=600):
        """Return the feed at url.
        
        url - The URL of the feed.

        force_update=False - When True, update the cache whether the
                                           current contents have
                                           exceeded their time-to-live
                                           or not.

        offline=False - When True, only return data from the local
                                 cache and never access the remote
                                 URL.

        If there is data for that feed in the cache already, check
        the expiration date before accessing the server.  If the
        cached data has not expired, return it without accessing the
        server.

        In cases where the server is accessed, check for updates
        before deciding what to return.  If the server reports a
        status of 304, the previously cached content is returned.  

        The cache is only updated if the server returns a status of
        200, to avoid holding redirected data in the cache.
        """
        print 'url="%s"' % url

        # Convert the URL to a value we can use
        # as a key for the storage backend.
        key = 'feed:' + url
        if isinstance( key, unicode):
            key = key.encode('utf-8')

        modified = None
        etag = None
        now = datetime.datetime.now()

        cached_time, cached_content = self.storage.get(key, (None, None))
        # Offline mode support (no networked requests)
        # so return whatever we found in the storage.
        # If there is nothing in the storage, we'll be returning None.
        if offline:
            # print 'offline mode'
            return cached_content

        # Does the storage contain a version of the data
        # which is older than the time-to-live?
        print 'cache modified time: %s' % str(cached_time)
        if cached_time is not None and not force_update:
            if self.time_to_live:
                age = now - cached_time
                ttl = datetime.timedelta(seconds=self.time_to_live)
                print 'Cached time: %s, Age: %s, TTL: %s' % (cached_time, age, ttl)
                if age <= ttl:
                    print 'cache contents still valid'
                    return cached_content
                else:
                    print 'cache contents older than TTL'
            else:
                print 'no TTL value'
            
            # The cache is out of date, but we have
            # something.  Try to use the etag and modified_time
            # values from the cached content.
            etag = cached_content.get('etag')
            modified = cached_content.get('modified')
            # print 'cached etag=%s' % etag
            # print 'cached modified=%s' % str(modified)
        else:
            print 'nothing in the cache, or forcing update'

        # We know we need to fetch, so go ahead and do it.
        print 'fetching...'
        parsed_result = feedparser.parse(url,
                                         agent=self.user_agent,
                                         modified=modified,
                                         etag=etag,
                                         )

        status = parsed_result.get('status', None)
        # print 'status=%s' % status
        if status == 304 or status == 302:
            # No new data, based on the etag or modified values.
            # We need to update the modified time in the
            # storage, though, so we know that what we have
            # stored is up to date.
            print 'Updating 304/2 stored data for %s' % (url)
            self.storage.set(key, (now, parsed_result), decay_time)

            # Return the data from the cache, since
            # the parsed data will be empty.
            parsed_result = cached_content
        elif status == 200:
            # There is new content, so store it unless there was an error.
            error = parsed_result.get('bozo_exception')
            print 'Updating stored data for %s' % url
            self.storage.set(key, (now, parsed_result), decay_time)

        return parsed_result

