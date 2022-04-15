from django.conf.urls import url
from apps.api import views

urlpatterns = [
    url(r'^logout', views.logout, name='api-logout'),
    url(r'^login', views.login, name='api-login'),
    url(r'^signup', views.signup, name='api-signup'),
    url(r'^add_site_load_script/(?P<token>\w+)', views.add_site_load_script, name='api-add-site-load-script'),
    url(r'^add_site/(?P<token>\w+)', views.add_site, name='api-add-site'),
    url(r'^add_url/(?P<token>\w+)', views.add_site, name='api-add-site'),
    url(r'^add_site/?$', views.add_site_authed, name='api-add-site-authed'),
    url(r'^add_url/?$', views.add_site_authed, name='api-add-site-authed'),
    url(r'^check_share_on_site/(?P<token>\w+)', views.check_share_on_site, name='api-check-share-on-site'),
    url(r'^share_story/(?P<token>\w+)', views.share_story, name='api-share-story'),
    url(r'^save_story/(?P<token>\w+)', views.save_story, name='api-save-story'),
    url(r'^share_story/?$', views.share_story),
    url(r'^save_story/?$', views.save_story),
    url(r'^ip_addresses/?$', views.ip_addresses),
]
