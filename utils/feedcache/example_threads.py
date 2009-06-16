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

"""Example use of feedcache.Cache combined with threads.

"""

__module_id__ = "$Id: example_threads.py 1153 2007-11-25 16:06:36Z dhellmann $"

#
# Import system modules
#
import Queue
import sys
import shelve
import threading

#
# Import local modules
#
import cache

#
# Module
#

MAX_THREADS=5
OUTPUT_DIR='/tmp/feedcache_example'


def main(urls=[]):

    if not urls:
        print 'Specify the URLs to a few RSS or Atom feeds on the command line.'
        return

    # Decide how many threads to start
    num_threads = min(len(urls), MAX_THREADS)

    # Add the URLs to a queue
    url_queue = Queue.Queue()
    for url in urls:
        url_queue.put(url)

    # Add poison pills to the url queue to cause
    # the worker threads to break out of their loops
    for i in range(num_threads):
        url_queue.put(None)

    # Track the entries in the feeds being fetched
    entry_queue = Queue.Queue()

    print 'Saving feed data to', OUTPUT_DIR
    storage = shelve.Shelve('file://' + OUTPUT_DIR)
    try:

        # Start a few worker threads
        worker_threads = []
        for i in range(num_threads):
            t = threading.Thread(target=fetch_urls, 
                                 args=(storage, url_queue, entry_queue,))
            worker_threads.append(t)
            t.setDaemon(True)
            t.start()

        # Start a thread to print the results
        printer_thread = threading.Thread(target=print_entries, args=(entry_queue,))
        printer_thread.setDaemon(True)
        printer_thread.start()

        # Wait for all of the URLs to be processed
        url_queue.join()

        # Wait for the worker threads to finish
        for t in worker_threads:
            t.join()

        # Poison the print thread and wait for it to exit
        entry_queue.put((None,None))
        entry_queue.join()
        printer_thread.join()        
        
    finally:
        storage.close()
    return


def fetch_urls(storage, input_queue, output_queue):
    """Thread target for fetching feed data.
    """
    c = cache.Cache(storage)

    while True:
        next_url = input_queue.get()
        if next_url is None: # None causes thread to exit
            input_queue.task_done()
            break

        feed_data = c.fetch(next_url)
        for entry in feed_data.entries:
            output_queue.put( (feed_data.feed, entry) )
        input_queue.task_done()
    return


def print_entries(input_queue):
    """Thread target for printing the contents of the feeds.
    """
    while True:
        feed, entry = input_queue.get()
        if feed is None: # None causes thread to exist
            input_queue.task_done()
            break

        print '%s: %s' % (feed.title, entry.title)
        input_queue.task_done()
    return


if __name__ == '__main__':
    main(sys.argv[1:])

