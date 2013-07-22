# -*- encoding: utf-8 -*-
from django import forms
from vendor.zebra.forms import StripePaymentForm
from django.utils.safestring import mark_safe
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from apps.profile.models import change_password, blank_authenticate
from apps.social.models import MSocialProfile

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
                             label='邮件地址',
                             required=False)
    plan = forms.ChoiceField(required=False, widget=forms.RadioSelect(renderer=HorizRadioRenderer),
                             choices=PLANS, label='Plan')


class DeleteAccountForm(forms.Form):
    password = forms.CharField(widget=forms.PasswordInput(),
                               label="确认密码",
                               required=False)
    confirm = forms.CharField(label="请输入“Delete”以确认",
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
            raise forms.ValidationError('你的密码不匹配。')

        return self.cleaned_data

    def clean_confirm(self):
        if self.cleaned_data.get('confirm', "").lower() != "delete":
            raise forms.ValidationError('请输入“Delete”以确认删除。')

        return self.cleaned_data

class ForgotPasswordForm(forms.Form):
    email = forms.CharField(widget=forms.TextInput(),
                               label="你的邮件地址",
                               required=False)

    def __init__(self, *args, **kwargs):
        super(ForgotPasswordForm, self).__init__(*args, **kwargs)
    
    def clean_email(self):
        if not self.cleaned_data['email']:
            raise forms.ValidationError('请输入邮件地址。')
        try:
            User.objects.get(email__iexact=self.cleaned_data['email'])
        except User.MultipleObjectsReturned:
            pass
        except User.DoesNotExist:
            raise forms.ValidationError('没有用户使用此邮件地址。')

        return self.cleaned_data

class ForgotPasswordReturnForm(forms.Form):
    password = forms.CharField(widget=forms.PasswordInput(),
                               label="你的新密码",
                               required=True)

class AccountSettingsForm(forms.Form):
    username = forms.RegexField(regex=r'^[a-zA-Z0-9]+$',
                                max_length=30,
                                widget=forms.TextInput(attrs={'class': 'NB-input'}),
                                label='用户名',
                                required=False,
                                error_messages={
                                    'invalid': "用户名只能包含字母或数字"
                                })
    email = forms.EmailField(widget=forms.TextInput(attrs={'maxlength': 75, 'class': 'NB-input'}),
                             label='邮件地址',
                             required=True,
                             error_messages={'required': '请输入邮件地址。'})
    new_password = forms.CharField(widget=forms.PasswordInput(attrs={'class': 'NB-input'}),
                                   label='密码',
                                   required=False,
                                   error_messages={'required': '请输入密码。'})
    old_password = forms.CharField(widget=forms.PasswordInput(attrs={'class': 'NB-input'}),
                                   label='密码',
                                   required=False,
                                   error_messages={'required': '请输入密码。'})
    
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
                raise forms.ValidationError("此用户名已被使用，请尝试其他用户名。")
        
        if self.user.email != email:
            if email and User.objects.filter(email__iexact=email).count():
                raise forms.ValidationError("此邮件地址已被其他帐户使用，请尝试其他邮件地址。")
        
        if old_password or new_password:
            code = change_password(self.user, old_password, new_password, only_check=True)
            if code <= 0:
                raise forms.ValidationError("你的旧密码不正确。")    

        return self.cleaned_data
        
    def save(self, profile_callback=None):
        username = self.cleaned_data['username']
        new_password = self.cleaned_data.get('new_password', None)
        old_password = self.cleaned_data.get('old_password', None)
        email = self.cleaned_data.get('email', None)
        
        if username and self.user.username != username:
            change_password(self.user, self.user.username, username)
            self.user.username = username
            self.user.save()
            social_profile = MSocialProfile.get_user(self.user.pk)
            social_profile.username = username
            social_profile.save()

        
        if self.user.email != email:
            self.user.email = email
            self.user.save()
        
        if old_password or new_password:
            change_password(self.user, old_password, new_password)
        

        
