import logging
from django.conf import settings
from utils.colorama import Fore, Back, Style
import re

def getlogger():
    root_logger = logging.getLogger('newsblur')
    if len(root_logger.handlers) >= 1:
        return root_logger
    
    logger = logging.getLogger('newsblur')
    if settings.LOG_TO_STREAM:
        hdlr = logging.StreamHandler()
    else:
        hdlr = logging.FileHandler(settings.LOG_FILE)
    formatter = logging.Formatter('[%(asctime)-12s] %(message)s','%b %d %H:%M:%S')
    
    hdlr.setFormatter(formatter)
    logger.addHandler(hdlr)
    logger.setLevel(settings.LOG_LEVEL)

    return logger

def debug(msg):
    logger = getlogger()
    logger.debug(colorize(msg))

def info(msg):
    logger = getlogger()
    logger.info(colorize(msg))

def error(msg):
    logger = getlogger()
    logger.error(colorize(msg))
    
def colorize(msg):
    params = {
        r'\-\-\->'        : '~FB~SB--->~FW',
        r'\*\*\*>'        : '~FB~SB~BB--->~BT~FW',
        r'\['             : '~SB~FB[~SN~FM',
        r'AnonymousUser'  : '~FBAnonymousUser',
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
    msg = msg % colors
    return msg