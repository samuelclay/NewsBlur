from django.http import Http404, HttpResponse
from django.template import RequestContext
from django.shortcuts import render_to_response
from utils import json_functions as json
import functools

def get_argument_or_404(request, param, method='REQUEST', code='404'):
    try:
        return getattr(request, method)[param]
    except KeyError:
        if code == '404':
            raise Http404
        else:
            return 
        
def render_to(template):
    """
    Decorator for Django views that sends returned dict to render_to_response function
    with given template and RequestContext as context instance.

    If view doesn't return dict then decorator simply returns output.
    Additionally view can return two-tuple, which must contain dict as first
    element and string with template name as second. This string will
    override template name, given as parameter

    Parameters:

     - template: template name to use
    """
    def renderer(func):
        def wrapper(request, *args, **kw):
            output = func(request, *args, **kw)
            if isinstance(output, (list, tuple)):
                return render_to_response(output[1], output[0], RequestContext(request))
            elif isinstance(output, dict):
                return render_to_response(template, output, RequestContext(request))
            return output
        return wrapper
    return renderer
    
def is_true(value):
    if value == 1:
        return True
    return bool(value) and isinstance(value, basestring) and value.lower() not in ('false', '0')
    
class required_params(object):
    "Instances of this class can be used as decorators"
    
    def __init__(self, *args, **kwargs):
        self.params = args
        self.named_params = kwargs
        self.method = kwargs.get('method', 'REQUEST')
        
    def __call__(self, fn):
        def wrapper(request, *args, **kwargs):
            return self.view_wrapper(request, fn, *args, **kwargs)
        functools.update_wrapper(wrapper, fn)
        return wrapper
    
    def view_wrapper(self, request, fn, *args, **kwargs):
        if request.method != self.method and self.method != 'REQUEST':
            return self.disallowed(method=True, status_code=405)
        
        # Check if parameter is included
        for param in self.params:
            if getattr(request, self.method).get(param) is None:
                print " Unnamed parameter not found: %s" % param
                return self.disallowed(param)

        # Check if parameter is correct type
        for param, param_type in self.named_params.items():
            if getattr(request, self.method).get(param) is None:
                print " Typed parameter not found: %s" % param
                return self.disallowed(param)
            try:
                if param_type(getattr(request, self.method).get(param)) is None:
                    print " Typed parameter wrong: %s" % param
                    return self.disallowed(param, param_type)
            except (TypeError, ValueError), e:
                print " %s -> %s" % (param, e)
                return self.disallowed(param, param_type)
                
        return fn(request, *args, **kwargs)

    def disallowed(self, param=None, param_type=None, method=False, status_code=400):
        if method:
            message = "Invalid HTTP method. Use %s." % self.method
        elif param_type:
            message = "Invalid paramter: %s - needs to be %s" % (
                param,
                param_type,
            )
        else:
            message = "Missing parameter: %s" % param

        return HttpResponse(json.encode({
            'message': message,
            'code': -1,
        }), mimetype="application/json", status=status_code)