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

"""Tests with shove filesystem storage.

"""

__module_id__ = "$Id: test_shovefilesystem.py 1153 2007-11-25 16:06:36Z dhellmann $"

#
# Import system modules
#
import os
import shove
import tempfile
import threading
import unittest

#
# Import local modules
#
from cache import Cache
from test_server import HTTPTestBase

#
# Module
#

class CacheShoveTest(HTTPTestBase):

    def setUp(self):
        HTTPTestBase.setUp(self)
        self.shove_dirname = tempfile.mkdtemp('shove')
        return

    def tearDown(self):
        try:
            os.system('rm -rf %s' % self.storage_dirname)
        except AttributeError:
            pass
        HTTPTestBase.tearDown(self)
        return

    def test(self):
        # First fetch the data through the cache
        storage = shove.Shove('file://' + self.shove_dirname)
        try:
            fc = Cache(storage)
            parsed_data = fc.fetch(self.TEST_URL)
            self.failUnlessEqual(parsed_data.feed.title, 'CacheTest test data')
        finally:
            storage.close()

        # Now retrieve the same data directly from the shelf
        storage = shove.Shove('file://' + self.shove_dirname)
        try:
            modified, shelved_data = storage[self.TEST_URL]
        finally:
            storage.close()
            
        # The data should be the same
        self.failUnlessEqual(parsed_data, shelved_data)
        return


if __name__ == '__main__':
    unittest.main()
