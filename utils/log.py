import logging
import re
import string
import time

from django.core.handlers.wsgi import WSGIRequest
from django.conf import settings
from django.utils.encoding import smart_unicode

from user_functions import extract_user_agent
from apps.statistics.rstats import RStats


class NullHandler(logging.Handler):  # exists in python 3.1
    def emit(self, record):
        pass


def getlogger():
    logger = logging.getLogger('newsblur')
    return logger


def user(u, msg, request=None, warn_color=True):
    msg = smart_unicode(msg)
    if not u:
        return debug(msg)

    platform = '------'
    time_elapsed = ""
    if isinstance(u, WSGIRequest) or request:
        if not request:
            request = u
            u = request.user
        platform = extract_user_agent(request)

        if hasattr(request, 'start_time'):
            seconds = time.time() - request.start_time
            color = '~FB'
            if warn_color:
                if seconds >= 1:
                    color = '~FR'
                elif seconds > .2:
                    color = '~SB~FK'
            time_elapsed = "[%s%.4ss~SB] " % (
                color,
                seconds,
            )
    is_premium = u.is_authenticated() and u.profile.is_premium
    premium = '*' if is_premium else ''
    username = cipher(unicode(u)) if settings.CIPHER_USERNAMES else unicode(u)
    info(' ---> [~FB~SN%-6s~SB] %s[%s%s] %s' % (platform, time_elapsed, username, premium, msg))
    page_load_paths = [
        "/reader/feed/",
        "/social/stories/",
        "/reader/river_stories/",
        "/social/river_stories/"
    ]
    if request:
        path = RStats.clean_path(request.path)
        if path in page_load_paths:
            RStats.add('page_load', duration=seconds)


def cipher(msg):
    shift = len(msg)
    in_alphabet = unicode(string.ascii_lowercase)
    out_alphabet = in_alphabet[shift:] + in_alphabet[:shift]
    translation_table = dict((ord(ic), oc) for ic, oc in zip(in_alphabet, out_alphabet))

    return msg.translate(translation_table)


def debug(msg):
    msg = smart_unicode(msg)
    logger = getlogger()
    logger.debug(colorize(msg))


def info(msg):
    msg = smart_unicode(msg)
    logger = getlogger()
    logger.info(colorize(msg))


def error(msg):
    msg = smart_unicode(msg)
    logger = getlogger()
    logger.error(msg)


def colorize(msg):
    params = {
        r'\-\-\->'        : '~FB~SB--->~FW',
        r'\*\*\*>'        : '~FB~SB~BB--->~BT~FW',
        r'\['             : '~SB~FB[~SN~FM',
        r'AnonymousUser'  : '~FBAnonymousUser',
        r'\*(\s*)~FB~SB\]'           : r'~SN~FR*\1~FB~SB]',
        r'\]'             : '~FB~SB]~FW~SN',
    }
    colors = {
        '~SB' : Style.BRIGHT,
        '~SN' : Style.NORMAL,
        '~SK' : Style.BLINK,
        '~SU' : Style.UNDERLINE,
        '~ST' : Style.RESET_ALL,
        '~FK': Fore.BLACK,
        '~FR': Fore.RED,
        '~FG': Fore.GREEN,
        '~FY': Fore.YELLOW,
        '~FB': Fore.BLUE,
        '~FM': Fore.MAGENTA,
        '~FC': Fore.CYAN,
        '~FW': Fore.WHITE,
        '~FT': Fore.RESET,
        '~BK': Back.BLACK,
        '~BR': Back.RED,
        '~BG': Back.GREEN,
        '~BY': Back.YELLOW,
        '~BB': Back.BLUE,
        '~BM': Back.MAGENTA,
        '~BC': Back.CYAN,
        '~BW': Back.WHITE,
        '~BT': Back.RESET,
    }
    for k, v in params.items():
        msg = re.sub(k, v, msg)
    msg = msg + '~ST~FW~BT'
    # msg = re.sub(r'(~[A-Z]{2})', r'%(\1)s', msg)
    for k, v in colors.items():
        msg = msg.replace(k, v)
    return msg
    
'''
This module generates ANSI character codes to printing colors to terminals.
See: http://en.wikipedia.org/wiki/ANSI_escape_code
'''

COLOR_ESC = '\033['

class AnsiCodes(object):
    def __init__(self, codes):
        for name in dir(codes):
            if not name.startswith('_'):
                value = getattr(codes, name)
                setattr(self, name, COLOR_ESC + str(value) + 'm')

class AnsiFore:
    BLACK   = 30
    RED     = 31
    GREEN   = 32
    YELLOW  = 33
    BLUE    = 34
    MAGENTA = 35
    CYAN    = 36
    WHITE   = 37
    RESET   = 39

class AnsiBack:
    BLACK   = 40
    RED     = 41
    GREEN   = 42
    YELLOW  = 43
    BLUE    = 44
    MAGENTA = 45
    CYAN    = 46
    WHITE   = 47
    RESET   = 49

class AnsiStyle:
    BRIGHT    = 1
    DIM       = 2
    UNDERLINE = 4
    BLINK     = 5
    NORMAL    = 22
    RESET_ALL = 0

Fore = AnsiCodes(AnsiFore)
Back = AnsiCodes(AnsiBack)
Style = AnsiCodes(AnsiStyle)
