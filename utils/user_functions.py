from django.contrib.auth.models import User
from django.core.cache import cache
from django.utils.hashcompat import md5_constructor
from django.utils.http import urlquote

DEFAULT_USER = 'conesus'

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