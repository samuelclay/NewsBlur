import re

import requests
from django import forms
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.utils.safestring import mark_safe
from django.utils.translation import gettext_lazy

from apps.profile.models import MGiftCode, blank_authenticate, change_password
from apps.social.models import MSocialProfile
from vendor.zebra.forms import StripePaymentForm


class PopularityQueryForm(forms.Form):
    email = forms.CharField(
        widget=forms.TextInput(), label=gettext_lazy("Your email address"), required=False
    )
    query = forms.CharField(widget=forms.TextInput(), label=gettext_lazy("Keywords"), required=False)

    def __init__(self, *args, **kwargs):
        super(PopularityQueryForm, self).__init__(*args, **kwargs)

    def clean_email(self):
        if not self.cleaned_data["email"]:
            raise forms.ValidationError(gettext_lazy("Please enter in an email address."))

        return self.cleaned_data["email"]

    def clean_query(self):
        if not self.cleaned_data["query"]:
            raise forms.ValidationError(gettext_lazy("Please enter in a keyword search query."))

        return self.cleaned_data["query"]
