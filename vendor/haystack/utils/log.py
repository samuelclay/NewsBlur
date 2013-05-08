from __future__ import absolute_import

import logging

from django.conf import settings


def getLogger(name):
    real_logger = logging.getLogger(name)
    return LoggingFacade(real_logger)


class LoggingFacade(object):
    def __init__(self, real_logger):
        self.real_logger = real_logger

    def noop(self, *args, **kwargs):
        pass

    def __getattr__(self, attr):
        if getattr(settings, 'HAYSTACK_LOGGING', True):
            return getattr(self.real_logger, attr)
        return self.noop
