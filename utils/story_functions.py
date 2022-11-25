import re
import datetime
import struct
import dateutil
import hashlib
import base64
import html
import sys
from random import randint
from lxml.html.diff import tokenize, fixup_ins_del_tags, htmldiff_tokens
from lxml.etree import ParserError, XMLSyntaxError, SerialisationError
import lxml.html, lxml.etree
from lxml.html.clean import Cleaner
from itertools import chain
from django.utils.dateformat import DateFormat
from django.utils.html import strip_tags as strip_tags_django
from utils.tornado_escape import linkify as linkify_tornado
from utils.tornado_escape import xhtml_unescape as xhtml_unescape_tornado
import feedparser

import hmac
from binascii import hexlify
from hashlib import sha1

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

def relative_date(d):
    diff = datetime.datetime.utcnow() - d
    s = diff.seconds
    if diff.days == 1:
        return '1 day ago'
    elif diff.days > 1:
        return '{} days ago'.format(diff.days)
    elif s < 60:
        return 'just now'
    elif s < 120:
        return '1 minute ago'
    elif s < 3600:
        return '{} minutes ago'.format(s//60)
    elif s < 7200:
        return '1 hour ago'
    else:
        return '{} hours ago'.format(s//3600)

def _extract_date_tuples(date):
    parsed_date = DateFormat(date)
    date_tuple = datetime.datetime.timetuple(date)[:3]
    today_tuple = datetime.datetime.timetuple(datetime.datetime.utcnow())[:3]
    today = datetime.datetime.today()
    yesterday_tuple = datetime.datetime.timetuple(today - datetime.timedelta(1))[:3]
    
    return parsed_date, date_tuple, today_tuple, yesterday_tuple
    
def pre_process_story(entry, encoding):
    # Do not switch to published_parsed or every story will be dated the fetch time
    publish_date = entry.get('g_parsed') or entry.get('updated_parsed') 
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
        entry['published'] = datetime.datetime.utcnow() + datetime.timedelta(seconds=randint(0, 59))
    
    if entry['published'] < datetime.datetime(2000, 1, 1):
        entry['published'] = datetime.datetime.utcnow()
    
    # Future dated stories get forced to current date
    # if entry['published'] > datetime.datetime.now() + datetime.timedelta(days=1):
    if entry['published'] > datetime.datetime.now():
        entry['published'] = datetime.datetime.now() + datetime.timedelta(seconds=randint(0, 59))
    
    # entry_link = entry.get('link') or ''
    # protocol_index = entry_link.find("://")
    # if protocol_index != -1:
    #     entry['link'] = (entry_link[:protocol_index+3]
    #                     + urlquote(entry_link[protocol_index+3:]))
    # else:
    #     entry['link'] = urlquote(entry_link)
    if isinstance(entry.get('guid'), dict):
        entry['guid'] = str(entry['guid'])

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
    if not entry['story_content'] and entry.get('subtitle'):
        entry['story_content'] = entry.get('subtitle')
    
    if 'summary_detail' in entry and entry['summary_detail'].get('type', None) == 'text/plain':
        try:
            entry['story_content'] = feedparser.sanitizer._sanitize_html(entry['story_content'], encoding, 'text/plain')
            if encoding and not isinstance(entry['story_content'], str):
                entry['story_content'] = entry['story_content'].decode(encoding, 'ignore')
        except UnicodeEncodeError:
            pass
        
    # Add each media enclosure as a Download link
    for media_content in chain(entry.get('media_content', [])[:15], entry.get('links', [])[:15]):
        media_url = media_content.get('url', media_content.get('href', ''))
        media_type = media_content.get('type', media_content.get('medium', ''))
        if media_url and media_type and media_url not in entry['story_content']:
            media_type_name = media_type.split('/')[0]
            if 'audio' in media_type and media_url:
                entry['story_content'] += """<br><br>
                    <audio controls="controls" preload="none">
                        <source src="%(media_url)s" type="%(media_type)s" />
                    </audio>"""  % {
                        'media_url': media_url, 
                        'media_type': media_type
                    }
            elif 'video' in media_type and media_url:
                entry['story_content'] += """<br><br>
                    <video controls="controls" preload="none">
                        <source src="%(media_url)s" type="%(media_type)s" />
                    </video>"""  % {
                        'media_url': media_url, 
                        'media_type': media_type
                    }
            elif 'image' in media_type and media_url and media_url not in entry['story_content']:
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

    if not entry.get('title'):
        entry['title'] = ""
        
    entry['title'] = strip_tags(entry.get('title'))
    entry['author'] = strip_tags(entry.get('author'))
    if not entry['author']:
        entry['author'] = strip_tags(entry.get('credit'))

    
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

def strip_tags(html):
    if not html:
        return ''
    return strip_tags_django(html)

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

        return lxml.etree.tostring(clean_html).decode()
    except (XMLSyntaxError, ParserError, SerialisationError):
        return html_string

def prep_for_search(html):
    html = strip_tags_django(html)
    html = html.lower()
    html = xhtml_unescape_tornado(html)
    
    return html[:100000]
    
def linkify(*args, **kwargs):
    return xhtml_unescape_tornado(linkify_tornado(*args, **kwargs))
    
def truncate_chars(value, max_length):
    try:
        value = value.encode('utf-8')
    except UnicodeDecodeError:
        pass
    if len(value) <= max_length:
        return value.decode('utf-8', 'ignore')
 
    truncd_val = value[:max_length]
    if value[max_length] != b" ":
        rightmost_space = truncd_val.rfind(b" ")
        if rightmost_space != -1:
            truncd_val = truncd_val[:rightmost_space]
 
    return truncd_val.decode('utf-8', 'ignore') + "..."

def htmldiff(old_html, new_html):
    try:
        old_html_tokens = tokenize(old_html, include_hrefs=False) 
        new_html_tokens = tokenize(new_html, include_hrefs=False) 
    except (KeyError, ParserError):
        return new_html
    
    result = htmldiff_tokens(old_html_tokens, new_html_tokens) 
    result = ''.join(result).strip() 
    
    return fixup_ins_del_tags(result)


def create_camo_signed_url(base_url, hmac_key, url):
    """Create a camo signed URL for the specified image URL
    Args:
        base_url: Base URL of the camo installation
        hmac_key: HMAC shared key to be used for signing
        url: URL of the destination image
    Returns:
        str: A full url that can be used to serve the proxied image
    """

    base_url = base_url.rstrip('/')
    signature = hmac.HMAC(hmac_key, url.encode(), digestmod=sha1).hexdigest()
    hex_url = hexlify(url.encode()).decode()

    return ('{base}/{signature}/{hex_url}'
            .format(base=base_url, signature=signature, hex_url=hex_url))
            
def create_imageproxy_signed_url(base_url, hmac_key, url, options=None):
    """Create a imageproxy signed URL for the specified image URL
    Args:
        base_url: Base URL of the imageproxy installation
        hmac_key: HMAC shared key to be used for signing
        url: URL of the destination image
    Returns:
        str: A full url that can be used to serve the proxied image
    """
    if not options: options = []
    if isinstance(options, int): options = [str(options)]
    if not isinstance(options, list): options = [options]
    if sys.getdefaultencoding() == 'ascii':
        url = url.encode('utf-8')
    
    if url.startswith("data:"):
        return url

    base_url = base_url.rstrip('/')
    signature = base64.urlsafe_b64encode(hmac.new(hmac_key.encode(), msg=url.encode(), digestmod=hashlib.sha256).digest())
    options.append('sc')
    options.append('s'+signature.decode())

    return ('{base}/{options}/{url}'
            .format(base=base_url, options=','.join(options), url=url))
            