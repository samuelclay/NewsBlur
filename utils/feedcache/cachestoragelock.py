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
from __future__ import with_statement

"""Lock wrapper for cache storage which do not permit multi-threaded access.

"""

__module_id__ = "$Id: cachestoragelock.py 1153 2007-11-25 16:06:36Z dhellmann $"

#
# Import system modules
#
import threading

#
# Import local modules
#


#
# Module
#

class CacheStorageLock:
    """Lock wrapper for cache storage which do not permit multi-threaded access.
    """

    def __init__(self, shelf):
        self.lock = threading.Lock()
        self.shelf = shelf
        return

    def __getitem__(self, key):
        with self.lock:
            return self.shelf[key]

    def get(self, key, default=None):
        with self.lock:
            try:
                return self.shelf[key]
            except KeyError:
                return default

    def __setitem__(self, key, value):
        with self.lock:
            self.shelf[key] = value
