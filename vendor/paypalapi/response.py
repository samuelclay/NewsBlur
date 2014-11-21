# coding=utf-8
"""
PayPalResponse parsing and processing.
"""

import logging
from pprint import pformat

from vendor.paypalapi.compat import is_py3

if is_py3:
    #noinspection PyUnresolvedReferences
    from urllib.parse import parse_qs
else:
    # Python 2.6 and up (but not 3.0) have urlparse.parse_qs, which is copied
    # from Python 2.5's cgi.parse_qs.
    from urlparse import parse_qs

logger = logging.getLogger('paypal.response')


class PayPalResponse(object):
    """
    Parse and prepare the reponse from PayPal's API. Acts as somewhat of a
    glorified dictionary for API responses.

    NOTE: Don't access self.raw directly. Just do something like
    PayPalResponse.someattr, going through PayPalResponse.__getattr__().
    """
    def __init__(self, query_string, config):
        """
        query_string is the response from the API, in NVP format. This is
        parseable by urlparse.parse_qs(), which sticks it into the
        :attr:`raw` dict for retrieval by the user.

        :param str query_string: The raw response from the API server.
        :param PayPalConfig config: The config object that was used to send
            the query that caused this response.
        """
        # A dict of NVP values. Don't access this directly, use
        # PayPalResponse.attribname instead. See self.__getattr__().
        self.raw = parse_qs(query_string)
        self.config = config
        logger.debug("PayPal NVP API Response:\n%s" % self.__str__())

    def __str__(self):
        """
        Returns a string representation of the PayPalResponse object, in
        'pretty-print' format.

        :rtype: str
        :returns: A 'pretty' string representation of the response dict.
        """
        return pformat(self.raw)

    def __getattr__(self, key):
        """
        Handles the retrieval of attributes that don't exist on the object
        already. This is used to get API response values. Handles some
        convenience stuff like discarding case and checking the cgi/urlparsed
        response value dict (self.raw).

        :param str key: The response attribute to get a value for.
        :rtype: str
        :returns: The requested value from the API server's response.
        """
        # PayPal response names are always uppercase.
        key = key.upper()
        try:
            value = self.raw[key]
            if len(value) == 1:
                # For some reason, PayPal returns lists for all of the values.
                # I'm not positive as to why, so we'll just take the first
                # of each one. Hasn't failed us so far.
                return value[0]
            return value
        except KeyError:
            # The requested value wasn't returned in the response.
            raise AttributeError(self)

    def __getitem__(self, key):
        """
        Another (dict-style) means of accessing response data.

        :param str key: The response key to get a value for.
        :rtype: str
        :returns: The requested value from the API server's response.
        """
        # PayPal response names are always uppercase.
        key = key.upper()
        value = self.raw[key]
        if len(value) == 1:
            # For some reason, PayPal returns lists for all of the values.
            # I'm not positive as to why, so we'll just take the first
            # of each one. Hasn't failed us so far.
            return value[0]
        return value
        
    def items(self):
        items_list = []
        for key in self.raw.keys():
            items_list.append((key, self.__getitem__(key)))
        return items_list
        
    def iteritems(self):
        for key in self.raw.keys():
            yield (key, self.__getitem__(key))

    def success(self):
        """
        Checks for the presence of errors in the response. Returns ``True`` if
        all is well, ``False`` otherwise.

        :rtype: bool
        :returns ``True`` if PayPal says our query was successful.
        """
        return self.ack.upper() in (self.config.ACK_SUCCESS,
                                    self.config.ACK_SUCCESS_WITH_WARNING)
    success = property(success)
