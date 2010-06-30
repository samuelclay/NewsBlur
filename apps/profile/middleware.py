import datetime

class LastSeenMiddleware(object):

    def process_response(self, request, response):
        if not request.is_ajax() and request.user.is_authenticated(): 
            request.user.profile.last_seen_on = datetime.datetime.now()
            request.user.profile.last_activity_ip = request.META['REMOTE_ADDR']
            request.user.profile.save()
        
        return response