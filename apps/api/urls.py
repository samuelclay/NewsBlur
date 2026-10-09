from django.conf.urls import url

from apps.api import social_auth, views

urlpatterns = [
    url(
        r"^social/delete_password_account/?$",
        social_auth.delete_password_account,
        name="social-delete-password-account",
    ),
    url(r"^social/account/?$", social_auth.account, name="social-account"),
    url(r"^social/delete_account/?$", social_auth.delete_account, name="social-delete-account"),
    url(r"^social/start/?$", social_auth.start, name="social-start"),
    url(r"^social/apple/callback/?$", social_auth.apple_callback, name="social-apple-callback"),
    url(r"^social/apple/?$", social_auth.apple, name="social-apple"),
    url(r"^social/google/callback/?$", social_auth.google_callback, name="social-google-callback"),
    url(r"^social/complete/?$", social_auth.complete, name="social-complete"),
    url(r"^logout", views.logout, name="api-logout"),
    url(r"^login", views.login, name="api-login"),
    url(r"^signup", views.signup, name="api-signup"),
    url(r"^add_site_load_script/(?P<token>\w+)", views.add_site_load_script, name="api-add-site-load-script"),
    url(r"^add_site/(?P<token>\w+)", views.add_site, name="api-add-site"),
    url(r"^add_url/(?P<token>\w+)", views.add_site, name="api-add-site"),
    url(r"^add_site/?$", views.add_site_authed, name="api-add-site-authed"),
    url(r"^add_url/?$", views.add_site_authed, name="api-add-site-authed"),
    url(r"^check_share_on_site/(?P<token>\w+)", views.check_share_on_site, name="api-check-share-on-site"),
    url(r"^share_story/(?P<token>\w+)", views.share_story, name="api-share-story"),
    url(r"^save_story/(?P<token>\w+)", views.save_story, name="api-save-story"),
    url(r"^share_story/?$", views.share_story),
    url(r"^save_story/?$", views.save_story),
    url(r"^ip_addresses/?$", views.ip_addresses),
]
