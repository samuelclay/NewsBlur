from utils import log as logging
from django.shortcuts import get_object_or_404
from django.views.decorators.http import require_POST
from apps.rss_feeds.models import Feed
from apps.reader.models import UserSubscription
from apps.analyzer.models import MClassifierTitle, MClassifierAuthor, MClassifierFeed, MClassifierTag
from apps.analyzer.models import get_classifiers_for_user
from utils import json_functions as json
from utils.user_functions import get_user
from utils.user_functions import ajax_login_required

def index(requst):
    pass
    
@require_POST
@ajax_login_required
@json.json_view
def save_classifier(request):
    post = request.POST
    feed_id = int(post['feed_id'])
    feed = get_object_or_404(Feed, pk=feed_id)
    code = 0
    message = 'OK'
    payload = {}

    logging.user(request, "~FGSaving classifier: ~SB%s~SN ~FW%s" % (feed, post))
    
    # Mark subscription as dirty, so unread counts can be recalculated
    try:
        usersub = UserSubscription.objects.get(user=request.user, feed=feed)
    except UserSubscription.DoesNotExist:
        usersub = None
    if usersub and (not usersub.needs_unread_recalc or not usersub.is_trained):
        usersub.needs_unread_recalc = True
        usersub.is_trained = True
        usersub.save()
        
        
    def _save_classifier(ClassifierCls, content_type):
        classifiers = {
            'like_'+content_type: 1, 
            'dislike_'+content_type: -1,
            'remove_like_'+content_type: 0,
            'remove_dislike_'+content_type: 0,
        }
        for opinion, score in classifiers.items():
            if opinion in post:
                post_contents = post.getlist(opinion)
                for post_content in post_contents:
                    if not post_content: continue
                    classifier_dict = {
                        'user_id': request.user.pk,
                        'feed_id': feed_id,
                        'defaults': {
                            'score': score
                        }
                    }
                    if content_type in ('author', 'tag', 'title'):
                        classifier_dict.update({content_type: post_content})
                    
                    classifier, created = ClassifierCls.objects.get_or_create(**classifier_dict)
                    if score == 0:
                        classifier.delete()
                    elif classifier.score != score:
                        if score == 0:
                            if ((classifier.score == 1 and opinion.startswith('remove_like'))
                                or (classifier.score == -1 and opinion.startswith('remove_dislike'))):
                                classifier.delete()
                        else:
                            classifier.score = score
                            classifier.save()
                        
    _save_classifier(MClassifierAuthor, 'author')
    _save_classifier(MClassifierTag, 'tag')
    _save_classifier(MClassifierTitle, 'title')
    _save_classifier(MClassifierFeed, 'feed')

    response = dict(code=code, message=message, payload=payload)
    return response
    
@json.json_view
def get_classifiers_feed(request, feed_id):
    user = get_user(request)
    code = 0
    
    payload = get_classifiers_for_user(user, feed_id)
    
    response = dict(code=code, payload=payload)
    
    return response
    