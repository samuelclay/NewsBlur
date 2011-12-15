from django.conf.urls.defaults import url, patterns
from apps.social import views

urlpatterns = patterns('',
    url(r'^share_story/?$', views.mark_story_as_shared, name='mark-story-as-shared'),
)
