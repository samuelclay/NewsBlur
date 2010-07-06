import datetime

class LastSeenMiddleware(object):

    def process_response(self, request, response):
        if (request.path == '/'
            and not request.is_ajax() 
            and hasattr(request, 'user')
            and request.user.is_authenticated()): 
            request.user.profile.last_seen_on = datetime.datetime.now()
            request.user.profile.last_seen_ip = request.META['REMOTE_ADDR']
            request.user.profile.save()
        
        return response