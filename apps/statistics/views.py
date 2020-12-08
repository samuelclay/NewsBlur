import datetime
from django.http import HttpResponse
from django.shortcuts import render
from django.utils import feedgenerator
from apps.statistics.models import MStatistics, MFeedback
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
    