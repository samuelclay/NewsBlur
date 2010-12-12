from django.utils.dateformat import DateFormat
import datetime
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
        return 'Today, ' + parsed_date.format('F jS g:ia').replace('.','')
    if date_tuple == yesterday_tuple:
        return 'Yesterday, ' + parsed_date.format('F jS g:ia').replace('.','')
    elif date_tuple[0] == today_tuple[0]:
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