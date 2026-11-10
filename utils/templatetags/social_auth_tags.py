"""Shared provider buttons for the login, signup, and welcome templates."""

from django import template

from apps.profile.web_social_auth import available_providers

register = template.Library()


@register.inclusion_tag("accounts/social_buttons.html", takes_context=True)
def social_signin_buttons(context):
    request = context["request"]
    return dict(
        providers=available_providers(),
        csrf_token=context.get("csrf_token"),
        MEDIA_URL=context.get("MEDIA_URL", "/media/"),
        next=context.get("next") or request.GET.get("next", ""),
        referrer=context.get("referrer", ""),
        gift_code=context.get("gift_code", ""),
        last_provider=request.COOKIES.get("nb_last_social_provider", ""),
    )
