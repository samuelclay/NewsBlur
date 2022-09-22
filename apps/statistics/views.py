import base64
import pickle
import redis
import datetime
from operator import countOf
from collections import defaultdict
from django.http import HttpResponse
from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import AnonymousUser
from django.contrib.auth.models import User
from django.conf import settings
from django.utils import feedgenerator
from django.http import HttpResponseForbidden
from apps.statistics.models import MStatistics, MFeedback
from apps.statistics.rstats import round_time
from apps.profile.models import PaymentHistory
from utils import log as logging

def dashboard_graphs(request):
    statistics = MStatistics.all()
    return render(
        request,
        'statistics/render_statistics_graphs.xhtml', 
        {'statistics': statistics}
    )

def feedback_table(request):
    feedbacks = MFeedback.all()
    return render(
        request, 
        'statistics/render_feedback_table.xhtml',
        {'feedbacks': feedbacks}
    )

def revenue(request):
    data = {}
    data['title'] = "NewsBlur Revenue"
    data['link'] = "https://www.newsblur.com"
    data['description'] = "Revenue"
    data['lastBuildDate'] = datetime.datetime.utcnow()
    data['generator'] = 'NewsBlur Revenue Writer'
    data['docs'] = None
    rss = feedgenerator.Atom1Feed(**data)
    
    report = PaymentHistory.report()
    content = "%s revenue: $%s<br><code>%s</code>" % (datetime.datetime.now().strftime('%Y'), report['annual'], report['output'].replace('\n', '<br>'))
    
    story = {
        'title': "Daily snapshot: %s" % (datetime.datetime.now().strftime('%a %b %-d, %Y')),
        'link': 'https://www.newsblur.com',
        'description': content,
        'unique_id': datetime.datetime.now().strftime('%a %b %-d, %Y'),
        'pubdate': datetime.datetime.now(),
    }
    rss.add_item(**story)
    
    logging.user(request, "~FBGenerating Revenue RSS feed: ~FM%s" % (
        request.META.get('HTTP_USER_AGENT', "")[:24]
    ))
    return HttpResponse(rss.writeString('utf-8'), content_type='application/rss+xml')


@login_required
def slow(request):
    r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
    if not request.user.is_staff and not settings.DEBUG:
        logging.user(request, "~SKNON-STAFF VIEWING SLOW STATUS!")
        assert False
        return HttpResponseForbidden()

    now = datetime.datetime.now()
    all_queries = {}
    user_id_counts = {}
    path_counts = {}
    users = {}
    
    for minutes_ago in range(60*6):
        dt_ago = now - datetime.timedelta(minutes=minutes_ago)
        minute = round_time(dt_ago, round_to=60)
        dt_ago_str = minute.strftime("%a %b %-d, %Y %H:%M")
        name = f"SLOW:{minute.strftime('%s')}"
        minute_queries = r.lrange(name, 0, -1)
        for query_raw in minute_queries:
            query = pickle.loads(base64.b64decode(query_raw))
            user_id = query['user_id']
            if dt_ago_str not in all_queries:
                all_queries[dt_ago_str] = []
            if user_id in users:
                user = users[user_id]
            elif int(user_id) != 0:
                try:
                    user = User.objects.get(pk=user_id)
                except User.DoesNotExist:
                    continue
                users[user_id] = user
            else:
                user = AnonymousUser()
                users[user_id] = user
            query['user'] = user
            query['datetime'] = minute
            all_queries[dt_ago_str].append(query)
            if user_id not in user_id_counts:
                user_id_counts[user_id] = 0
            user_id_counts[user_id] += 1
            if query['path'] not in path_counts:
                path_counts[query['path']] = 0
            path_counts[query['path']] += 1

    user_counts = []
    for user_id, count in user_id_counts.items():
        user_counts.append({'user': users[user_id], 'count': count})
    
    return render(request, 'statistics/slow.xhtml', {
        'all_queries': all_queries,
        'user_counts': user_counts,
        'path_counts': path_counts,
    })
