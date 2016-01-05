#-*- coding: utf-8 -*-
from django.db import models
from django.utils.functional import Promise
from django.utils.encoding import force_unicode, smart_unicode
from django.utils import simplejson as json
from decimal import Decimal
from django.core import serializers
from django.conf import settings
from django.http import HttpResponse, HttpResponseForbidden, Http404
from django.core.mail import mail_admins
from django.db.models.query import QuerySet
from mongoengine.queryset.queryset import QuerySet as MongoQuerySet
from bson.objectid import ObjectId
import sys
import datetime


def decode(data):
    if not data:
        return data
    return json.loads(data)


def encode(data, *args, **kwargs):
    if type(data) == QuerySet:  # Careful, ValuesQuerySet is a dict
        # Django models
        return serializers.serialize("json", data, *args, **kwargs)
    else:
        return json_encode(data, *args, **kwargs)


def json_encode(data, *args, **kwargs):
    """
    The main issues with django's default json serializer is that properties that
    had been added to an object dynamically are being ignored (and it also has
    problems with some models).
    """

    def _any(data):
        ret = None
        # Opps, we used to check if it is of type list, but that fails
        # i.e. in the case of django.newforms.utils.ErrorList, which extends
        # the type "list". Oh man, that was a dumb mistake!
        if hasattr(data, 'canonical'):
            ret = _any(data.canonical())
        elif isinstance(data, list):
            ret = _list(data)
        elif isinstance(data, set):
            ret = _list(list(data))
        # Same as for lists above.
        elif isinstance(data, dict):
            ret = _dict(data)
        elif isinstance(data, (Decimal, ObjectId)):
            # json.dumps() cant handle Decimal
            ret = str(data)
        elif isinstance(data, models.query.QuerySet):
            # Actually its the same as a list ...
            ret = _list(data)
        elif isinstance(data, MongoQuerySet):
            # Actually its the same as a list ...
            ret = _list(data)
        elif isinstance(data, models.Model):
            ret = _model(data)
        # here we need to encode the string as unicode (otherwise we get utf-16 in the json-response)
        elif isinstance(data, basestring):
            ret = smart_unicode(data)
        elif isinstance(data, Exception):
            ret = unicode(data)
        # see http://code.djangoproject.com/ticket/5868
        elif isinstance(data, Promise):
            ret = force_unicode(data)
        elif isinstance(data, datetime.datetime) or isinstance(data, datetime.date):
            ret = str(data)
        elif hasattr(data, 'to_json'):
            ret = data.to_json()
        else:
            ret = data
        return ret

    def _model(data):
        ret = {}
        # If we only have a model, we only want to encode the fields.
        for f in data._meta.fields:
            ret[f.attname] = _any(getattr(data, f.attname))
        # And additionally encode arbitrary properties that had been added.
        fields = dir(data.__class__) + ret.keys()
        add_ons = [k for k in dir(data) if k not in fields]
        for k in add_ons:
            ret[k] = _any(getattr(data, k))
        return ret

    def _list(data):
        ret = []
        for v in data:
            ret.append(_any(v))
        return ret

    def _dict(data):
        ret = {}
        for k, v in data.items():
            ret[str(k)] = _any(v)
        return ret

    if hasattr(data, 'to_json'):
        data = data.to_json()
    ret = _any(data)
    return json.dumps(ret)


def json_view(func):
    def wrap(request, *a, **kw):
        response = func(request, *a, **kw)
        return json_response(request, response)

    if isinstance(func, HttpResponse):
        return func
    else:
        return wrap


def json_response(request, response=None):
    code = 200

    if isinstance(response, HttpResponseForbidden):
        return response

    try:
        if isinstance(response, dict):
            response = dict(response)
            if 'result' not in response:
                response['result'] = 'ok'
            authenticated = request.user.is_authenticated()
            response['authenticated'] = authenticated
            if authenticated:
                response['user_id'] = request.user.pk
    except KeyboardInterrupt:
        # Allow keyboard interrupts through for debugging.
        raise
    except Http404:
        raise Http404
    except Exception, e:
        # Mail the admins with the error
        exc_info = sys.exc_info()
        subject = 'JSON view error: %s' % request.path
        try:
            request_repr = repr(request)
        except:
            request_repr = 'Request repr() unavailable'
        import traceback
        message = 'Traceback:\n%s\n\nRequest:\n%s' % (
            '\n'.join(traceback.format_exception(*exc_info)),
            request_repr,
            )

        response = {'result': 'error',
                    'text': unicode(e)}
        code = 500
        if not settings.DEBUG:
            mail_admins(subject, message, fail_silently=True)
        else:
            print '\n'.join(traceback.format_exception(*exc_info))

    json = json_encode(response)
    return HttpResponse(json, mimetype='application/json', status=code)


def main():
    test = {
        1: True,
        2: u"string",
        3: 30,
        4: u"юнікод, ўўў, © ™ ® ё ² § $ ° ќо́",
        5: "utf-8: \xd1\x9e, \xc2\xa9 \xe2\x84\xa2 \xc2\xae \xd1\x91 \xd0\xba\xcc\x81\xd0\xbe\xcc\x81",
    }
    json_test = json_encode(test)
    print test, json_test


if __name__ == '__main__':
    main()
