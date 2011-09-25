import datetime
import re
from utils import log as logging
from django.conf import settings
from django.db import connection
from django.template import Template, Context


class LastSeenMiddleware(object):
    def process_response(self, request, response):
        if ((request.path in ('/', '/reader/refresh_feeds', '/reader/load_feeds'))
            and hasattr(request, 'user')
            and request.user.is_authenticated()): 
            hour_ago = datetime.datetime.utcnow() - datetime.timedelta(minutes=60)
            # SUBSCRIBER_EXPIRE = datetime.datetime.utcnow() - datetime.timedelta(days=settings.SUBSCRIBER_EXPIRE)
            if request.user.profile.last_seen_on < hour_ago:
                logging.user(request, "~FG~BBRepeat visitor: ~SB%s" % (request.user.profile.last_seen_on))
            # if request.user.profile.last_seen_on < SUBSCRIBER_EXPIRE:
                # request.user.profile.refresh_stale_feeds()
            request.user.profile.last_seen_on = datetime.datetime.utcnow()
            request.user.profile.last_seen_ip = request.META['REMOTE_ADDR']
            request.user.profile.save()
        
        return response
        
        
class SQLLogToConsoleMiddleware:
    def process_response(self, request, response): 
        if settings.DEBUG and connection.queries:
            time = sum([float(q['time']) for q in connection.queries])
            queries = connection.queries
            for query in queries:
                query['sql'] = re.sub(r'SELECT (.*?) FROM', 'SELECT * FROM', query['sql'])
                query['sql'] = re.sub(r'SELECT', '~FYSELECT', query['sql'])
                query['sql'] = re.sub(r'INSERT', '~FGINSERT', query['sql'])
                query['sql'] = re.sub(r'UPDATE', '~FY~SBUPDATE', query['sql'])
                query['sql'] = re.sub(r'DELETE', '~FR~SBDELETE', query['sql'])
            t = Template("{% for sql in sqllog %}{% if not forloop.first %}                  {% endif %}[{{forloop.counter}}] {{sql.time}}s: {{sql.sql|safe}}{% if not forloop.last %}\n{% endif %}{% endfor %}")
            logging.debug(t.render(Context({'sqllog':queries,'count':len(queries),'time':time})))
        return response