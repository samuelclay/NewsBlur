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

"""Tests for shelflock.

"""

__module_id__ = "$Id: test_cachestoragelock.py 1153 2007-11-25 16:06:36Z dhellmann $"

#
# Import system modules
#
import os
import shelve
import tempfile
import threading
import unittest

#
# Import local modules
#
from cache import Cache
from cachestoragelock import CacheStorageLock
from test_server import HTTPTestBase

#
# Module
#

class CacheShelveTest(HTTPTestBase):

    def setUp(self):
        HTTPTestBase.setUp(self)
        handle, self.shelve_filename = tempfile.mkstemp('.shelve')
        os.close(handle) # we just want the file name, so close the open handle
        os.unlink(self.shelve_filename) # remove the empty file
        return

    def tearDown(self):
        try:
            os.unlink(self.shelve_filename)
        except AttributeError:
            pass
        HTTPTestBase.tearDown(self)
        return

    def test(self):
        storage = shelve.open(self.shelve_filename)
        locking_storage = CacheStorageLock(storage)
        try:
            fc = Cache(locking_storage)

            # First fetch the data through the cache
            parsed_data = fc.fetch(self.TEST_URL)
            self.failUnlessEqual(parsed_data.feed.title, 'CacheTest test data')

            # Now retrieve the same data directly from the shelf
            modified, shelved_data = storage[self.TEST_URL]
            
            # The data should be the same
            self.failUnlessEqual(parsed_data, shelved_data)
        finally:
            storage.close()
        return


if __name__ == '__main__':
    unittest.main()
