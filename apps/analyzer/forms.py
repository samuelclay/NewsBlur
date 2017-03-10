import re
import requests
from django import forms
from vendor.zebra.forms import StripePaymentForm
from django.utils.safestring import mark_safe
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from apps.profile.models import change_password, blank_authenticate, MGiftCode
from apps.social.models import MSocialProfile

class PopularityQueryForm(forms.Form):
    email = forms.CharField(widget=forms.TextInput(),
                               label="Your email address",
                               required=False)
    query = forms.CharField(widget=forms.TextInput(),
                               label="Keywords",
                               required=False)

    def __init__(self, *args, **kwargs):
        super(PopularityQueryForm, self).__init__(*args, **kwargs)
    
    def clean_email(self):
        if not self.cleaned_data['email']:
            raise forms.ValidationError('Please enter in an email address.')

        return self.cleaned_data['email']
    
    def clean_query(self):
        if not self.cleaned_data['query']:
            raise forms.ValidationError('Please enter in a keyword search query.')

        return self.cleaned_data['query']
