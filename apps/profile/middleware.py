import datetime
from utils import log as logging

class LastSeenMiddleware(object):

    def process_response(self, request, response):
        if (request.path == '/'
            and not request.is_ajax() 
            and hasattr(request, 'user')
            and request.user.is_authenticated()): 
            hour_ago = datetime.datetime.utcnow() - datetime.timedelta(minutes=60)
            if request.user.profile.last_seen_on < hour_ago:
                logging.info(" ---> [%s] ~FG~BBRepeat visitor: ~SB%s" % (request.user, request.user.profile.last_seen_on))
            request.user.profile.last_seen_on = datetime.datetime.utcnow()
            request.user.profile.last_seen_ip = request.META['REMOTE_ADDR']
            request.user.profile.save()
        
        return response