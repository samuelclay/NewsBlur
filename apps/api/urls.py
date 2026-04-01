from django.urls import re_path

from apps.api import views

urlpatterns = [
    re_path(r"^logout", views.logout, name="api-logout"),
    re_path(r"^login", views.login, name="api-login"),
    re_path(r"^signup", views.signup, name="api-signup"),
    re_path(r"^add_site_load_script/(?P<token>\w+)", views.add_site_load_script, name="api-add-site-load-script"),
    re_path(r"^add_site/(?P<token>\w+)", views.add_site, name="api-add-site"),
    re_path(r"^add_url/(?P<token>\w+)", views.add_site, name="api-add-site"),
    re_path(r"^add_site/?$", views.add_site_authed, name="api-add-site-authed"),
    re_path(r"^add_url/?$", views.add_site_authed, name="api-add-site-authed"),
    re_path(r"^check_share_on_site/(?P<token>\w+)", views.check_share_on_site, name="api-check-share-on-site"),
    re_path(r"^share_story/(?P<token>\w+)", views.share_story, name="api-share-story"),
    re_path(r"^save_story/(?P<token>\w+)", views.save_story, name="api-save-story"),
    re_path(r"^share_story/?$", views.share_story),
    re_path(r"^save_story/?$", views.save_story),
    re_path(r"^ip_addresses/?$", views.ip_addresses),
]
