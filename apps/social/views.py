import datetime
from apps.rss_feeds.models import MStory
from apps.social.models import MSharedStory
from utils import json_functions as json
from utils.user_functions import ajax_login_required
from utils import log as logging

@ajax_login_required
@json.json_view
def mark_story_as_shared(request):
    code     = 1
    feed_id  = int(request.POST['feed_id'])
    story_id = request.POST['story_id']
    comments = request.POST.get('comments', '')
    
    story = MStory.objects(story_feed_id=feed_id, story_guid=story_id).limit(1)
    if story:
        story_db = dict([(k, v) for k, v in story[0]._data.items() 
                                if k is not None and v is not None])
        now = datetime.datetime.now()
        story_values = dict(user_id=request.user.pk, shared_date=now, comments=comments, **story_db)
        MSharedStory.objects.create(**story_values)
        logging.user(request, "~FCSharing: ~SB~FM%s (~FB%s~FM)" % (story[0].story_title[:50], comments[:100]))
    else:
        code = -1
    
    return {'code': code}