import datetime
import time
import sys
from django.utils.translation import ungettext, ugettext
from utils import feedfinder

def encode(tstr):
    """ Encodes a unicode string in utf-8
    """
    if not tstr:
        return ''
    # this is _not_ pretty, but it works
    try:
        return tstr.encode('utf-8', "xmlcharrefreplace")
    except UnicodeDecodeError:
        # it's already UTF8.. sigh
        return tstr.decode('utf-8').encode('utf-8')

def prints(tstr):
    """ lovely unicode
    """
    sys.stdout.write('%s\n' % (tstr.encode(sys.getdefaultencoding(),
                         'replace')))
    sys.stdout.flush()

def mtime(ttime):
    """ datetime auxiliar function.
    """
    return datetime.datetime.fromtimestamp(time.mktime(ttime))

# From: http://www.poromenos.org/node/87
def levenshtein_distance(first, second):
    """Find the Levenshtein distance between two strings."""
    if len(first) > len(second):
        first, second = second, first
    if len(second) == 0:
        return len(first)
    first_length = len(first) + 1
    second_length = len(second) + 1
    distance_matrix = [[0] * second_length for x in range(first_length)]
    for i in range(first_length):
       distance_matrix[i][0] = i
    for j in range(second_length):
       distance_matrix[0][j]=j
    for i in xrange(1, first_length):
        for j in range(1, second_length):
            deletion = distance_matrix[i-1][j] + 1
            insertion = distance_matrix[i][j-1] + 1
            substitution = distance_matrix[i-1][j-1]
            if first[i-1] != second[j-1]:
                substitution += 1
            distance_matrix[i][j] = min(insertion, deletion, substitution)
    return distance_matrix[first_length-1][second_length-1]
    
    
def fetch_address_from_page(url, existing_feed=None):
    from apps.rss_feeds.models import Feed
    feed_finder_url = feedfinder.feed(url)
    if feed_finder_url:
        if existing_feed:
            existing_feed.feed_address = feed_finder_url
            existing_feed.save()
            feed = existing_feed
        else:
            try:
                feed = Feed.objects.get(feed_address=feed_finder_url)
            except Feed.DoesNotExist:
                feed = Feed(feed_address=feed_finder_url)
                feed.save()
                feed.update()
        return feed
        
def _do_timesince(d, chunks, now=None):
    """
    Started as a copy of django.util.timesince.timesince, but modified to
    only output one time unit, and use months as the maximum unit of measure.
    
    Takes two datetime objects and returns the time between d and now
    as a nicely formatted string, e.g. "10 minutes".  If d occurs after now,
    then "0 minutes" is returned.

    Units used are months, weeks, days, hours, and minutes.
    Seconds and microseconds are ignored.
    """
    # Convert datetime.date to datetime.datetime for comparison
    if d.__class__ is not datetime.datetime:
        d = datetime.datetime(d.year, d.month, d.day)

    if not now:
        now = datetime.datetime.now()

    # ignore microsecond part of 'd' since we removed it from 'now'
    delta = now - (d - datetime.timedelta(0, 0, d.microsecond))
    since = delta.days * 24 * 60 * 60 + delta.seconds
    for i, (seconds, name) in enumerate(chunks):
        count = since // seconds
        if count != 0:
            break
    s = '%(number)d %(type)s' % {'number': count, 'type': name(count)}
    return s

def relative_timesince(value):
    if not value:
        return u''

    chunks = (
      (60 * 60, lambda n: ungettext('hour', 'hours', n)),
      (60, lambda n: ungettext('minute', 'minutes', n))
    )
    return _do_timesince(value, chunks)
    
def relative_timeuntil(value):
    if not value:
        return u''

    chunks = (
      (60 * 60, lambda n: ungettext('hour', 'hours', n)),
      (60, lambda n: ungettext('minute', 'minutes', n))
    )
    
    now = datetime.datetime.now()
    
    return _do_timesince(now, chunks, value)
        
def format_relative_date(date, future=False):
    if not date or date < datetime.datetime(2010, 1, 1):
        return "Soon"
        
    now = datetime.datetime.now()
    diff = abs(now - date)
    if diff < datetime.timedelta(minutes=60):
        minutes = diff.seconds / 60
        return "%s minute%s %s" % (minutes, 
                                   '' if minutes == 1 else 's', 
                                   '' if future else 'ago')
    elif datetime.timedelta(minutes=60) <= diff < datetime.timedelta(minutes=90):
        return "1 hour %s" % ('' if future else 'ago')
    elif diff >= datetime.timedelta(minutes=90):
        dec = (diff.seconds / 60 + 15) % 60
        if dec >= 30:
            return "%s.5 hours %s" % ((((diff.seconds / 60) + 15) / 60),
                                      '' if future else 'ago')
        else:
            return "%s hours %s" % ((((diff.seconds / 60) + 15) / 60), 
                                    '' if future else 'ago')