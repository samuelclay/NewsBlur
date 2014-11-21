# coding=utf-8
"""
PayPal response parsing of list syntax.
"""

import logging
import re

from response import PayPalResponse
from exceptions import PayPalAPIResponseError

logger = logging.getLogger('paypal.response')

class PayPalResponseList(PayPalResponse):
    """
    Subclass of PayPalResponse, parses L_style list items and
    stores them in a dictionary keyed by numeric index.

    NOTE: Don't access self.raw directly. Just do something like
    PayPalResponse.someattr, going through PayPalResponse.__getattr__().
    """
    def __init__(self, raw, config):
        self.raw = raw
        self.config = config

        L_regex = re.compile("L_([a-zA-Z]+)([0-9]{0,2})")
        # name-value pair list syntax documented at
        #  https://developer.paypal.com/docs/classic/api/NVPAPIOverview/#id084E30EC030
        # api returns max 100 items, so only two digits required

        self.list_items_dict = {}

        for key in self.raw.keys():
            match = L_regex.match(key)
            if match:
                index = match.group(2)
                d_key = match.group(1)

                if type(self.raw[key]) == type(list()) and len(self.raw[key]) == 1:
                    d_val = self.raw[key][0]
                else:
                    d_val = self.raw[key]
            
                #skip error codes
                if d_key in ['ERRORCODE','SHORTMESSAGE','LONGMESSAGE','SEVERITYCODE']:
                    continue

                if index in self.list_items_dict:
                    #dict for index exists, update
                    self.list_items_dict[index][d_key] = d_val
                else:
                    #create new dict 
                    self.list_items_dict[index] = {d_key: d_val}

        #log ResponseErrors from warning keys
        if self.raw['ACK'][0].upper() == self.config.ACK_SUCCESS_WITH_WARNING:
            self.errors = [PayPalAPIResponseError(self)]
            logger.error(self.errors)

    def items(self):
        #convert dict like {'1':{},'2':{}, ...} to list
        return list(self.list_items_dict.values())
        
    def iteritems(self):
         for key in self.list_items_dict.keys():
            yield (key, self.list_items_dict[key])
