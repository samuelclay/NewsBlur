from django.http import JsonResponse
from django.utils.cache import patch_vary_headers
from oauth2_provider.middleware import OAuth2TokenMiddleware
from oauth2_provider.models import get_access_token_model
from oauthlib.oauth2 import InvalidClientError

from apps.mcp.validators import RFC8252OAuth2Validator
from apps.oauth.access import application_is_active
from apps.oauth.applications import owner_subscription_error


class InactiveApplication(Exception):
    pass


class ProApplicationValidator(RFC8252OAuth2Validator):
    def _load_application(self, client_id, request):
        application = super()._load_application(client_id, request)
        if application and not application_is_active(application):
            raise InvalidClientError(description=owner_subscription_error())
        return application

    def _load_access_token(self, token):
        # Join the owner in oauth2_provider's normal token lookup, including for legacy tokens.
        access_token = (
            get_access_token_model()
            .objects.select_related("application__user__profile", "user")
            .filter(token=token)
            .first()
        )
        if (
            access_token
            and not access_token.is_expired()
            and not application_is_active(access_token.application)
        ):
            raise InactiveApplication()
        return access_token


class ProApplicationMiddleware(OAuth2TokenMiddleware):
    def __call__(self, request):
        try:
            return super().__call__(request)
        except InactiveApplication:
            response = JsonResponse(
                {"error": "invalid_client", "error_description": owner_subscription_error()}, status=403
            )
            response["Cache-Control"] = "no-store"
            patch_vary_headers(response, ("Authorization",))
            return response
