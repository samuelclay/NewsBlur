from django.utils.dateformat import DateFormat
import datetime
from django.utils.http import urlquote

def format_story_link_date__short(date, now=None):
    if not now: now = datetime.datetime.now()
    diff = date.date() - now.date()
    if diff.days == 0:
        return date.strftime('%I:%M%p').lstrip('0').lower()
    elif diff.days == 1:
        return 'Yesterday, ' + date.strftime('%I:%M%p').lstrip('0').lower()
    else:
        return date.strftime('%d %b %Y, ') + date.strftime('%I:%M%p').lstrip('0').lower()

def format_story_link_date__long(date, now=None):
    if not now: now = datetime.datetime.utcnow()
    diff = now.date() - date.date()
    parsed_date = DateFormat(date)
    if diff.days == 0:
        return 'Today, ' + parsed_date.format('F jS ') + date.strftime('%I:%M%p').lstrip('0').lower()
    elif diff.days == 1:
        return 'Yesterday, ' + parsed_date.format('F jS g:ia').replace('.','')
    elif date.date().timetuple()[7] == now.date().timetuple()[7]:
        return parsed_date.format('l, F jS g:ia').replace('.','')
    else:
        return parsed_date.format('l, F jS, Y g:ia').replace('.','')

def _extract_date_tuples(date):
    parsed_date = DateFormat(date)
    date_tuple = datetime.datetime.timetuple(date)[:3]
    today_tuple = datetime.datetime.timetuple(datetime.datetime.utcnow())[:3]
    today = datetime.datetime.today()
    yesterday_tuple = datetime.datetime.timetuple(today - datetime.timedelta(1))[:3]
    
    return parsed_date, date_tuple, today_tuple, yesterday_tuple
    
def pre_process_story(entry):
    publish_date = entry.get('published_parsed', entry.get('updated_parsed'))
    entry['published'] = datetime.datetime(*publish_date[:6]) if publish_date else datetime.datetime.utcnow()
    
    entry_link = entry.get('link', '')
    protocol_index = entry_link.find("://")
    if protocol_index != -1:
        entry['link'] = (entry_link[:protocol_index+3]
                        + urlquote(entry_link[protocol_index+3:]))
    else:
        entry['link'] = urlquote(entry_link)
    if isinstance(entry.get('guid'), dict):
        entry['guid'] = unicode(entry['guid'])
    return entry
    
class bunch(dict):
    """Example of overloading __getatr__ and __setattr__
    This example creates a dictionary where members can be accessed as attributes
    """
    def __init__(self, indict=None, attribute=None):
        if indict is None:
            indict = {}
        # set any attributes here - before initialisation
        # these remain as normal attributes
        self.attribute = attribute
        dict.__init__(self, indict)
        self.__initialised = True
        # after initialisation, setting attributes is the same as setting an item

    def __getattr__(self, item):
        """Maps values to attributes.
        Only called if there *isn't* an attribute with this name
        """
        try:
            return self.__getitem__(item)
        except KeyError:
            return None

    def __setattr__(self, item, value):
        """Maps attributes to values.
        Only if we are initialised
        """
        if not self.__dict__.has_key('_bunch__initialised'):  # this test allows attributes to be set in the __init__ method
            return dict.__setattr__(self, item, value)
        elif self.__dict__.has_key(item):       # any normal attributes are handled normally
            dict.__setattr__(self, item, value)
        else:
            self.__setitem__(item, value)