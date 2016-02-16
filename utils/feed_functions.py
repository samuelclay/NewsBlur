import datetime
import threading
import sys
import traceback
import pprint
import urllib
import urlparse
import random
import warnings
from django.core.mail import mail_admins
from django.utils.translation import ungettext
from django.utils.encoding import smart_unicode
from utils import log as logging


class TimeoutError(Exception): pass
def timelimit(timeout):
    """borrowed from web.py"""
    def _1(function):
        def _2(*args, **kw):
            class Dispatch(threading.Thread):
                def __init__(self):
                    threading.Thread.__init__(self)
                    self.result = None
                    self.error = None
                    
                    self.setDaemon(True)
                    self.start()

                def run(self):
                    try:
                        self.result = function(*args, **kw)
                    except:
                        self.error = sys.exc_info()
            c = Dispatch()
            c.join(timeout)
            if c.isAlive():
                raise TimeoutError, 'took too long'
            if c.error:
                tb = ''.join(traceback.format_exception(c.error[0], c.error[1], c.error[2]))
                logging.debug(tb)
                mail_admins('Error in timeout: %s' % c.error[0], tb)
                raise c.error[0], c.error[1], c.error[2]
            return c.result
        return _2
    return _1

         
def utf8encode(tstr):
    """ Encodes a unicode string in utf-8
    """
    msg = "utf8encode is deprecated. Use django.utils.encoding.smart_unicode instead."
    warnings.warn(msg, DeprecationWarning)
    return smart_unicode(tstr)

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
        now = datetime.datetime.utcnow()

    # ignore microsecond part of 'd' since we removed it from 'now'
    delta = now - (d - datetime.timedelta(0, 0, d.microsecond))
    since = delta.days * 24 * 60 * 60 + delta.seconds
    if since > 10:
        for i, (seconds, name) in enumerate(chunks):
            count = since // seconds
            if count != 0:
                break
        s = '%(number)d %(type)s' % {'number': count, 'type': name(count)}
    else:
        s = 'just a second'
    return s

def relative_timesince(value):
    if not value:
        return u''

    chunks = (
      (60 * 60 * 24, lambda n: ungettext('day', 'days', n)),
      (60 * 60, lambda n: ungettext('hour', 'hours', n)),
      (60, lambda n: ungettext('minute', 'minutes', n)),
      (1, lambda n: ungettext('second', 'seconds', n)),
      (0, lambda n: 'just now'),
    )
    return _do_timesince(value, chunks)
    
def relative_timeuntil(value):
    if not value:
        return u''

    chunks = (
      (60 * 60, lambda n: ungettext('hour', 'hours', n)),
      (60, lambda n: ungettext('minute', 'minutes', n))
    )
    
    now = datetime.datetime.utcnow()
    
    return _do_timesince(now, chunks, value)

def seconds_timesince(value):
    if not value:
        return 0
    now = datetime.datetime.utcnow()
    delta = now - value
    
    return delta.days * 24 * 60 * 60 + delta.seconds
    
def format_relative_date(date, future=False):
    if not date or date < datetime.datetime(2010, 1, 1):
        return "Soon"
        
    now = datetime.datetime.utcnow()
    diff = abs(now - date)
    if diff < datetime.timedelta(minutes=60):
        minutes = diff.seconds / 60
        return "%s minute%s %s" % (minutes, 
                                   '' if minutes == 1 else 's', 
                                   '' if future else 'ago')
    elif datetime.timedelta(minutes=60) <= diff < datetime.timedelta(minutes=90):
        return "1 hour %s" % ('' if future else 'ago')
    elif diff < datetime.timedelta(hours=24):
        dec = (diff.seconds / 60 + 15) % 60
        if dec >= 30:
            return "%s.5 hours %s" % ((((diff.seconds / 60) + 15) / 60),
                                      '' if future else 'ago')
        else:
            return "%s hours %s" % ((((diff.seconds / 60) + 15) / 60), 
                                    '' if future else 'ago')
    else:
        days = ((diff.seconds / 60) / 60 / 24)
        return "%s day%s %s" % (days, '' if days == 1 else 's', '' if future else 'ago')
    
def add_object_to_folder(obj, in_folder, folders, parent='', added=False):
    obj_identifier = obj
    if isinstance(obj, dict):
        obj_identifier = obj.keys()[0]

    if ((not in_folder or in_folder == " ") and
        not parent and 
        not isinstance(obj, dict) and 
        obj_identifier not in folders):
        folders.append(obj)
        return folders

    child_folder_names = []
    for item in folders:
        if isinstance(item, dict):
            child_folder_names.append(item.keys()[0])
    if isinstance(obj, dict) and in_folder == parent:
        if obj_identifier not in child_folder_names:
            folders.append(obj)
        return folders
        
    for k, v in enumerate(folders):
        if isinstance(v, dict):
            for f_k, f_v in v.items():
                if f_k == in_folder and obj_identifier not in f_v and not added:
                    f_v.append(obj)
                    added = True
                folders[k][f_k] = add_object_to_folder(obj, in_folder, f_v, f_k, added)
    
    return folders  

def mail_feed_error_to_admin(feed, e, local_vars=None, subject=None):
    # Mail the admins with the error
    if not subject:
        subject = "Feed update error"
    exc_info = sys.exc_info()
    subject = '%s: %s' % (subject, repr(e))
    message = 'Traceback:\n%s\n\Feed:\n%s\nLocals:\n%s' % (
        '\n'.join(traceback.format_exception(*exc_info)),
        pprint.pformat(feed.__dict__),
        pprint.pformat(local_vars)
        )
    # print message
    mail_admins(subject, message)
    
## {{{ http://code.activestate.com/recipes/576611/ (r11)
from operator import itemgetter
from heapq import nlargest
from itertools import repeat, ifilter

class Counter(dict):
    '''Dict subclass for counting hashable objects.  Sometimes called a bag
    or multiset.  Elements are stored as dictionary keys and their counts
    are stored as dictionary values.

    >>> Counter('zyzygy')
    Counter({'y': 3, 'z': 2, 'g': 1})

    '''

    def __init__(self, iterable=None, **kwds):
        '''Create a new, empty Counter object.  And if given, count elements
        from an input iterable.  Or, initialize the count from another mapping
        of elements to their counts.

        >>> c = Counter()                           # a new, empty counter
        >>> c = Counter('gallahad')                 # a new counter from an iterable
        >>> c = Counter({'a': 4, 'b': 2})           # a new counter from a mapping
        >>> c = Counter(a=4, b=2)                   # a new counter from keyword args

        '''        
        self.update(iterable, **kwds)

    def __missing__(self, key):
        return 0

    def most_common(self, n=None):
        '''List the n most common elements and their counts from the most
        common to the least.  If n is None, then list all element counts.

        >>> Counter('abracadabra').most_common(3)
        [('a', 5), ('r', 2), ('b', 2)]

        '''        
        if n is None:
            return sorted(self.iteritems(), key=itemgetter(1), reverse=True)
        return nlargest(n, self.iteritems(), key=itemgetter(1))

    def elements(self):
        '''Iterator over elements repeating each as many times as its count.

        >>> c = Counter('ABCABC')
        >>> sorted(c.elements())
        ['A', 'A', 'B', 'B', 'C', 'C']

        If an element's count has been set to zero or is a negative number,
        elements() will ignore it.

        '''
        for elem, count in self.iteritems():
            for _ in repeat(None, count):
                yield elem

    # Override dict methods where the meaning changes for Counter objects.

    @classmethod
    def fromkeys(cls, iterable, v=None):
        raise NotImplementedError(
            'Counter.fromkeys() is undefined.  Use Counter(iterable) instead.')

    def update(self, iterable=None, **kwds):
        '''Like dict.update() but add counts instead of replacing them.

        Source can be an iterable, a dictionary, or another Counter instance.

        >>> c = Counter('which')
        >>> c.update('witch')           # add elements from another iterable
        >>> d = Counter('watch')
        >>> c.update(d)                 # add elements from another counter
        >>> c['h']                      # four 'h' in which, witch, and watch
        4

        '''        
        if iterable is not None:
            if hasattr(iterable, 'iteritems'):
                if self:
                    self_get = self.get
                    for elem, count in iterable.iteritems():
                        self[elem] = self_get(elem, 0) + count
                else:
                    dict.update(self, iterable) # fast path when counter is empty
            else:
                self_get = self.get
                for elem in iterable:
                    self[elem] = self_get(elem, 0) + 1
        if kwds:
            self.update(kwds)

    def copy(self):
        'Like dict.copy() but returns a Counter instance instead of a dict.'
        return Counter(self)

    def __delitem__(self, elem):
        'Like dict.__delitem__() but does not raise KeyError for missing values.'
        if elem in self:
            dict.__delitem__(self, elem)

    def __repr__(self):
        if not self:
            return '%s()' % self.__class__.__name__
        items = ', '.join(map('%r: %r'.__mod__, self.most_common()))
        return '%s({%s})' % (self.__class__.__name__, items)

    # Multiset-style mathematical operations discussed in:
    #       Knuth TAOCP Volume II section 4.6.3 exercise 19
    #       and at http://en.wikipedia.org/wiki/Multiset
    #
    # Outputs guaranteed to only include positive counts.
    #
    # To strip negative and zero counts, add-in an empty counter:
    #       c += Counter()

    def __add__(self, other):
        '''Add counts from two counters.

        >>> Counter('abbb') + Counter('bcc')
        Counter({'b': 4, 'c': 2, 'a': 1})


        '''
        if not isinstance(other, Counter):
            return NotImplemented
        result = Counter()
        for elem in set(self) | set(other):
            newcount = self[elem] + other[elem]
            if newcount > 0:
                result[elem] = newcount
        return result

    def __sub__(self, other):
        ''' Subtract count, but keep only results with positive counts.

        >>> Counter('abbbc') - Counter('bccd')
        Counter({'b': 2, 'a': 1})

        '''
        if not isinstance(other, Counter):
            return NotImplemented
        result = Counter()
        for elem in set(self) | set(other):
            newcount = self[elem] - other[elem]
            if newcount > 0:
                result[elem] = newcount
        return result

    def __or__(self, other):
        '''Union is the maximum of value in either of the input counters.

        >>> Counter('abbb') | Counter('bcc')
        Counter({'b': 3, 'c': 2, 'a': 1})

        '''
        if not isinstance(other, Counter):
            return NotImplemented
        _max = max
        result = Counter()
        for elem in set(self) | set(other):
            newcount = _max(self[elem], other[elem])
            if newcount > 0:
                result[elem] = newcount
        return result

    def __and__(self, other):
        ''' Intersection is the minimum of corresponding counts.

        >>> Counter('abbb') & Counter('bcc')
        Counter({'b': 1})

        '''
        if not isinstance(other, Counter):
            return NotImplemented
        _min = min
        result = Counter()
        if len(self) < len(other):
            self, other = other, self
        for elem in ifilter(self.__contains__, other):
            newcount = _min(self[elem], other[elem])
            if newcount > 0:
                result[elem] = newcount
        return result


if __name__ == '__main__':
    import doctest
    print doctest.testmod()
## end of http://code.activestate.com/recipes/576611/ }}}

def chunks(l, n):
    for i in xrange(0, len(l), n):
        yield l[i:i+n]
