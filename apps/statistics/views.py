from django.template import RequestContext
from django.shortcuts import render_to_response
from apps.statistics.models import MStatistics, MFeedback

def dashboard_graphs(request):
    statistics = MStatistics.all()
    return render_to_response('statistics/render_statistics_graphs.xhtml', {
        'statistics': statistics,
    }, context_instance=RequestContext(request))

def feedback_table(request):
    feedbacks = MFeedback.all()
    return render_to_response('statistics/render_feedback_table.xhtml', {
        'feedbacks': feedbacks,
    }, context_instance=RequestContext(request))