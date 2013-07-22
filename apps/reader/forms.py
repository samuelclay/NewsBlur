# -*- encoding: utf-8 -*-
import datetime
from django import forms
from django.utils.translation import ugettext_lazy as _
from django.contrib.auth.models import User
from django.contrib.auth import authenticate
from django.db.models import Q
from django.conf import settings
from apps.reader.models import Feature
from apps.profile.tasks import EmailNewUser
from apps.social.models import MActivity
from apps.profile.models import blank_authenticate, RNewUserQueue
from utils import log as logging

class LoginForm(forms.Form):
    username = forms.CharField(label=_("用户名或邮件地址"), max_length=30,
                               widget=forms.TextInput(attrs={'tabindex': 1, 'class': 'NB-input'}),
                               error_messages={'required': '请输入用户名。'})
    password = forms.CharField(label=_("密码"),
                               widget=forms.PasswordInput(attrs={'tabindex': 2, 'class': 'NB-input'}),
                               required=True,
                               error_messages={'required': '请输入密码。'})

    def __init__(self, *args, **kwargs):
        self.user_cache = None
        super(LoginForm, self).__init__(*args, **kwargs)

    def clean(self):
        username = self.cleaned_data.get('username', '').lower()
        password = self.cleaned_data.get('password', '')
        
        user = User.objects.filter(Q(username__iexact=username) | Q(email=username))
        if user:
            user = user[0]
        if username and user:
            self.user_cache = authenticate(username=user.username, password=password)
            if self.user_cache is None:
                blank = blank_authenticate(user.username)
                if blank:
                    user.set_password(user.username)
                    user.save()
                self.user_cache = authenticate(username=user.username, password=user.username)
            if self.user_cache is None:
                email_user = User.objects.filter(email=username)
                if email_user:
                    email_user = email_user[0]
                    self.user_cache = authenticate(username=email_user.username, password=password)
                    if self.user_cache is None:
                        blank = blank_authenticate(email_user.username)
                        if blank:
                            email_user.set_password(email_user.username)
                            email_user.save()
                        self.user_cache = authenticate(username=email_user.username, password=email_user.username)
            if self.user_cache is None:
                logging.info(" ***> [%s] Bad Login" % username)
                raise forms.ValidationError(_("哎呀，登录失败！请重试。"))
        elif username and not user:
            raise forms.ValidationError(_("此用户名没有注册。请重试。"))
            
        return self.cleaned_data

    def get_user_id(self):
        if self.user_cache:
            return self.user_cache.id
        return None

    def get_user(self):
        return self.user_cache


class SignupForm(forms.Form):
    username = forms.RegexField(regex=r'^[a-zA-Z0-9]+$',
                                max_length=30,
                                widget=forms.TextInput(attrs={'class': 'NB-input'}),
                                label=_(u'用户名'),
                                error_messages={
                                    'required': '请输入用户名。', 
                                    'invalid': "用户名只能包含字母或数字。"
                                })
    email = forms.EmailField(widget=forms.TextInput(attrs={'maxlength': 75, 'class': 'NB-input'}),
                             label=_(u'邮件地址'),
                             required=True,
                             error_messages={'required': '请输入邮件地址。'})
    password = forms.CharField(widget=forms.PasswordInput(attrs={'class': 'NB-input'}),
                               label=_(u'密码'),
                               required=True,
                               error_messages={'required': '请输入密码。'})
    
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
        password = self.cleaned_data.get('password', '')
        email = self.cleaned_data.get('email', None)
        if email:
            email_exists = User.objects.filter(email__iexact=email).count()
            if email_exists:
                raise forms.ValidationError(_(u'此邮件地址已经被使用。'))
        exists = User.objects.filter(username__iexact=username).count()
        if exists:
            user_auth = authenticate(username=username, password=password)
            if not user_auth:
                raise forms.ValidationError(_(u'此用户名已经被使用。'))
        return self.cleaned_data
        
    def save(self, profile_callback=None):
        username = self.cleaned_data['username']
        password = self.cleaned_data['password']

        email = self.cleaned_data.get('email', None)
        if email:
            email_exists = User.objects.filter(email__iexact=email).count()
            if email_exists:
                raise forms.ValidationError(_(u'此邮件地址已经被使用。'))

        exists = User.objects.filter(username__iexact=username).count()
        if exists:
            user_auth = authenticate(username=username, password=password)
            if not user_auth:
                raise forms.ValidationError(_(u'此用户名已经被使用。'))
            else:
                return user_auth
        
        if not password:
            password = username
            
        new_user = User(username=username)
        new_user.set_password(password)
        new_user.is_active = False
        new_user.email = email
        new_user.save()
        new_user = authenticate(username=username,
                                password=password)
        
        MActivity.new_signup(user_id=new_user.pk)
        
        RNewUserQueue.add_user(new_user.pk)
        
        if new_user.email:
            EmailNewUser.delay(user_id=new_user.pk)
        
        if getattr(settings, 'AUTO_PREMIUM_NEW_USERS', False):
            new_user.profile.activate_premium()
        elif getattr(settings, 'AUTO_ENABLE_NEW_USERS', False):
            new_user.profile.activate_free()
        
        return new_user

class FeatureForm(forms.Form):
    description = forms.CharField(required=True)
    
    def save(self):
        feature = Feature(description=self.cleaned_data['description'],
                          date=datetime.datetime.utcnow() + datetime.timedelta(minutes=1))
        feature.save()
        return feature
