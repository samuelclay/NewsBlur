import datetime
from utils import log as logging
from django.conf import settings

class LastSeenMiddleware(object):

    def process_response(self, request, response):
        if (request.path == '/'
            and not request.is_ajax() 
            and hasattr(request, 'user')
            and request.user.is_authenticated()): 
            hour_ago = datetime.datetime.utcnow() - datetime.timedelta(minutes=60)
            SUBSCRIBER_EXPIRE = datetime.datetime.utcnow() - datetime.timedelta(days=settings.SUBSCRIBER_EXPIRE)
            if request.user.profile.last_seen_on < hour_ago:
                logging.user(request.user, "~FG~BBRepeat visitor: ~SB%s" % (request.user.profile.last_seen_on))
            if request.user.profile.last_seen_on < SUBSCRIBER_EXPIRE:
                request.user.profile.refresh_stale_feeds()
            request.user.profile.last_seen_on = datetime.datetime.utcnow()
            request.user.profile.last_seen_ip = request.META['REMOTE_ADDR']
            request.user.profile.save()
        
        return response