from django.urls import re_path
from django.views.decorators.csrf import csrf_protect
from oauth2_provider import views
from oauth2_provider.urls import base_urlpatterns, oidc_urlpatterns

from apps.oauth import applications

app_name = "oauth2_provider"
session_required = applications.browser_session_required

urlpatterns = (
    base_urlpatterns
    + oidc_urlpatterns
    + [
        re_path(r"^applications/register/?$", applications.register_application, name="register"),
        re_path(r"^applications/preview/?$", applications.preview_application),
        re_path(r"^applications/usage/?$", applications.owned_applications),
        re_path(r"^applications/$", session_required(views.ApplicationList.as_view()), name="list"),
        re_path(
            r"^applications/(?P<pk>\d+)/$", session_required(views.ApplicationDetail.as_view()), name="detail"
        ),
        re_path(r"^applications/(?P<pk>\d+)/update/?$", applications.edit_application, name="update"),
        re_path(
            r"^applications/(?P<pk>\d+)/delete/$",
            session_required(csrf_protect(views.ApplicationDelete.as_view())),
            name="delete",
        ),
        re_path(
            r"^authorized_tokens/$",
            session_required(views.AuthorizedTokensListView.as_view()),
            name="authorized-token-list",
        ),
        re_path(
            r"^authorized_tokens/(?P<pk>\d+)/delete/$",
            session_required(csrf_protect(views.AuthorizedTokenDeleteView.as_view())),
            name="authorized-token-delete",
        ),
    ]
)
