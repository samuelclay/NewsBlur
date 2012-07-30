from django.http import Http404
from django.template import RequestContext
from django.shortcuts import render_to_response

def get_argument_or_404(request, param, method='REQUEST'):
    try:
        return getattr(request, method)[param]
    except KeyError:
        raise Http404
        
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