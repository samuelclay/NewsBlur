import hashlib
from simplejson.decoder import JSONDecodeError
from utils import json_functions as json
from django.contrib.auth.models import User
from django.core.cache import cache
from django.utils.http import urlquote
from django.http import HttpResponseForbidden
from django.http import HttpResponse
from django.conf import settings

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

def oauth_login_required(function=None):
    def _dec(view_func):
        def _view(request, *args, **kwargs):
            if request.user.is_anonymous():
                return HttpResponse(content=json.encode({
                    "message": "You must have a valid OAuth token.",
                }), status=401)
            else:
                try:
                    setattr(request, 'body_json', json.decode(request.body))
                except JSONDecodeError:
                    return HttpResponse(content=json.encode({
                        "message": "Your JSON body is malformed.",
                    }), status=400)
                return view_func(request, *args, **kwargs)

        _view.__name__ = view_func.__name__
        _view.__dict__ = view_func.__dict__
        _view.__doc__ = view_func.__doc__

        return _view

    if function is None:
        return _dec
    else:
        return _dec(function)

def admin_only(function=None):
    def _dec(view_func):
        def _view(request, *args, **kwargs):
            if not request.user.is_staff:
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
    if not hasattr(request, 'user'):
        user = request
    else:
        user = request.user
        
    if user.is_anonymous():
        user = cache.get('user:%s' % settings.HOMEPAGE_USERNAME, None)
        if not user:
            try:
                user = User.objects.get(username=settings.HOMEPAGE_USERNAME)
                cache.set('user:%s' % user, user)
            except User.DoesNotExist:
                user = User.objects.create(username=settings.HOMEPAGE_USERNAME)
                user.set_password('')
                user.save()
    return user
    
def invalidate_template_cache(fragment_name, *variables):
    args = hashlib.md5(u':'.join([urlquote(var) for var in variables]))
    cache_key = 'template.cache.%s.%s' % (fragment_name, args.hexdigest())
    cache.delete(cache_key)
    
def generate_secret_token(phrase, size=12):
    """Generate a (SHA1) security hash from the provided info."""
    info = (phrase, settings.SECRET_KEY)
    return hashlib.sha1("".join(info)).hexdigest()[:size]

def extract_user_agent(request):
    user_agent = request.environ.get('HTTP_USER_AGENT', '').lower()
    platform = '------'
    if 'ipad app' in user_agent:
        platform = 'iPad'
    elif 'iphone app' in user_agent:
        platform = 'iPhone'
    elif 'blar' in user_agent:
        platform = 'Blar'
    elif 'Android app' in user_agent:
        platform = 'Androd'
    elif 'android' in user_agent:
        platform = 'androd'
    elif 'pluggio' in user_agent:
        platform = 'Plugio'
    elif 'msie' in user_agent:
        platform = 'IE'
        if 'msie 9' in user_agent:
            platform += '9'
        elif 'msie 10' in user_agent:
            platform += '10'
        elif 'msie 8' in user_agent:
            platform += '8'
    elif 'trident/7' in user_agent:
        platform = 'IE11'
    elif 'chrome' in user_agent:
        platform = 'Chrome'
    elif 'safari' in user_agent:
        platform = 'Safari'
    elif 'meego' in user_agent:
        platform = 'MeeGo'
    elif 'firefox' in user_agent:
        platform = 'FF'
    elif 'opera' in user_agent:
        platform = 'Opera'
    elif 'wp7' in user_agent:
        platform = 'WP7'
    elif 'wp8' in user_agent:
        platform = 'WP8'
    elif 'tafiti' in user_agent:
        platform = 'Tafiti'
    elif 'readkit' in user_agent:
        platform = 'ReadKt'
    elif 'reeder' in user_agent:
        platform = 'Reeder'
    elif 'metroblur' in user_agent:
        platform = 'Metrob'
    elif 'feedme' in user_agent:
        platform = 'FeedMe'
    elif 'theoldreader' in user_agent:
        platform = 'OldRdr'
    elif 'fever' in user_agent:
        platform = 'Fever'
    elif 'superfeedr' in user_agent:
        platform = 'Suprfd'
    elif 'feed reader-window' in user_agent:
        platform = 'FeedRe'
    elif 'feed reader-background' in user_agent:
        platform = 'FeReBg'
    
    return platform
