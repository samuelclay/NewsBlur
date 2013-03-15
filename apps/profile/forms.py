from django import forms
from vendor.zebra.forms import StripePaymentForm
from django.utils.safestring import mark_safe
from django.contrib.auth import authenticate
from django.contrib.auth.models import User

PLANS = [
    ("newsblur-premium-12", mark_safe("$12 / year <span class='NB-small'>($1/month)</span>")),
    ("newsblur-premium-24", mark_safe("$24 / year <span class='NB-small'>($2/month)</span>")),
    ("newsblur-premium-36", mark_safe("$36 / year <span class='NB-small'>($3/month)</span>")),
]

class HorizRadioRenderer(forms.RadioSelect.renderer):
    """ this overrides widget method to put radio buttons horizontally
        instead of vertically.
    """
    def render(self):
            """Outputs radios"""
            choices = '\n'.join(['%s\n' % w for w in self])
            return mark_safe('<div class="NB-stripe-plan-choice">%s</div>' % choices)

class StripePlusPaymentForm(StripePaymentForm):
    def __init__(self, *args, **kwargs):
        email = kwargs.pop('email')
        plan = kwargs.pop('plan', '')
        super(StripePlusPaymentForm, self).__init__(*args, **kwargs)
        self.fields['email'].initial = email
        if plan:
            self.fields['plan'].initial = plan

    email = forms.EmailField(widget=forms.TextInput(attrs=dict(maxlength=75)),
                             label='Email address',
                             required=False)
    plan = forms.ChoiceField(required=False, widget=forms.RadioSelect(renderer=HorizRadioRenderer),
                             choices=PLANS, label='Plan')


class DeleteAccountForm(forms.Form):
    password = forms.CharField(widget=forms.PasswordInput(),
                               label="Confirm your password",
                               required=False)
    confirm = forms.CharField(label="Type \"Delete\" to confirm",
                              widget=forms.TextInput(),
                              required=False)

    def __init__(self, *args, **kwargs):
        self.user = kwargs.pop('user')
        super(DeleteAccountForm, self).__init__(*args, **kwargs)
    
    def clean_password(self):
        user_auth = authenticate(username=self.user.username, 
                                 password=self.cleaned_data['password'])
        if not user_auth:
            raise forms.ValidationError('Your password doesn\'t match.')

        return self.cleaned_data

    def clean_confirm(self):
        if self.cleaned_data.get('confirm', "").lower() != "delete":
            raise forms.ValidationError('Please type "DELETE" to confirm deletion.')

        return self.cleaned_data

class ForgotPasswordForm(forms.Form):
    email = forms.CharField(widget=forms.TextInput(),
                               label="Your email address",
                               required=False)

    def __init__(self, *args, **kwargs):
        super(ForgotPasswordForm, self).__init__(*args, **kwargs)
    
    def clean_email(self):
        if not self.cleaned_data['email']:
            raise forms.ValidationError('Please enter in an email address.')
        try:
            User.objects.get(email__iexact=self.cleaned_data['email'])
        except User.MultipleObjectsReturned:
            pass
        except User.DoesNotExist:
            raise forms.ValidationError('No user has that email address.')

        return self.cleaned_data

class ForgotPasswordReturnForm(forms.Form):
    password = forms.CharField(widget=forms.PasswordInput(),
                               label="Your new password",
                               required=False)
