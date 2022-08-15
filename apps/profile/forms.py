import re
import requests
from django import forms
from vendor.zebra.forms import StripePaymentForm
from django.utils.safestring import mark_safe
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from apps.profile.models import change_password, blank_authenticate, MGiftCode, MCustomStyling
from apps.social.models import MSocialProfile

PLANS = [
    ("newsblur-premium-36", mark_safe("$36 / year <span class='NB-small'>($3/month)</span>")),
    ("newsblur-premium-archive", mark_safe("$99 / year <span class='NB-small'>(~$8/month)</span>")),
    ("newsblur-premium-pro", mark_safe("$299 / year <span class='NB-small'>(~$25/month)</span>")),
]

class HorizRadioRenderer(forms.RadioSelect):
    """ this overrides widget method to put radio buttons horizontally
        instead of vertically.
    """
    def render(self, name, value, attrs=None, renderer=None):
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
    plan = forms.ChoiceField(required=False, widget=forms.RadioSelect,
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
            user_auth = blank_authenticate(username=self.user.username)
        
        if not user_auth:
            raise forms.ValidationError('Your password doesn\'t match.')

        return self.cleaned_data['password']

    def clean_confirm(self):
        if self.cleaned_data.get('confirm', "").lower() != "delete":
            raise forms.ValidationError('Please type "DELETE" to confirm deletion.')

        return self.cleaned_data['confirm']

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

        return self.cleaned_data['email']

class ForgotPasswordReturnForm(forms.Form):
    password = forms.CharField(widget=forms.PasswordInput(),
                               label="Your new password",
                               required=False)

class AccountSettingsForm(forms.Form):
    use_required_attribute = False
    username = forms.RegexField(regex=r'^\w+$',
                                max_length=30,
                                widget=forms.TextInput(attrs={'class': 'NB-input'}),
                                label='username',
                                required=False,
                                error_messages={
                                    'invalid': "Your username may only contain letters and numbers."
                                })
    email = forms.EmailField(widget=forms.TextInput(attrs={'maxlength': 75, 'class': 'NB-input'}),
                             label='email address',
                             required=True,
                             error_messages={'required': 'Please enter an email.'})
    new_password = forms.CharField(widget=forms.PasswordInput(attrs={'class': 'NB-input'}),
                                   label='password',
                                   required=False)
                                   # error_messages={'required': 'Please enter a password.'})
    old_password = forms.CharField(widget=forms.PasswordInput(attrs={'class': 'NB-input'}),
                                   label='password',
                                   required=False)
    custom_js = forms.CharField(widget=forms.TextInput(attrs={'class': 'NB-input'}),
                                   label='custom_js',
                                   required=False)
    custom_css = forms.CharField(widget=forms.TextInput(attrs={'class': 'NB-input'}),
                                   label='custom_css',
                                   required=False)
    
    def __init__(self, user, *args, **kwargs):
        self.user = user
        super(AccountSettingsForm, self).__init__(*args, **kwargs)
        
    def clean_username(self):
        username = self.cleaned_data['username']
        return username

    def clean_password(self):
        if not self.cleaned_data['password']:
            return ""
        return self.cleaned_data['password']
            
    def clean_email(self):
        return self.cleaned_data['email']
    
    def clean(self):
        username = self.cleaned_data.get('username', '')
        new_password = self.cleaned_data.get('new_password', '')
        old_password = self.cleaned_data.get('old_password', '')
        email = self.cleaned_data.get('email', None)
        
        if username and self.user.username != username:
            try:
                User.objects.get(username__iexact=username)
            except User.DoesNotExist:
                pass
            else:
                raise forms.ValidationError("This username is already taken. Try something different.")
        
        if self.user.email != email:
            if email and User.objects.filter(email__iexact=email).count():
                raise forms.ValidationError("This email is already being used by another account. Try something different.")
        
        if old_password or new_password:
            code = change_password(self.user, old_password, new_password, only_check=True)
            if code <= 0:
                raise forms.ValidationError("Your old password is incorrect.")    

        return self.cleaned_data
        
    def save(self, profile_callback=None):
        username = self.cleaned_data['username']
        new_password = self.cleaned_data.get('new_password', None)
        old_password = self.cleaned_data.get('old_password', None)
        email = self.cleaned_data.get('email', None)
        custom_css = self.cleaned_data.get('custom_css', None)
        custom_js = self.cleaned_data.get('custom_js', None)
        
        if username and self.user.username != username:
            change_password(self.user, self.user.username, username)
            self.user.username = username
            self.user.save()
            social_profile = MSocialProfile.get_user(self.user.pk)
            social_profile.username = username
            social_profile.save()

        
        self.user.profile.update_email(email)
        
        if old_password or new_password:
            change_password(self.user, old_password, new_password)
        
        MCustomStyling.save_user(self.user.pk, custom_css, custom_js)
        
class RedeemCodeForm(forms.Form):
    use_required_attribute = False
    gift_code = forms.CharField(widget=forms.TextInput(),
                               label="Gift code",
                               required=True)
    
    def clean_gift_code(self):
        gift_code = self.cleaned_data['gift_code']
        
        gift_code = re.sub(r'[^a-zA-Z0-9]', '', gift_code).lower()

        if len(gift_code) != 12:
            raise forms.ValidationError('Your gift code should be 12 characters long.')
        
        newsblur_gift_code = MGiftCode.objects.filter(gift_code__iexact=gift_code)

        if newsblur_gift_code:
            # Native gift codes
            newsblur_gift_code = newsblur_gift_code[0]
            return newsblur_gift_code.gift_code
        else:
            # Thinkup / Good Web Bundle
            req = requests.get('https://www.thinkup.com/join/api/bundle/', params={'code': gift_code})
            response = req.json()
        
            is_valid = response.get('is_valid', None)
            if is_valid:
                return gift_code
            elif is_valid == False:
                raise forms.ValidationError('Your gift code is invalid. Check it for errors.')
            elif response.get('error', None):
                raise forms.ValidationError('Your gift code is invalid, says the server: %s' % response['error'])
        
        return gift_code
