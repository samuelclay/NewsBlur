import datetime
from django import forms
from django.utils.translation import ugettext_lazy as _
from django.contrib.auth.models import User
from django.contrib.auth import authenticate
from django.db.models import Q
from apps.reader.models import Feature
from utils import log as logging

class LoginForm(forms.Form):
    username = forms.CharField(label=_("Username or Email"), max_length=30,
                               widget=forms.TextInput(attrs={'tabindex': 1}),
                               error_messages={'required': 'Please enter a username.'})
    password = forms.CharField(label=_("Password"),
                               widget=forms.PasswordInput(attrs={'tabindex': 2}),
                               required=False)    
                               # error_messages={'required': 'Please enter a password.'})

    def __init__(self, *args, **kwargs):
        self.user_cache = None
        super(LoginForm, self).__init__(*args, **kwargs)

    def clean(self):
        username = self.cleaned_data.get('username', '').lower()
        password = self.cleaned_data.get('password', '')
        
        user = User.objects.filter(Q(username__iexact=username) | Q(email=username))
        if username and user:
            self.user_cache = authenticate(username=user[0].username, password=password)
            if self.user_cache is None:
                email_username = User.objects.filter(email=username)
                if email_username:
                    self.user_cache = authenticate(username=email_username[0].username, password=password)
                if self.user_cache is None:
                    # logging.info(" ***> [%s] Bad Login: TRYING JK-LESS PASSWORD" % username)
                    jkless_password = password.replace('j', '').replace('k', '')
                    self.user_cache = authenticate(username=username, password=jkless_password)
                    if self.user_cache is None:
                        logging.info(" ***> [%s] Bad Login" % username)
                        raise forms.ValidationError(_("Whoopsy-daisy. Try again."))
                    else:
                        # Supreme fuck-up. Accidentally removed the letters J and K from
                        # all user passwords. Re-save with correct password.
                        logging.info(" ***> [%s] FIXING JK-LESS PASSWORD" % username)
                        self.user_cache.set_password(password)
                        self.user_cache.save()
                elif not self.user_cache.is_active:
                    raise forms.ValidationError(_("This account is inactive."))
        elif username and not user:
            raise forms.ValidationError(_("That username is not registered. Create an account with it instead."))
            
        return self.cleaned_data

    def get_user_id(self):
        if self.user_cache:
            return self.user_cache.id
        return None

    def get_user(self):
        return self.user_cache


class SignupForm(forms.Form):
    username = forms.RegexField(regex=r'^\w+$',
                                max_length=30,
                                widget=forms.TextInput(),
                                label=_(u'username'),
                                error_messages={
                                    'required': 'Please enter a username.', 
                                    'invalid': "Your username may only contain letters and numbers."
                                })
    email = forms.EmailField(widget=forms.TextInput(attrs=dict(maxlength=75)),
                             label=_(u'email address'),
                             required=False)  
                             # error_messages={'required': 'Please enter your email.'})
    password = forms.CharField(widget=forms.PasswordInput(),
                               label=_(u'password'),
                               required=False)
                               # error_messages={'required': 'Please enter a password.'})
    
    def clean_username(self):
        username = self.cleaned_data['username']
        return username

    def clean_password(self):
        if not self.cleaned_data['password']:
            return ""
        return self.cleaned_data['password']
            
    def clean_email(self):
        if not self.cleaned_data['email']:
            return ""
        return self.cleaned_data['email']
    
    def clean(self):
        username = self.cleaned_data['username']
        password = self.cleaned_data['password']
        exists = User.objects.filter(username__iexact=username).count()
        if exists:
            user_auth = authenticate(username=username, password=password)
            if not user_auth:
                raise forms.ValidationError(_(u'Someone is already using that username.'))
        return self.cleaned_data
        
    def save(self, profile_callback=None):
        username = self.cleaned_data['username']
        password = self.cleaned_data['password']

        exists = User.objects.filter(username__iexact=username).count()
        if exists:
            user_auth = authenticate(username=username, password=password)
            if not user_auth:
                raise forms.ValidationError(_(u'Someone is already using that username.'))
            else:
                return user_auth
            
        new_user = User(username=username)
        new_user.set_password(password)
        new_user.is_active = True
        new_user.email = self.cleaned_data['email']
        new_user.save()
        new_user = authenticate(username=username,
                                password=password)
        new_user.profile.send_new_user_email()
        
        return new_user

class FeatureForm(forms.Form):
    description = forms.CharField(required=True)
    
    def save(self):
        feature = Feature(description=self.cleaned_data['description'],
                          date=datetime.datetime.utcnow() + datetime.timedelta(minutes=1))
        feature.save()
        return feature