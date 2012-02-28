from django.core.serializers.json import DateTimeAwareJSONEncoder
from django.db import models
from django.utils.functional import Promise
from django.utils.encoding import force_unicode
from django.utils import simplejson as json
import cjson
from decimal import Decimal
from django.core import serializers
from django.conf import settings
from django.http import HttpResponse, HttpResponseForbidden, Http404
from django.core.mail import mail_admins
from django.db.models.query import QuerySet
import sys
import datetime

def decode(data):
    if not data:
        return data
    # return json.loads(data)
    try:
        return cjson.decode(data, encoding='utf-8')
    except cjson.DecodeError:
        return cjson.decode(data)
    
def encode(data, *args, **kwargs):
    if type(data) == QuerySet: # Careful, ValuesQuerySet is a dict
        # Django models
        return serializers.serialize("json", data, *args, **kwargs)
    else:
        return cjson.encode(data, encoding='utf-8', key2str=True, 
                            extension=lambda x: "\"%s\"" % str(x))
        # return json_encode(data, *args, **kwargs)

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
        if hasattr(data, 'to_json'):
            ret = data.to_json()
        elif isinstance(data, list):
            ret = _list(data)
        # Same as for lists above.
        elif isinstance(data, dict):
            ret = _dict(data)
        elif isinstance(data, Decimal):
            # json.dumps() cant handle Decimal
            ret = str(data)
        elif isinstance(data, models.query.QuerySet):
            # Actually its the same as a list ...
            ret = _list(data)
        elif isinstance(data, models.Model):
            ret = _model(data)
        # here we need to encode the string as unicode (otherwise we get utf-16 in the json-response)
        elif isinstance(data, basestring):
            ret = unicode(data)
        # see http://code.djangoproject.com/ticket/5868
        elif isinstance(data, Promise):
            ret = force_unicode(data)
        elif isinstance(data, datetime.datetime) or isinstance(data, datetime.date):
            ret = str(data)
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
        for k,v in data.items():
            ret[str(k)] = _any(v)
        return ret
    
    ret = _any(data)
    return json.dumps(ret)
    # return cjson.encode(ret, encoding='utf-8', extension=lambda x: "\"%s\"" % str(x))

def json_view(func):
    def wrap(request, *a, **kw):
        response = None
        code = 200
        try:
            response = func(request, *a, **kw)
            if isinstance(response, dict):
                response = dict(response)
                if 'result' not in response:
                    response['result'] = 'ok'
                authenticated = request.user.is_authenticated()
                response['authenticated'] = authenticated
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
            # print message
            if not settings.DEBUG:
                mail_admins(subject, message, fail_silently=True)

                response = {'result': 'error',
                            'text': unicode(e)}
                code = 500
            else:
                print '\n'.join(traceback.format_exception(*exc_info))

        if isinstance(response, HttpResponseForbidden):
            return response
        json = json_encode(response)
        return HttpResponse(json, mimetype='application/json', status=code)
    if isinstance(func, HttpResponse):
        return func
    else:
        return wrap

def main():
    test = {1: True, 2: u"string", 3: 30}
    json_test = json_encode(test)
    print test, json_test
    
if __name__ == '__main__':
    main()