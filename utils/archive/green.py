from gevent import monkey
monkey.patch_socket()

from newsblur.utils import feedparser
import gevent
from gevent import queue
import urllib2

def fetch_title(url):
    print "Running %s" % url
    data = urllib2.urlopen(url).read()
    print "Parsing %s" % url
    d = feedparser.parse(data)
    print "Parsed %s" % d.feed.get('title', '')
    return d.feed.get('title', '')

def worker():
    while True:
        url = q.get()
        try:
            fetch_title(url)
        finally:
            q.task_done()

if __name__ == '__main__':
    q = queue.JoinableQueue()
    for i in range(5):
         gevent.spawn(worker)

    for url in "http://www.43folders.com/rss.xml/nhttp://feeds.feedburner.com/43folders/nhttp://www.43folders.com/rss.xml/nhttp://feeds.feedburner.com/43folders/nhttp://feeds.feedburner.com/AMinuteWithBrendan/nhttp://feeds.feedburner.com/AMinuteWithBrendan/nhttp://www.asianart.org/feeds/Lectures,Classes,Symposia.xml/nhttp://www.asianart.org/feeds/Performances.xml/nhttp://feeds.feedburner.com/ajaxian/nhttp://ajaxian.com/index.xml/nhttp://al3x.net/atom.xml/nhttp://feeds.feedburner.com/AmericanDrink/nhttp://feeds.feedburner.com/eod_full/nhttp://feeds.feedburner.com/typepad/notes/nhttp://feeds.dashes.com/AnilDash/nhttp://rss.sciam.com/assignment-impossible/feed/nhttp://blogs.scientificamerican.com/assignment-impossible//nhttp://feeds.feedburner.com/Beautiful-Pixels/nhttp://feeds.feedburner.com/Beautiful-Pixels/nhttp://www.betabeat.com/feed/".split('/n'):
            print "Spawning: %s" % url
            q.put(url)

    q.join()  # block until all tasks are done


