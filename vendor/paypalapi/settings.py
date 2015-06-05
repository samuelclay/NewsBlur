# coding=utf-8
"""
This module contains config objects needed by paypal.interface.PayPalInterface.
Most of this is transparent to the end developer, as the PayPalConfig object
is instantiated by the PayPalInterface object.
"""

import logging
import os
from pprint import pformat

from vendor.paypalapi.compat import basestring
from vendor.paypalapi.exceptions import PayPalConfigError

logger = logging.getLogger('paypal.settings')


class PayPalConfig(object):
    """
    The PayPalConfig object is used to allow the developer to perform API
    queries with any number of different accounts or configurations. This
    is done by instantiating paypal.interface.PayPalInterface, passing config
    directives as keyword args.
    """
    # Used to validate correct values for certain config directives.
    _valid_ = {
        'API_ENVIRONMENT': ['SANDBOX', 'PRODUCTION'],
        'API_AUTHENTICATION_MODE': ['3TOKEN', 'CERTIFICATE'],
    }

    # Various API servers.
    _API_ENDPOINTS = {
        # In most cases, you want 3-Token. There's also Certificate-based
        # authentication, which uses different servers.
        '3TOKEN': {
            'SANDBOX': 'https://api-3t.sandbox.paypal.com/nvp',
            'PRODUCTION': 'https://api-3t.paypal.com/nvp',
        },
        'CERTIFICATE': {
            'SANDBOX': 'https://api.sandbox.paypal.com/nvp',
            'PRODUCTION': 'https://api.paypal.com/nvp',
        },
    }

    _PAYPAL_URL_BASE = {
        'SANDBOX': 'https://www.sandbox.paypal.com/cgi-bin/webscr',
        'PRODUCTION': 'https://www.paypal.com/cgi-bin/webscr',
    }

    API_VERSION = '98.0'

    # Defaults. Used in the absence of user-specified values.
    API_ENVIRONMENT = 'SANDBOX'
    API_AUTHENTICATION_MODE = '3TOKEN'

    # 3TOKEN credentials
    API_USERNAME = None
    API_PASSWORD = None
    API_SIGNATURE = None

    # CERTIFICATE credentials
    API_CERTIFICATE_FILENAME = None
    API_KEY_FILENAME = None

    # API Endpoints are just API server addresses.
    API_ENDPOINT = None
    PAYPAL_URL_BASE = None

    # API Endpoint CA certificate chain. If this is True, do a simple SSL
    # certificate check on the endpoint. If it's a full path, verify against
    # a private cert.
    # e.g. '/etc/ssl/certs/Verisign_Class_3_Public_Primary_Certification_Authority.pem'
    API_CA_CERTS = True

    # UNIPAY credentials
    UNIPAY_SUBJECT = None

    ACK_SUCCESS = "SUCCESS"
    ACK_SUCCESS_WITH_WARNING = "SUCCESSWITHWARNING"

    # In seconds. Depending on your setup, this may need to be higher.
    HTTP_TIMEOUT = 15.0

    def __init__(self, **kwargs):
        """
        PayPalConfig constructor. **kwargs catches all of the user-specified
        config directives at time of instantiation. It is fine to set these
        values post-instantiation, too.

        Some basic validation for a few values is performed below, and defaults
        are applied for certain directives in the absence of
        user-provided values.
        """
        if kwargs.get('API_ENVIRONMENT'):
            api_environment = kwargs['API_ENVIRONMENT'].upper()
            # Make sure the environment is one of the acceptable values.
            if api_environment not in self._valid_['API_ENVIRONMENT']:
                raise PayPalConfigError('Invalid API_ENVIRONMENT')
            else:
                self.API_ENVIRONMENT = api_environment

        if kwargs.get('API_AUTHENTICATION_MODE'):
            auth_mode = kwargs['API_AUTHENTICATION_MODE'].upper()
            # Make sure the auth mode is one of the known/implemented methods.
            if auth_mode not in self._valid_['API_AUTHENTICATION_MODE']:
                choices = ", ".join(self._valid_['API_AUTHENTICATION_MODE'])
                raise PayPalConfigError(
                    "Not a supported auth mode. Use one of: %s" % choices
                )
            else:
                self.API_AUTHENTICATION_MODE = auth_mode

        # Set the API endpoints, which is a cheesy way of saying API servers.
        self.API_ENDPOINT = self._API_ENDPOINTS[self.API_AUTHENTICATION_MODE][self.API_ENVIRONMENT]
        self.PAYPAL_URL_BASE = self._PAYPAL_URL_BASE[self.API_ENVIRONMENT]

        # Set the CA_CERTS location. This can either be a None, a bool, or a
        # string path.
        if 'API_CA_CERTS' in kwargs:
            self.API_CA_CERTS = kwargs['API_CA_CERTS']

            if isinstance(self.API_CA_CERTS, basestring) and not os.path.exists(self.API_CA_CERTS):
                # A CA Cert path was specified, but it's invalid.
                raise PayPalConfigError('Invalid API_CA_CERTS')

        # check authentication fields
        if self.API_AUTHENTICATION_MODE in ('3TOKEN', 'CERTIFICATE'):
            auth_args = ['API_USERNAME', 'API_PASSWORD']
            if self.API_AUTHENTICATION_MODE == '3TOKEN':
                auth_args.append('API_SIGNATURE')
            elif self.API_AUTHENTICATION_MODE == 'CERTIFICATE':
                auth_args.extend(['API_CERTIFICATE_FILENAME', 'API_KEY_FILENAME'])

            for arg in auth_args:
                if arg not in kwargs:
                    raise PayPalConfigError('Missing in PayPalConfig: %s ' % arg)
                setattr(self, arg, kwargs[arg])

        for arg in ['HTTP_TIMEOUT']:
            if arg in kwargs:
                setattr(self, arg, kwargs[arg])

        logger.debug(
            'PayPalConfig object instantiated with kwargs: %s' % pformat(kwargs)
        )
