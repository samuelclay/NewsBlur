from django.contrib.auth.models import User
from django.core.cache import cache

DEFAULT_USER = 'conesus'

def get_user(request):
    if request.user.is_authenticated():
        user = request.user
    else:
        user = cache.get('user:%s' % DEFAULT_USER, None)
        if not user:
            print "USER CACHE MISS"
            user = User.objects.get(username=DEFAULT_USER)
            cache.set('user:%s' % user, user)
    return user