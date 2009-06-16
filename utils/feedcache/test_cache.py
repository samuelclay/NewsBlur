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

"""Unittests for feedcache.cache

"""

__module_id__ = "$Id: test_cache.py 1153 2007-11-25 16:06:36Z dhellmann $"

import logging
logging.basicConfig(level=logging.DEBUG,
                    format='%(asctime)s %(levelname)-8s %(name)s %(message)s',
                    )
logger = logging.getLogger('feedcache.test_cache')

#
# Import system modules
#
import copy
import email.utils
import os
import time
import unittest
import UserDict

#
# Import local modules
#
import cache
from test_server import HTTPTestBase, TestHTTPServer

#
# Module
#

class CacheTestBase(HTTPTestBase):

    def setUp(self):
        HTTPTestBase.setUp(self)

        self.storage = self.getStorage()
        self.cache = cache.Cache(self.storage,
                                 timeToLiveSeconds=self.CACHE_TTL,
                                 userAgent='feedcache.test',
                                 )
        return

    def getStorage(self):
        "Return a cache storage for the test."
        return {}

class CacheTest(CacheTestBase):

    CACHE_TTL = 30

    def getServer(self):
        "These tests do not want to use the ETag or If-Modified-Since headers"
        return TestHTTPServer(applyModifiedHeaders=False)

    def testRetrieveNotInCache(self):
        # Retrieve data not already in the cache.
        feed_data = self.cache.fetch(self.TEST_URL)
        self.failUnless(feed_data)
        self.failUnlessEqual(feed_data.feed.title, 'CacheTest test data')
        return

    def testRetrieveIsInCache(self):
        # Retrieve data which is alread in the cache,
        # and verify that the second copy is identitical
        # to the first.

        # First fetch
        feed_data = self.cache.fetch(self.TEST_URL)

        # Second fetch
        feed_data2 = self.cache.fetch(self.TEST_URL)

        # Since it is the in-memory storage, we should have the
        # exact same object.
        self.failUnless(feed_data is feed_data2)
        return

    def testExpireDataInCache(self):
        # Retrieve data which is in the cache but which
        # has expired and verify that the second copy
        # is different from the first.

        # First fetch
        feed_data = self.cache.fetch(self.TEST_URL)

        # Change the timeout and sleep to move the clock
        self.cache.time_to_live = 0
        time.sleep(1)

        # Second fetch
        feed_data2 = self.cache.fetch(self.TEST_URL)

        # Since we reparsed, the cache response should be different.
        self.failIf(feed_data is feed_data2)
        return

    def testForceUpdate(self):
        # Force cache to retrieve data which is alread in the cache,
        # and verify that the new data is different.

        # Pre-populate the storage with bad data
        self.cache.storage[self.TEST_URL] = (time.time() + 100, self.id())

        # Fetch the data
        feed_data = self.cache.fetch(self.TEST_URL, force_update=True)

        self.failIfEqual(feed_data, self.id())
        return

    def testOfflineMode(self):
        # Retrieve data which is alread in the cache,
        # whether it is expired or not.

        # Pre-populate the storage with data
        self.cache.storage[self.TEST_URL] = (0, self.id())

        # Fetch it
        feed_data = self.cache.fetch(self.TEST_URL, offline=True)

        self.failUnlessEqual(feed_data, self.id())
        return

    def testUnicodeURL(self):
        # Pass in a URL which is unicode

        url = unicode(self.TEST_URL)
        feed_data = self.cache.fetch(url)

        storage = self.cache.storage
        key = unicode(self.TEST_URL).encode('UTF-8')

        # Verify that the storage has a key
        self.failUnless(storage.has_key(key))

        # Now pull the data from the storage directly
        storage_timeout, storage_data = self.cache.storage.get(key)
        self.failUnlessEqual(feed_data, storage_data)
        return



class SingleWriteMemoryStorage(UserDict.UserDict):
    """Cache storage which only allows the cache value 
    for a URL to be updated one time.
    """

    def __setitem__(self, url, data):
        if url in self.keys():
            modified, existing = self[url]
            # Allow the modified time to change, 
            # but not the feed content.
            if data[1] != existing:
                raise AssertionError('Trying to update cache for %s to %s' \
                                         % (url, data))
        UserDict.UserDict.__setitem__(self, url, data)
        return
    

class CacheConditionalGETTest(CacheTestBase):

    def getStorage(self):
        return SingleWriteMemoryStorage()

    def testFetchOnceForEtag(self):
        # Fetch data which has a valid ETag value, and verify
        # that while we hit the server twice the response
        # codes cause us to use the same data.

        # First fetch populates the cache
        response1 = self.cache.fetch(self.TEST_URL)
        self.failUnlessEqual(response1.feed.title, 'CacheTest test data')

        # Remove the modified setting from the cache so we know
        # the next time we check the etag will be used
        # to check for updates.  Since we are using an in-memory
        # cache, modifying response1 updates the cache storage
        # directly.
        response1['modified'] = None

        # Wait so the cache data times out
        time.sleep(1)

        # This should result in a 304 status, and no data from
        # the server.  That means the cache won't try to
        # update the storage, so our SingleWriteMemoryStorage
        # should not raise and we should have the same
        # response object.
        response2 = self.cache.fetch(self.TEST_URL)
        self.failUnless(response1 is response2)

        # Should have hit the server twice
        self.failUnlessEqual(self.server.getNumRequests(), 2)
        return

    def testFetchOnceForModifiedTime(self):
        # Fetch data which has a valid Last-Modified value, and verify
        # that while we hit the server twice the response
        # codes cause us to use the same data.

        # First fetch populates the cache
        response1 = self.cache.fetch(self.TEST_URL)
        self.failUnlessEqual(response1.feed.title, 'CacheTest test data')

        # Remove the etag setting from the cache so we know
        # the next time we check the modified time will be used
        # to check for updates.  Since we are using an in-memory
        # cache, modifying response1 updates the cache storage
        # directly.
        response1['etag'] = None

        # Wait so the cache data times out
        time.sleep(1)

        # This should result in a 304 status, and no data from
        # the server.  That means the cache won't try to
        # update the storage, so our SingleWriteMemoryStorage
        # should not raise and we should have the same
        # response object.
        response2 = self.cache.fetch(self.TEST_URL)
        self.failUnless(response1 is response2)

        # Should have hit the server twice
        self.failUnlessEqual(self.server.getNumRequests(), 2)
        return


class CacheRedirectHandlingTest(CacheTestBase):
    
    def _test(self, response):
        # Set up the server to redirect requests,
        # then verify that the cache is not updated
        # for the original or new URL and that the
        # redirect status is fed back to us with
        # the fetched data.

        self.server.setResponse(response, '/redirected')

        response1 = self.cache.fetch(self.TEST_URL)

        # The response should include the status code we set
        self.failUnlessEqual(response1.get('status'), response)

        # The response should include the new URL, too
        self.failUnlessEqual(response1.href, self.TEST_URL + 'redirected')

        # The response should not have been cached under either URL
        self.failIf(self.storage.has_key(self.TEST_URL))
        self.failIf(self.storage.has_key(self.TEST_URL + 'redirected'))
        return

    def test301(self):
        self._test(301)
        return                    

    def test302(self):
        self._test(302)
        return                    

    def test303(self):
        self._test(303)
        return                    

    def test307(self):
        self._test(307)
        return                    

class CachePurgeTest(CacheTestBase):

    def testPurgeAll(self):
        # Remove everything from the cache

        response1 = self.cache.fetch(self.TEST_URL)
        self.failUnless(self.storage.keys(), 'Have no data in the cache storage')

        self.cache.purge(None)

        self.failIf(self.storage.keys(), 'Still have data in the cache storage')
        return

    def testPurgeByAge(self):
        # Remove old content from the cache

        response1 = self.cache.fetch(self.TEST_URL)
        self.failUnless(self.storage.keys(), 'Have no data in the cache storage')

        time.sleep(1)

        remains = (time.time(), copy.deepcopy(self.storage[self.TEST_URL][1]))
        self.storage['http://this.should.remain/'] = remains

        self.cache.purge(1)

        self.failUnlessEqual(self.storage.keys(), ['http://this.should.remain/'])
        return


if __name__ == '__main__':
    unittest.main()
