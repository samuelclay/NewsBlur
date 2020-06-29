import math
import redis
from django.conf import settings
from django.contrib.sessions.models import Session

sessions_count = Session.objects.count()
print " ---> %s sessions in Django" % sessions_count
batch_size = 1000
r = redis.Redis(connection_pool=settings.REDIS_SESSION_POOL)

for batch in range(int(math.ceil(sessions_count / batch_size))+1):
    start = batch * batch_size
    end = (batch + 1) * batch_size
    print " ---> Loading sessions #%s - #%s" % (start, end)
    pipe = r.pipeline()
    for session in Session.objects.all()[start:end]:
        _ = pipe.set(session.session_key, session.session_data)
        _ = pipe.expireat(session.session_key, session.expire_date.strftime("%s"))
    _ = pipe.execute()