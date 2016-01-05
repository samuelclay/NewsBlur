from django.conf.urls import *
from apps.api import views

urlpatterns = patterns('',
    url(r'^logout', views.logout, name='api-logout'),
    url(r'^login', views.login, name='api-login'),
    url(r'^signup', views.signup, name='api-signup'),
    url(r'^add_site_load_script/(?P<token>\w+)', views.add_site_load_script, name='api-add-site-load-script'),
    url(r'^add_site/(?P<token>\w+)', views.add_site, name='api-add-site'),
    url(r'^check_share_on_site/(?P<token>\w+)', views.check_share_on_site, name='api-check-share-on-site'),
    url(r'^share_story/(?P<token>\w+)', views.share_story, name='api-share-story'),
    url(r'^share_story/?$', views.share_story),
)
