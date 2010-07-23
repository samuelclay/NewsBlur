import datetime

class LastSeenMiddleware(object):

    def process_response(self, request, response):
        if (request.path == '/'
            and not request.is_ajax() 
            and hasattr(request, 'user')
            and request.user.is_authenticated()): 
            hour_ago = datetime.datetime.now() - datetime.timedelta(minutes=60)
            if request.user.profile.last_seen_on < hour_ago:
                print " ---> Repeat visitor: %s" % request.user
            request.user.profile.last_seen_on = datetime.datetime.now()
            request.user.profile.last_seen_ip = request.META['REMOTE_ADDR']
            request.user.profile.save()
        
        return response