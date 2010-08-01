from django.views.decorators.http import require_POST
from apps.rss_feeds.models import Feed, Tag, StoryAuthor
from apps.reader.models import UserSubscription
from apps.analyzer.models import ClassifierTitle, ClassifierAuthor, ClassifierFeed, ClassifierTag, get_classifiers_for_user
from utils import json
from utils.user_functions import get_user
from utils.user_functions import ajax_login_required

def index(requst):
    pass
    
@require_POST
@ajax_login_required
@json.json_view
def save_classifier(request):
    post = request.POST
    feed = Feed.objects.get(pk=post['feed_id'])
    code = 0
    message = 'OK'
    payload = {}

    # Make subscription as dirty, so unread counts can be recalculated
    usersub = UserSubscription.objects.get(user=request.user, feed=feed)
    if not usersub.needs_unread_recalc or not usersub.is_trained:
        usersub.needs_unread_recalc = True
        usersub.is_trained = True
        usersub.save()
        
        
    def _save_classifier(ClassifierCls, content_type, ContentCls=None, post_content_field=None):
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
                    classifier_dict = {
                        'user': request.user,
                        'feed': feed,
                        'defaults': {
                            'score': score
                        }
                    }
                    # if story:
                        # classifier_dict['defaults'].update(original_story=story)
                    if content_type in ('author', 'tag'):
                        # Use content to lookup object. Authors, Tags.
                        content_dict = {
                            post_content_field: post_content,
                            'feed': feed
                        }
                        content = ContentCls.objects.get(**content_dict)
                        classifier_dict.update({content_type: content})
                    elif content_type in ('title',):
                        # Skip content lookup and just use content directly. Titles.
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
                        
    _save_classifier(ClassifierAuthor, 'author', StoryAuthor, 'author_name')
    _save_classifier(ClassifierTag, 'tag', Tag, 'name')
    _save_classifier(ClassifierTitle, 'title')
    _save_classifier(ClassifierFeed, 'publisher')
    
    response = dict(code=code, message=message, payload=payload)
    return response
    
@json.json_view
def get_classifiers_feed(request):
    feed = request.POST['feed_id']
    user = get_user(request)
    code = 0
    
    payload = get_classifiers_for_user(user, feed)
    
    response = dict(code=code, payload=payload)
    
    return response
    