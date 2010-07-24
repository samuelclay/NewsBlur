from django.contrib.auth.models import User
from django.core.cache import cache
from django.utils.hashcompat import md5_constructor
from django.utils.http import urlquote
from django.http import HttpResponseForbidden

DEFAULT_USER = 'conesus'

def ajax_login_required(function=None):
    def _dec(view_func):
        def _view(request, *args, **kwargs):
            if request.user.is_anonymous():
                return HttpResponseForbidden()
            else:
                return view_func(request, *args, **kwargs)

        _view.__name__ = view_func.__name__
        _view.__dict__ = view_func.__dict__
        _view.__doc__ = view_func.__doc__

        return _view

    if function is None:
        return _dec
    else:
        return _dec(function)

def get_user(request):
    if request.user.is_authenticated():
        user = request.user
    else:
        user = cache.get('user:%s' % DEFAULT_USER, None)
        if not user:
            user = User.objects.get(username=DEFAULT_USER)
            cache.set('user:%s' % user, user)
    return user
    
def invalidate_template_cache(fragment_name, *variables):
    args = md5_constructor(u':'.join([urlquote(var) for var in variables]))
    cache_key = 'template.cache.%s.%s' % (fragment_name, args.hexdigest())
    cache.delete(cache_key)