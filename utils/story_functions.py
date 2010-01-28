from django.utils.dateformat import DateFormat
import datetime
from utils.dateutil.parser import parse as dateutil_parse
from django.utils.http import urlquote

def format_story_link_date__short(date):
    parsed_date, date_tuple, today_tuple, yesterday_tuple = _extract_date_tuples(date)
    if date_tuple == today_tuple:
        return parsed_date.format('g:ia').replace('.','')
    elif date_tuple == yesterday_tuple:
        return 'Yesterday, ' + parsed_date.format('g:ia').replace('.','')
    else:
        return parsed_date.format('d M Y, g:ia').replace('.','')

def format_story_link_date__long(date):
    parsed_date, date_tuple, today_tuple, yesterday_tuple = _extract_date_tuples(date)
    if date_tuple == today_tuple:
        return parsed_date.format('\T\o\d\\a\y, F jS, Y g:ia').replace('.','')
    elif date_tuple[0] == today_tuple[0]:
        return parsed_date.format('l, F jS g:ia').replace('.','')
    else:
        return parsed_date.format('l, F jS, Y g:ia').replace('.','')

def _extract_date_tuples(date):
    parsed_date = DateFormat(date)
    date_tuple = datetime.datetime.timetuple(date)[:3]
    today_tuple = datetime.datetime.timetuple(datetime.datetime.now())[:3]
    today = datetime.datetime.today()
    yesterday_tuple = datetime.datetime.timetuple(today - datetime.timedelta(1))[:3]
    
    return parsed_date, date_tuple, today_tuple, yesterday_tuple
    
def pre_process_story(entry):
    date_published = entry.get('published', entry.get('updated'))
    if not date_published:
        date_published = str(datetime.datetime.now())
        entry['published_now'] = True
    if not isinstance(date_published, datetime.datetime):
        date_published = dateutil_parse(date_published)
    # Change the date to UTC and remove timezone info since 
    # MySQL doesn't support it.
    timezone_diff = datetime.datetime.utcnow() - datetime.datetime.now()
    date_published_offset = date_published.utcoffset()
    if date_published_offset:
        date_published = (date_published - date_published_offset
                          - timezone_diff).replace(tzinfo=None)
    else:
        date_published = date_published.replace(tzinfo=None)

    entry['published'] = date_published
    
    entry_link = entry.get('link', '')
    protocol_index = entry_link.find("://")
    if protocol_index != -1:
        entry['link'] = (entry_link[:protocol_index+3]
                        + urlquote(entry_link[protocol_index+3:]))
    else:
        entry['link'] = urlquote(entry_link)
    return entry