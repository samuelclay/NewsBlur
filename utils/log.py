import logging
import re
from django.core.handlers.wsgi import WSGIRequest

class NullHandler(logging.Handler): #exists in python 3.1
    def emit(self, record):
        pass

def getlogger():
    logger = logging.getLogger('newsblur')
    return logger

def user(u, msg):
    platform = '------'
    if isinstance(u, WSGIRequest):
        request = u
        u = request.user
        user_agent = request.environ.get('HTTP_USER_AGENT', '')
        if 'iPhone App' in user_agent:
            platform = 'iPhone'
        elif 'Blar' in user_agent:
            platform = 'Blar'
        elif 'MSIE' in user_agent:
            platform = 'IE'
        elif 'Chrome' in user_agent:
            platform = 'Chrome'
        elif 'Safari' in user_agent:
            platform = 'Safari'
        elif 'MeeGo' in user_agent:
            platform = 'MeeGo'
        elif 'Firefox' in user_agent:
            platform = 'FF'
        elif 'Opera' in user_agent:
            platform = 'Opera'
    premium = '*' if u.is_authenticated() and u.profile.is_premium else ''
    info(' ---> [~FB~SN%-6s~SB] [%s%s] %s' % (platform, u, premium, msg))
    
def debug(msg):
    logger = getlogger()
    logger.debug(colorize(msg))

def info(msg):
    logger = getlogger()
    logger.info(colorize(msg))

def error(msg):
    logger = getlogger()
    logger.error(msg)
    
def colorize(msg):
    params = {
        r'\-\-\->'        : '~FB~SB--->~FW',
        r'\*\*\*>'        : '~FB~SB~BB--->~BT~FW',
        r'\['             : '~SB~FB[~SN~FM',
        r'AnonymousUser'  : '~FBAnonymousUser',
        r'\*\]'           : '~SN~FR*]',
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
    msg = re.sub(r'(~[A-Z]{2})', r'%(\1)s', msg)
    try:
        msg = msg % colors
    except (TypeError, ValueError, KeyError):
        pass
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