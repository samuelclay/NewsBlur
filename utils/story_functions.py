import re
import datetime
import struct
import dateutil
from HTMLParser import HTMLParser
from lxml.html.diff import tokenize, fixup_ins_del_tags, htmldiff_tokens
from lxml.etree import ParserError, XMLSyntaxError
import lxml.html, lxml.etree
from lxml.html.clean import Cleaner
from itertools import chain
from django.utils.dateformat import DateFormat
from django.utils.html import strip_tags as strip_tags_django
from utils.tornado_escape import linkify as linkify_tornado
from utils.tornado_escape import xhtml_unescape as xhtml_unescape_tornado
from vendor import reseekfile
from utils import feedparser

# COMMENTS_RE = re.compile('\<![ \r\n\t]*(--([^\-]|[\r\n]|-[^\-])*--[ \r\n\t]*)\>')
COMMENTS_RE = re.compile('\<!--.*?--\>')

def midnight_today(now=None):
    if not now:
        now = datetime.datetime.now()
    return now.replace(hour=0, minute=0, second=0, microsecond=0, tzinfo=None)
    
def midnight_yesterday(midnight=None):
    if not midnight:
        midnight = midnight_today()
    return midnight - datetime.timedelta(days=1)
    
def beginning_of_this_month():
    return datetime.datetime.now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    
def format_story_link_date__short(date, now=None):
    if not now:
        now = datetime.datetime.now()
    date = date.replace(tzinfo=None)
    midnight = midnight_today(now)
    if date >= midnight:
        return date.strftime('%I:%M%p').lstrip('0').lower()
    elif date >= midnight_yesterday(midnight):
        return 'Yesterday, ' + date.strftime('%I:%M%p').lstrip('0').lower()
    else:
        return date.strftime('%d %b %Y, ') + date.strftime('%I:%M%p').lstrip('0').lower()

def format_story_link_date__long(date, now=None):
    if not now:
        now = datetime.datetime.now()
    date = date.replace(tzinfo=None)
    midnight = midnight_today(now)
    parsed_date = DateFormat(date)

    if date >= midnight:
        return 'Today, ' + parsed_date.format('F jS ') + date.strftime('%I:%M%p').lstrip('0').lower()
    elif date >= midnight_yesterday(midnight):
        return 'Yesterday, ' + parsed_date.format('F jS g:ia').replace('.','')
    elif date >= beginning_of_this_month():
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
    
def pre_process_story(entry, encoding):
    publish_date = entry.get('published_parsed') or entry.get('updated_parsed')
    if publish_date:
        publish_date = datetime.datetime(*publish_date[:6])
    if not publish_date and entry.get('published'):
        try:
            publish_date = dateutil.parser.parse(entry.get('published')).replace(tzinfo=None)
        except (ValueError, TypeError, OverflowError):
            pass
    
    if publish_date:
        entry['published'] = publish_date
    else:
        entry['published'] = datetime.datetime.utcnow()
    
    if entry['published'] < datetime.datetime(2000, 1, 1):
        entry['published'] = datetime.datetime.utcnow()
    
    if entry['published'] > datetime.datetime.now() + datetime.timedelta(days=1):
        entry['published'] = datetime.datetime.now()
    
    # entry_link = entry.get('link') or ''
    # protocol_index = entry_link.find("://")
    # if protocol_index != -1:
    #     entry['link'] = (entry_link[:protocol_index+3]
    #                     + urlquote(entry_link[protocol_index+3:]))
    # else:
    #     entry['link'] = urlquote(entry_link)
    if isinstance(entry.get('guid'), dict):
        entry['guid'] = unicode(entry['guid'])

    # Normalize story content/summary
    summary = entry.get('summary') or ""
    content = ""
    if not summary and 'summary_detail' in entry:
        summary = entry['summary_detail'].get('value', '')
    if entry.get('content'):
        content = entry['content'][0].get('value', '')
    if len(content) > len(summary):
        entry['story_content'] = content.strip()
    else:
        entry['story_content'] = summary.strip()
    
    if 'summary_detail' in entry and entry['summary_detail'].get('type', None) == 'text/plain':
        try:
            entry['story_content'] = feedparser._sanitizeHTML(entry['story_content'], encoding, 'text/plain')
            if encoding and not isinstance(entry['story_content'], unicode):
                entry['story_content'] = entry['story_content'].decode(encoding, 'ignore')
        except UnicodeEncodeError:
            pass
        
    # Add each media enclosure as a Download link
    for media_content in chain(entry.get('media_content', [])[:15], entry.get('links', [])[:15]):
        media_url = media_content.get('url', '')
        media_type = media_content.get('type', media_content.get('medium', ''))
        if media_url and media_type and entry['story_content'] and media_url not in entry['story_content']:
            media_type_name = media_type.split('/')[0]
            if 'audio' in media_type and media_url:
                entry['story_content'] += """<br><br>
                    <audio controls="controls" preload="none">
                        <source src="%(media_url)s" type="%(media_type)s" />
                    </audio>"""  % {
                        'media_url': media_url, 
                        'media_type': media_type
                    }
            elif 'image' in media_type and media_url:
                entry['story_content'] += """<br><br><img src="%s" />"""  % media_url
                continue
            elif media_content.get('rel', '') == 'alternative' or 'text' in media_content.get('type', ''):
                continue
            elif media_type_name in ['application']:
                continue
            entry['story_content'] += """<br><br>
                Download %(media_type)s: <a href="%(media_url)s">%(media_url)s</a>"""  % {
                'media_type': media_type_name,
                'media_url': media_url, 
            }
    
    entry['guid'] = entry.get('guid') or entry.get('id') or entry.get('link') or str(entry.get('published'))

    if not entry.get('title') and entry.get('story_content'):
        story_title = strip_tags(entry['story_content'])
        if len(story_title) > 80:
            story_title = story_title[:80] + '...'
        entry['title'] = story_title
    if not entry.get('title') and entry.get('link'):
        entry['title'] = entry['link']
        
    entry['title'] = strip_tags(entry.get('title'))
    entry['author'] = strip_tags(entry.get('author'))
    
    entry['story_content'] = attach_media_scripts(entry['story_content'])
    
    return entry

def attach_media_scripts(content):
    if 'instagram-media' in content and '<script' not in content:
        content += '<script async defer src="https://platform.instagram.com/en_US/embeds.js"></script><script>(function(){if(window.instgrm)window.instgrm.Embeds.process()})()</script>'
    if 'twitter-tweet' in content and '<script' not in content:
        content += '<script id="twitter-wjs" type="text/javascript" async defer src="https://platform.twitter.com/widgets.js"></script>'
    if 'imgur-embed-pub' in content and '<script' not in content:
        content += '<script async src="https://s.imgur.com/min/embed.js" charset="utf-8"></script>'
    return content
        
    
class MLStripper(HTMLParser):
    def __init__(self):
        self.reset()
        self.fed = []
    def handle_data(self, d):
        self.fed.append(d)
    def get_data(self):
        return ' '.join(self.fed)

def strip_tags(html):
    if not html:
        return ''
    return strip_tags_django(html)
    
    s = MLStripper()
    s.feed(html)
    return s.get_data()

def strip_comments(html_string):
    return COMMENTS_RE.sub('', html_string)

def strip_comments__lxml2(html_string=""):
    if not html_string: return html_string
    tree = lxml.html.fromstring(html_string)
    comments = tree.xpath('//comment()')

    for c in comments:
        p = c.getparent()
        p.remove(c)

    return lxml.etree.tostring(tree)
        
def strip_comments__lxml(html_string=""):
    if not html_string: return html_string
    
    params = {
        'comments': True,
        'scripts': False,
        'javascript': False,
        'style': False,
        'links': False,
        'meta': False,
        'page_structure': False,
        'processing_instructions': False,
        'embedded': False,
        'frames': False,
        'forms': False,
        'annoying_tags': False,
        'remove_tags': None,
        'allow_tags': None,
        'remove_unknown_tags': True,
        'safe_attrs_only': False,
    }
    try:
        cleaner = Cleaner(**params)
        html = lxml.html.fromstring(html_string)
        clean_html = cleaner.clean_html(html)

        return lxml.etree.tostring(clean_html)
    except (XMLSyntaxError, ParserError):
        return html_string

def prep_for_search(html):
    html = strip_tags_django(html)
    html = html.lower()
    html = xhtml_unescape_tornado(html)
    
    return html[:100000]
    
def linkify(*args, **kwargs):
    return xhtml_unescape_tornado(linkify_tornado(*args, **kwargs))
    
def truncate_chars(value, max_length):
    if len(value) <= max_length:
        return value
 
    truncd_val = value[:max_length]
    if value[max_length] != " ":
        rightmost_space = truncd_val.rfind(" ")
        if rightmost_space != -1:
            truncd_val = truncd_val[:rightmost_space]
 
    return truncd_val + "..."

def image_size(datastream):
    datastream = reseekfile.ReseekFile(datastream)
    data = str(datastream.read(30))
    size = len(data)
    height = -1
    width = -1
    content_type = ''

    # handle GIFs
    if (size >= 10) and data[:6] in ('GIF87a', 'GIF89a'):
        # Check to see if content_type is correct
        content_type = 'image/gif'
        w, h = struct.unpack("<HH", data[6:10])
        width = int(w)
        height = int(h)

    # See PNG 2. Edition spec (http://www.w3.org/TR/PNG/)
    # Bytes 0-7 are below, 4-byte chunk length, then 'IHDR'
    # and finally the 4-byte width, height
    elif ((size >= 24) and data.startswith('\211PNG\r\n\032\n')
          and (data[12:16] == 'IHDR')):
        content_type = 'image/png'
        w, h = struct.unpack(">LL", data[16:24])
        width = int(w)
        height = int(h)

    # Maybe this is for an older PNG version.
    elif (size >= 16) and data.startswith('\211PNG\r\n\032\n'):
        # Check to see if we have the right content type
        content_type = 'image/png'
        w, h = struct.unpack(">LL", data[8:16])
        width = int(w)
        height = int(h)

    # handle JPEGs
    elif (size >= 2) and data.startswith('\377\330'):
        content_type = 'image/jpeg'
        datastream.seek(0)
        datastream.read(2)
        b = datastream.read(1)
        try:
            w = 0
            h = 0
            while (b and ord(b) != 0xDA):
                while (ord(b) != 0xFF): b = datastream.read(1)
                while (ord(b) == 0xFF): b = datastream.read(1)
                if (ord(b) >= 0xC0 and ord(b) <= 0xC3):
                    datastream.read(3)
                    h, w = struct.unpack(">HH", datastream.read(4))
                    break
                else:
                    datastream.read(int(struct.unpack(">H", datastream.read(2))[0])-2)
                b = datastream.read(1)
            width = int(w)
            height = int(h)
        except struct.error:
            pass
        except ValueError:
            pass

    return content_type, width, height

def htmldiff(old_html, new_html):
    try:
        old_html_tokens = tokenize(old_html, include_hrefs=False) 
        new_html_tokens = tokenize(new_html, include_hrefs=False) 
    except (KeyError, ParserError):
        return new_html
    
    result = htmldiff_tokens(old_html_tokens, new_html_tokens) 
    result = ''.join(result).strip() 
    
    return fixup_ins_del_tags(result)
