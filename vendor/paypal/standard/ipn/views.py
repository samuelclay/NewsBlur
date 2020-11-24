#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import unicode_literals

import logging

from django.http import HttpResponse, QueryDict
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from paypal.standard.ipn.forms import PayPalIPNForm
from paypal.standard.ipn.models import PayPalIPN
from paypal.standard.models import DEFAULT_ENCODING
from paypal.utils import warn_untested

logger = logging.getLogger(__name__)

CONTENT_TYPE_ERROR = ("Invalid Content-Type - PayPal is only expected to use "
                      "application/x-www-form-urlencoded. If using django's "
                      "test Client, set `content_type` explicitly")


@require_POST
@csrf_exempt
def ipn(request):
    """
    PayPal IPN endpoint (notify_url).
    Used by both PayPal Payments Pro and Payments Standard to confirm transactions.
    http://tinyurl.com/d9vu9d

    PayPal IPN Simulator:
    https://developer.paypal.com/cgi-bin/devscr?cmd=_ipn-link-session
    """
    # TODO: Clean up code so that we don't need to set None here and have a lot
    #       of if checks just to determine if flag is set.
    flag = None
    ipn_obj = None

    # Avoid the RawPostDataException. See original issue for details:
    # https://github.com/spookylukey/django-paypal/issues/79
    if not request.META.get('CONTENT_TYPE', '').startswith(
            'application/x-www-form-urlencoded'):
        raise AssertionError(CONTENT_TYPE_ERROR)

    logger.debug("PayPal incoming POST data: %s", request.body)

    # Clean up the data as PayPal sends some weird values such as "N/A"
    # Also, need to cope with custom encoding, which is stored in the body (!).
    # Assuming the tolerant parsing of QueryDict and an ASCII-like encoding,
    # such as windows-1252, latin1 or UTF8, the following will work:
    encoding = request.POST.get('charset', None)

    encoding_missing = encoding is None
    if encoding_missing:
        encoding = DEFAULT_ENCODING

    try:
        data = QueryDict(request.body, encoding=encoding).copy()
    except LookupError:
        warn_untested()
        data = None
        flag = "Invalid form - invalid charset"

    if data is not None:
        if hasattr(PayPalIPN._meta, 'get_fields'):
            date_fields = [f.attname for f in PayPalIPN._meta.get_fields() if f.__class__.__name__ == 'DateTimeField']
        else:
            date_fields = [f.attname for f, m in PayPalIPN._meta.get_fields_with_model()
                           if f.__class__.__name__ == 'DateTimeField']

        for date_field in date_fields:
            if data.get(date_field) == 'N/A':
                del data[date_field]

        form = PayPalIPNForm(data)
        if form.is_valid():
            try:
                # When commit = False, object is returned without saving to DB.
                ipn_obj = form.save(commit=False)
            except Exception as e:
                flag = "Exception while processing. (%s)" % e
        else:
            formatted_form_errors = ["{0}: {1}".format(k, ", ".join(v)) for k, v in form.errors.items()]
            flag = "Invalid form. ({0})".format(", ".join(formatted_form_errors))

    if ipn_obj is None:
        ipn_obj = PayPalIPN()

    # Set query params and sender's IP address
    ipn_obj.initialize(request)

    if flag is not None:
        # We save errors in the flag field
        ipn_obj.set_flag(flag)
    else:
        # Secrets should only be used over SSL.
        if request.is_secure() and 'secret' in request.GET:
            warn_untested()
            ipn_obj.verify_secret(form, request.GET['secret'])
        else:
            ipn_obj.verify()

    ipn_obj.save()
    ipn_obj.send_signals()

    if encoding_missing:
        # Wait until we have an ID to log warning
        logger.warning("No charset passed with PayPalIPN: %s. Guessing %s", ipn_obj.id, encoding)

    return HttpResponse("OKAY")
