from django.conf.urls import url

from apps.team import views

urlpatterns = [
    url(r"^$", views.load_team, name="team-load"),
    url(r"^create/?$", views.create_team, name="team-create"),
    url(r"^rename/?$", views.rename_team, name="team-rename"),
    url(r"^invite/?$", views.invite, name="team-invite"),
    url(r"^revoke_invite/?$", views.revoke_invite, name="team-revoke-invite"),
    url(r"^join_link/?$", views.create_join_link, name="team-join-link"),
    url(r"^revoke_join_link/?$", views.revoke_join_link, name="team-revoke-join-link"),
    url(r"^invite_preview/?$", views.invite_preview, name="team-invite-preview"),
    url(r"^accept_invite/?$", views.accept_invite, name="team-accept-invite"),
    url(r"^change_role/?$", views.change_role, name="team-change-role"),
    url(r"^remove_member/?$", views.remove_member, name="team-remove-member"),
    url(r"^leave/?$", views.leave_team, name="team-leave"),
    url(r"^transfer_ownership/?$", views.transfer_ownership, name="team-transfer-ownership"),
    url(r"^cancel_transfer/?$", views.cancel_transfer, name="team-cancel-transfer"),
    url(r"^decline_transfer/?$", views.decline_transfer, name="team-decline-transfer"),
    url(r"^accept_transfer/?$", views.accept_transfer, name="team-accept-transfer"),
    url(r"^activity/?$", views.activity, name="team-activity"),
    url(r"^paypal_plan/?$", views.paypal_plan, name="team-paypal-plan"),
    url(r"^app_store_purchase/?$", views.app_store_purchase, name="team-app-store-purchase"),
    url(r"^play_purchase/?$", views.play_purchase, name="team-play-purchase"),
    url(r"^contact/?$", views.contact, name="team-contact"),
    url(r"^staff/?$", views.staff_team, name="team-staff"),
    url(r"^staff/seat_limit/?$", views.staff_seat_limit, name="team-staff-seat-limit"),
    url(r"^staff/plan/?$", views.staff_plan, name="team-staff-plan"),
    url(r"^staff/comp/?$", views.staff_comp, name="team-staff-comp"),
    url(r"^staff/end_comp/?$", views.staff_end_comp, name="team-staff-end-comp"),
]
