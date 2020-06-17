

import six
import requests
from django.conf import settings
from django.core.mail.backends.base import BaseEmailBackend
from django.core.mail.message import sanitize_address
from django.utils.encoding import force_text

from requests.packages.urllib3.filepost import encode_multipart_formdata

__version__ = '0.8.0'
version = __version__


# A mapping of smtp headers to API key names, along
# with a callable to transform them somehow (if nec.)
#
# https://documentation.mailgun.com/user_manual.html#sending-via-smtp
# https://documentation.mailgun.com/api-sending.html#sending
#
# structure is SMTP_HEADER: (api_name, data_transform_function)
HEADERS_MAP = {
    'X-Mailgun-Tag': ('o:tag', lambda x: x),
    'X-Mailgun-Campaign-Id': ('o:campaign', lambda x: x),
    'X-Mailgun-Dkim': ('o:dkim', lambda x: x),
    'X-Mailgun-Deliver-By': ('o:deliverytime', lambda x: x),
    'X-Mailgun-Drop-Message': ('o:testmode', lambda x: x),
    'X-Mailgun-Track': ('o:tracking', lambda x: x),
    'X-Mailgun-Track-Clicks': ('o:tracking-clicks', lambda x: x),
    'X-Mailgun-Track-Opens': ('o:tracking-opens', lambda x: x),
    'X-Mailgun-Variables': lambda v_k: (('v:%s' % v_k[0]), v_k[1]),
}


class MailgunAPIError(Exception):
    pass


class MailgunBackend(BaseEmailBackend):
    """A Django Email backend that uses mailgun.
    """

    def __init__(self, fail_silently=False, *args, **kwargs):
        access_key, server_name = (kwargs.pop('access_key', None),
                                   kwargs.pop('server_name', None))

        super(MailgunBackend, self).__init__(
            fail_silently=fail_silently,
            *args, **kwargs)

        try:
            self._access_key = access_key or getattr(settings, 'MAILGUN_ACCESS_KEY')
            self._server_name = server_name or getattr(settings, 'MAILGUN_SERVER_NAME')
        except AttributeError:
            if fail_silently:
                self._access_key, self._server_name = None
            else:
                raise

        self._api_url = "https://api.mailgun.net/v3/%s/" % self._server_name
        self._headers_map = HEADERS_MAP

    def open(self):
        """Stub for open connection, all sends are done over HTTP POSTs
        """
        pass

    def close(self):
        """Close any open HTTP connections to the API server.
        """
        pass

    def _map_smtp_headers_to_api_parameters(self, email_message):
        """
        Map the values passed in SMTP headers to API-ready
        2-item tuples present in HEADERS_MAP

        header values must be a single string or list or tuple of strings

        :return: 2-item tuples of the form (api_name, api_values)
        """
        api_data = []
        for smtp_key, api_transformer in six.iteritems(self._headers_map):
            data_to_transform = email_message.extra_headers.pop(smtp_key, None)
            if data_to_transform is not None:
                if isinstance(data_to_transform, (list, tuple)):
                    # map each value in the tuple/list
                    for data in data_to_transform:
                        api_data.append((api_transformer[0], api_transformer[1](data)))
                elif isinstance(data_to_transform, dict):
                    for data in six.iteritems(data_to_transform):
                        api_data.append(api_transformer(data))
                else:
                    # we only have one value
                    api_data.append((api_transformer[0], api_transformer[1](data_to_transform)))
        return api_data

    def _send(self, email_message):
        """A helper method that does the actual sending."""
        if not email_message.recipients():
            return False
        from_email = sanitize_address(email_message.from_email, email_message.encoding)

        to_recipients = [sanitize_address(addr, email_message.encoding)
                      for addr in email_message.to]

        try:
            post_data = []
            post_data.append(('to', (",".join(to_recipients)),))
            if email_message.bcc:
                bcc_recipients = [sanitize_address(addr, email_message.encoding) for addr in email_message.bcc]
                post_data.append(('bcc', (",".join(bcc_recipients)),))
            if email_message.cc:
                cc_recipients = [sanitize_address(addr, email_message.encoding) for addr in email_message.cc]
                post_data.append(('cc', (",".join(cc_recipients)),))
            post_data.append(('text', email_message.body,))
            post_data.append(('subject', email_message.subject,))
            post_data.append(('from', from_email,))
            # get our recipient variables if they were passed in
            recipient_variables = email_message.extra_headers.pop('recipient_variables', None)
            if recipient_variables is not None:
                post_data.append(('recipient-variables', recipient_variables, ))

            for name, value in self._map_smtp_headers_to_api_parameters(email_message):
                post_data.append((name, value, ))

            if hasattr(email_message, 'alternatives') and email_message.alternatives:
                for alt in email_message.alternatives:
                    if alt[1] == 'text/html':
                        post_data.append(('html', alt[0],))
                        break

            # Map Reply-To header if present
            try:
                if hasattr(email_message, 'reply_to'):
                    post_data.append((
                        "h:Reply-To",
                        ", ".join(map(force_text, email_message.reply_to)),
                    ))
                elif 'Reply-To' in email_message.extra_headers:
                    post_data.append((
                        "h:Reply-To",
                        email_message.extra_headers['Reply-To'],
                    ))
            except AttributeError:
                pass

            if email_message.attachments:
                for attachment in email_message.attachments:
                    post_data.append(('attachment', (attachment[0], attachment[1],)))
                content, header = encode_multipart_formdata(post_data)
                headers = {'Content-Type': header}
            else:
                content = post_data
                headers = None

            response = requests.post(self._api_url + "messages",
                    auth=("api", self._access_key),
                    data=content, headers=headers)
        except:
            if not self.fail_silently:
                raise
            return False

        if response.status_code != 200:
            if not self.fail_silently:
                raise MailgunAPIError(response)
            return False

        return True

    def send_messages(self, email_messages):
        """Sends one or more EmailMessage objects and returns the number of
        email messages sent.
        """
        if not email_messages:
            return

        num_sent = 0
        for message in email_messages:
            if self._send(message):
                num_sent += 1

        return num_sent