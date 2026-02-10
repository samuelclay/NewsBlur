import base64
import pickle
import time

import redis
from django.conf import settings

from apps.statistics.rstats import round_time
from utils import log as logging

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
                    request_items_str = (
                        request_items_str[:100]
                        + "...["
                        + str(len(request_items_str) - 200)
                        + " bytes]..."
                        + request_items_str[-100:]
                    )
                logging.debug(
                    " ---> ~FC%s ~SN~FK~BC%s~BT~ST ~FC%s~BK~FC"
                    % (request.method, request.path, request_items_str)
                )
            else:
                logging.debug(" ---> ~FC%s ~SN~FK~BC%s~BT~ST" % (request.method, request.path))

    def process_response(self, request, response):
        if hasattr(request, "sql_times_elapsed"):
            counts = getattr(request, "sql_call_counts", {})
            times = request.sql_times_elapsed
            redis_parts = []
            for key, label in [("redis_user", "user"), ("redis_story", "story"), ("redis_session", "session"), ("redis_pubsub", "pubsub")]:
                c = counts.get(key, 0)
                t = times[key]
                color = self.color_db(t, "~FC")
                redis_parts.append("%s%s:%s/%s~SN" % (color, label, c, self.format_db_time(t)))
            redis_log = " ".join(redis_parts)
            sql_color = self.color_db(times["sql"], "~FY")
            mongo_color = self.color_db(times["mongo"], "~FM")
            logging.user(
                request,
                "~SN~FCDB times ~SD~FW%s~SN~FC: %ssql: %s/%s~SN %smongo: %s/%s~SN ~FCredis: %s"
                % (
                    request.path,
                    sql_color,
                    counts.get("sql", 0),
                    self.format_db_time(times["sql"]),
                    mongo_color,
                    counts.get("mongo", 0),
                    self.format_db_time(times["mongo"]),
                    redis_log,
                ),
            )

        if hasattr(request, "start_time"):
            seconds = time.time() - request.start_time
            if seconds > RECORD_SLOW_REQUESTS_ABOVE_SECONDS:
                r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
                pipe = r.pipeline()
                minute = round_time(round_to=60)
                name = f"SLOW:{minute.strftime('%s')}"
                user_id = request.user.pk if request.user.is_authenticated else "0"
                data_string = None
                if request.method == "GET":
                    data_string = " ".join([f"{key}={value}" for key, value in request.GET.items()])
                elif request.method == "GET":
                    data_string = " ".join([f"{key}={value}" for key, value in request.POST.items()])
                data = {
                    "user_id": user_id,
                    "time": round(seconds, 2),
                    "path": request.path,
                    "method": request.method,
                    "data": data_string,
                }
                pipe.lpush(name, base64.b64encode(pickle.dumps(data)).decode("utf-8"))
                pipe.expire(name, 60 * 60 * 12)  # 12 hours
                pipe.execute()

        return response

    def format_db_time(self, seconds):
        return "%.3fs" % seconds

    def color_db(self, seconds, default):
        color = default
        if seconds >= 0.25:
            color = "~SB~FR"
        elif seconds > 0.1:
            color = "~FW"
        elif seconds == 0:
            color = "~SD~FW"
        return color

    def __init__(self, get_response=None):
        self.get_response = get_response

    def __call__(self, request):
        response = None
        if hasattr(self, "process_request"):
            response = self.process_request(request)
        if not response:
            response = self.get_response(request)
        if hasattr(self, "process_response"):
            response = self.process_response(request, response)

        return response
