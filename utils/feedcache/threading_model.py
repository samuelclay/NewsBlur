# Import system modules
import Queue
import sys
import shelve
import threading

# Import local modules
import cache
from cachestoragelock import CacheStorageLock
from django.core.cache import cache as dj_cache

MAX_THREADS=1
OUTPUT_DIR = '.temp'


def fetch_feeds(force_update, feeds=None):

    if not feeds:
        print 'Specify the URLs to a few RSS or Atom feeds on the command line.'
        return

    # Decide how many threads to start
    num_threads = min(len(feeds), MAX_THREADS)

    # Add the URLs to a queue
    url_queue = Queue.Queue()
    for f in feeds:
        url_queue.put(f)

    # Add poison pills to the url queue to cause
    # the worker threads to break out of their loops
    for i in range(num_threads):
        url_queue.put(None)

    # Track the entries in the feeds being fetched
    entry_queue = Queue.Queue()

    storage = dj_cache

    # Start a few worker threads
    worker_threads = []
    for i in range(num_threads):
        t = threading.Thread(target=fetch_urls, 
                             args=(storage, url_queue, entry_queue,))
        worker_threads.append(t)
        t.setDaemon(True)
        t.start()

    # Start a thread to print the results
    printer_thread = threading.Thread(target=print_entries, args=(force_update, entry_queue,))
    printer_thread.setDaemon(True)
    printer_thread.start()

    # Wait for all of the URLs to be processed
    url_queue.join()

    # Wait for the worker threads to finish
    for t in worker_threads:
        t.join()

    # Poison the print thread and wait for it to exit
    entry_queue.put((None,None,))
    entry_queue.join()
    printer_thread.join() 
        
    # finally:
        # storage.close()
    return


def fetch_urls(storage, input_queue, output_queue):
    """Thread target for fetching feed data.
    """
    c = cache.Cache(storage)

    while True:
        feed = input_queue.get()
        if feed is None: # None causes thread to exit
            print "--- Thread completed"
            input_queue.task_done()
            break

        feed_data = c.fetch(feed.feed_address)
        output_queue.put( (feed, feed_data) )

        input_queue.task_done()
    return


def print_entries(force_update, input_queue):
    """Thread target for printing the contents of the feeds.
    """
    while True:
        feed, feed_data = input_queue.get()
        if feed_data is None: # None causes thread to exist
            input_queue.task_done()
            break

        print 'Fetched: %s' % (feed.feed_title)
        feed.update(force_update, feed_data)
        input_queue.task_done()
    return