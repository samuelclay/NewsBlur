"""
Various utility functions.
"""
from django.conf import settings
from boto.ses import SESConnection

def get_boto_ses_connection():
    """
    Shortcut for instantiating and returning a boto SESConnection object.
    
    :rtype: boto.ses.SESConnection
    :returns: A boto SESConnection object, from which email sending is done.
    """
    access_key_id = getattr(settings, 'AWS_ACCESS_KEY_ID', None)
    access_key = getattr(settings, 'AWS_SECRET_ACCESS_KEY', None)
    api_endpoint = getattr(settings, 'AWS_SES_API_HOST',
                           SESConnection.DefaultHost)

    return SESConnection(
        aws_access_key_id=access_key_id,
        aws_secret_access_key=access_key,
        host=api_endpoint,
    )
