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

"""Simple HTTP server for testing the feed cache.

"""

__module_id__ = "$Id: test_server.py 1153 2007-11-25 16:06:36Z dhellmann $"

#
# Import system modules
#
import BaseHTTPServer
import email.utils
import logging
import md5
import threading
import time
import unittest
import urllib

#
# Import local modules
#


#
# Module
#
logger = logging.getLogger('feedcache.test_server')

def make_etag(data):
    """Given a string containing data to be returned to the client,
    compute an ETag value for the data.
    """
    _md5 = md5.new()
    _md5.update(data)
    return _md5.hexdigest()


class TestHTTPHandler(BaseHTTPServer.BaseHTTPRequestHandler):
    "HTTP request handler which serves the same feed data every time."

    FEED_DATA = """<?xml version="1.0" encoding="utf-8"?>

<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en-us">
  <title>CacheTest test data</title>
  <link href="http://localhost/feedcache/" rel="alternate"></link>
  <link href="http://localhost/feedcache/atom/" rel="self"></link>
  <id>http://localhost/feedcache/</id>
  <updated>2006-10-14T11:00:36Z</updated>
  <entry>
    <title>single test entry</title>
    <link href="http://www.example.com/" rel="alternate"></link>
    <updated>2006-10-14T11:00:36Z</updated>
    <author>
      <name>author goes here</name>
      <email>authoremail@example.com</email>
    </author>
    <id>http://www.example.com/</id>
    <summary type="html">description goes here</summary>
    <link length="100" href="http://www.example.com/enclosure" type="text/html" rel="enclosure">
    </link>
  </entry>
</feed>"""

    # The data does not change, so save the ETag and modified times
    # as class attributes.
    ETAG = make_etag(FEED_DATA)
    MODIFIED_TIME = email.utils.formatdate(usegmt=True)

    def do_GET(self):
        "Handle GET requests."
        logger.debug('GET %s', self.path)

        if self.path == '/shutdown':
            # Shortcut to handle stopping the server
            logger.debug('Stopping server')
            self.server.stop()
            self.send_response(200)

        else:
            logger.debug('pre-defined response code: %d', self.server.response)
            handler_method_name = 'do_GET_%d' % self.server.response
            handler_method = getattr(self, handler_method_name)
            handler_method()
        return

    def do_GET_3xx(self):
        "Handle redirects"
        if self.path.endswith('/redirected'):
            logger.debug('already redirected')
            # We have already redirected, so return the data.
            return self.do_GET_200()
        new_path = self.server.new_path
        logger.debug('redirecting to %s', new_path)
        self.send_response(self.server.response)
        self.send_header('Location', new_path)
        return

    do_GET_301 = do_GET_3xx
    do_GET_302 = do_GET_3xx
    do_GET_303 = do_GET_3xx
    do_GET_307 = do_GET_3xx

    def do_GET_200(self):
        logger.debug('Etag: %s' % self.ETAG)
        logger.debug('Last-Modified: %s' % self.MODIFIED_TIME)

        incoming_etag = self.headers.get('If-None-Match', None)
        logger.debug('Incoming ETag: "%s"' % incoming_etag)

        incoming_modified = self.headers.get('If-Modified-Since', None)
        logger.debug('Incoming If-Modified-Since: %s' % incoming_modified)

        send_data = True

        # Does the client have the same version of the data we have?
        if self.server.apply_modified_headers:
            if incoming_etag == self.ETAG:
                logger.debug('Response 304, etag')
                self.send_response(304)
                send_data = False

            elif incoming_modified == self.MODIFIED_TIME:
                logger.debug('Response 304, modified time')
                self.send_response(304)
                send_data = False

        # Now optionally send the data, if the client needs it
        if send_data:
            logger.debug('Response 200')
            self.send_response(200)

            self.send_header('Content-Type', 'application/atom+xml')

            logger.debug('Outgoing Etag: %s' % self.ETAG)
            self.send_header('ETag', self.ETAG)

            logger.debug('Outgoing modified time: %s' % self.MODIFIED_TIME)
            self.send_header('Last-Modified', self.MODIFIED_TIME)

            self.end_headers()

            logger.debug('Sending data')
            self.wfile.write(self.FEED_DATA)
        return

class TestHTTPServer(BaseHTTPServer.HTTPServer):
    """HTTP Server which counts the number of requests made
    and can stop based on client instructions.
    """

    def __init__(self, applyModifiedHeaders=True, handler=TestHTTPHandler):
        self.apply_modified_headers = applyModifiedHeaders
        self.keep_serving = True
        self.request_count = 0
        self.setResponse(200)
        BaseHTTPServer.HTTPServer.__init__(self, ('', 9999), handler)
        return
    
    def setResponse(self, newResponse, newPath=None):
        """Sets the response code to use for future requests, and a new
        path to be used as a redirect target, if necessary.
        """
        self.response = newResponse
        self.new_path = newPath
        return

    def getNumRequests(self):
        "Return the number of requests which have been made on the server."
        return self.request_count

    def stop(self):
        "Stop serving requests, after the next request."
        self.keep_serving = False
        return

    def serve_forever(self):
        "Main loop for server"
        while self.keep_serving:
            self.handle_request()
            self.request_count += 1
        logger.debug('exiting')
        return


class HTTPTestBase(unittest.TestCase):
    "Base class for tests that use a TestHTTPServer"

    TEST_URL = 'http://localhost:9999/'

    CACHE_TTL = 0

    def setUp(self):
        self.server = self.getServer()
        self.server_thread = threading.Thread(target=self.server.serve_forever)
        self.server_thread.setDaemon(True) # so the tests don't hang if cleanup fails
        self.server_thread.start()
        return

    def getServer(self):
        "Return a web server for the test."
        s = TestHTTPServer()
        s.setResponse(200)
        return s

    def tearDown(self):
        # Stop the server thread
        ignore = urllib.urlretrieve(self.TEST_URL + 'shutdown')
        time.sleep(1)
        self.server.server_close()
        self.server_thread.join()
        return
