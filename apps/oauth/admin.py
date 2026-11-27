from django.contrib import admin

from apps.oauth.models import ApplicationExemption


@admin.register(ApplicationExemption)
class ApplicationExemptionAdmin(admin.ModelAdmin):
    """Adding a row exempts the application from its owner's Premium Pro requirement (apps/oauth/access.py);
    deleting it removes the exemption."""

    list_display = ("application", "owner", "created")
    list_select_related = ("application__user",)
    raw_id_fields = ("application",)
    search_fields = ("application__name", "application__user__username")

    def owner(self, exemption):
        # First-party clients have no owner; the admin shows its empty value for None.
        user = exemption.application.user
        return user.username if user else None
