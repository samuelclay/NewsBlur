from django.conf import settings
from utils import log as logging
from apps.statistics.rstats import round_time
import pickle
import base64
import time
import redis

IGNORE_PATHS = [
    "/_haproxychk",
]

RECORD_SLOW_REQUESTS_ABOVE_SECONDS = 10

class DumpRequestMiddleware:
    def process_request(self, request):
        if settings.DEBUG and request.path not in IGNORE_PATHS:
            request_data = request.POST or request.GET
            request_items = dict(request_data).items()
            if request_items:
                request_items_str = f"{dict(request_items)}"
                if len(request_items_str) > 500:
                    request_items_str = request_items_str[:100] + "...[" + str(len(request_items_str)-200) + " bytes]..." + request_items_str[-100:]
                logging.debug(" ---> ~FC%s ~SN~FK~BC%s~BT~ST ~FC%s~BK~FC" % (request.method, request.path, request_items_str))
            else:
                logging.debug(" ---> ~FC%s ~SN~FK~BC%s~BT~ST" % (request.method, request.path))

    def process_response(self, request, response):
        if hasattr(request, 'sql_times_elapsed'):
            redis_log = "~FCuser:%s%.6f~SNs ~FCstory:%s%.6f~SNs ~FCsession:%s%.6f~SNs ~FCpubsub:%s%.6f~SNs" % (
                self.color_db(request.sql_times_elapsed['redis_user'], '~FC'),
                request.sql_times_elapsed['redis_user'],
                self.color_db(request.sql_times_elapsed['redis_story'], '~FC'),
                request.sql_times_elapsed['redis_story'],
                self.color_db(request.sql_times_elapsed['redis_session'], '~FC'),
                request.sql_times_elapsed['redis_session'],
                self.color_db(request.sql_times_elapsed['redis_pubsub'], '~FC'),
                request.sql_times_elapsed['redis_pubsub'],
            )
            logging.user(request, "~SN~FCDB times ~SB~FK%s~SN~FC: ~FYsql: %s%.4f~SNs ~SN~FMmongo: %s%.5f~SNs ~SN~FCredis: %s" % (
                request.path,
                self.color_db(request.sql_times_elapsed['sql'], '~FY'),
                request.sql_times_elapsed['sql'], 
                self.color_db(request.sql_times_elapsed['mongo'], '~FM'),
                request.sql_times_elapsed['mongo'],
                redis_log
            ))

        if hasattr(request, 'start_time'):
            seconds = time.time() - request.start_time
            if seconds > RECORD_SLOW_REQUESTS_ABOVE_SECONDS:
                r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
                pipe = r.pipeline()
                minute = round_time(round_to=60)
                name = f"SLOW:{minute.strftime('%s')}"
                user_id = request.user.pk if request.user.is_authenticated else "0"
                data_string = None
                if request.method == "GET":
                    data_string = ' '.join([f"{key}={value}" for key, value in request.GET.items()])
                elif request.method == "GET":
                    data_string = ' '.join([f"{key}={value}" for key, value in request.POST.items()])
                data = {
                    "user_id": user_id,
                    "time": round(seconds, 2),
                    "path": request.path,
                    "method": request.method,
                    "data": data_string,
                }
                pipe.lpush(name, base64.b64encode(pickle.dumps(data)).decode('utf-8'))
                pipe.expire(name, 60*60*12) # 12 hours
                pipe.execute()
                
        return response
    
    def color_db(self, seconds, default):
        color = default
        if seconds >= .25:
            color = '~SB~FR'
        elif seconds > .1:
            color = '~FW'
        # elif seconds == 0:
        #     color = '~FK~SB'
        return color

    def __init__(self, get_response=None):
        self.get_response = get_response

    def __call__(self, request):
        response = None
        if hasattr(self, 'process_request'):
            response = self.process_request(request)
        if not response:
            response = self.get_response(request)
        if hasattr(self, 'process_response'):
            response = self.process_response(request, response)

        return response
