# coding=utf-8
"""
Various PayPal API related exceptions.
"""


class PayPalError(Exception):
    """
    Used to denote some kind of generic error. This does not include errors
    returned from PayPal API responses. Those are handled by the more
    specific exception classes below.
    """
    def __init__(self, message, error_code=None):
        Exception.__init__(self, message, error_code)
        self.message = message
        self.error_code = error_code

    def __str__(self):
        if self.error_code:
            return "%s (Error Code: %s)" % (repr(self.message), self.error_code)
        else:
            return repr(self.message)


class PayPalConfigError(PayPalError):
    """
    Raised when a configuration problem arises.
    """
    pass


class PayPalAPIResponseError(PayPalError):
    """
    Raised when there is an error coming back with a PayPal NVP API response.

    Pipe the error message from the API to the exception, along with
    the error code.
    """
    def __init__(self, response):
        self.response = response
        self.error_code = int(getattr(response, 'L_ERRORCODE0', -1))
        self.message = getattr(response, 'L_LONGMESSAGE0', None)
        self.short_message = getattr(response, 'L_SHORTMESSAGE0', None)
        self.correlation_id = getattr(response, 'CORRELATIONID', None)

        super(PayPalAPIResponseError, self).__init__(self.message, self.error_code)
