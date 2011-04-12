#!/usr/bin/env python
# -*- coding: utf-8 -*-
from django.http import HttpResponse
from django.views.decorators.http import require_POST
from paypal.standard.ipn.forms import PayPalIPNForm
from paypal.standard.ipn.models import PayPalIPN


@require_POST
def ipn(request, item_check_callable=None):
    """
    PayPal IPN endpoint (notify_url).
    Used by both PayPal Payments Pro and Payments Standard to confirm transactions.
    http://tinyurl.com/d9vu9d
    
    PayPal IPN Simulator:
    https://developer.paypal.com/cgi-bin/devscr?cmd=_ipn-link-session
    """
    flag = None
    ipn_obj = None
    form = PayPalIPNForm(request.POST)
    if form.is_valid():
        try:
            ipn_obj = form.save(commit=False)
        except Exception, e:
            flag = "Exception while processing. (%s)" % e
    else:
        flag = "Invalid form. (%s)" % form.errors

    if ipn_obj is None:
        ipn_obj = PayPalIPN()    

    ipn_obj.initialize(request)

    if flag is not None:
        ipn_obj.set_flag(flag)
    else:
        # Secrets should only be used over SSL.
        if request.is_secure() and 'secret' in request.GET:
            ipn_obj.verify_secret(form, request.GET['secret'])
        else:
            ipn_obj.verify(item_check_callable)

    ipn_obj.save()
    return HttpResponse("OKAY")