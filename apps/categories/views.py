from apps.categories.models import MCategory
from apps.reader.models import UserSubscriptionFolders
from utils import json_functions as json
from utils.user_functions import ajax_login_required

@json.json_view
def all_categories(request):
    categories = MCategory.serialize()
    
    return categories
    
@ajax_login_required
@json.json_view
def subscribe(request):
    user = request.user
    categories = MCategory.serialize()
    category_titles = [c['title'] for c in categories['categories']]
    subscribe_category_titles = request.REQUEST.getlist('category')
    
    invalid_category_title = False
    for category_title in subscribe_category_titles:
        if category_title not in category_titles:
            invalid_category_title = True
            
    if not subscribe_category_titles or invalid_category_title:
        message = "Choose one or more of these categories: %s" % ', '.join(category_titles)
        return dict(code=-1, message=message)
    
    for category_title in subscribe_category_titles:
        MCategory.subscribe(user.pk, category_title)
    
    usf = UserSubscriptionFolders.objects.get(user=user.pk)
    
    return dict(code=1, message="Subscribed to %s %s" % (
        len(subscribe_category_titles),
        'category' if len(subscribe_category_titles) == 1 else 'categories',
    ), folders=json.decode(usf.folders))