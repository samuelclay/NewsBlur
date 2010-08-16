import logging
from django.conf import settings

def getlogger():
    root_logger = logging.getLogger('newsblur')
    if len(root_logger.handlers) >= 1:
        return root_logger
    
    logger = logging.getLogger('newsblur')
    if settings.LOG_TO_STREAM:
        hdlr = logging.StreamHandler()
    else:
        hdlr = logging.FileHandler(settings.LOG_FILE)
    formatter = logging.Formatter('[%(asctime)-12s] %(message)s','%b %d %H:%M') 
    
    hdlr.setFormatter(formatter)
    logger.addHandler(hdlr)
    logger.setLevel(settings.LOG_LEVEL)

    return logger

def debug(msg):
    logger = getlogger()
    logger.debug(msg)

def info(msg):
    logger = getlogger()
    logger.info(msg)

def error(msg):
    logger = getlogger()
    logger.error(msg)