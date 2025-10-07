import datetime

from django import forms
from django.conf import settings
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.db.models import Q
from django.utils.translation import gettext_lazy as _
from dns.resolver import (
    NXDOMAIN,
    NoAnswer,
    NoNameservers,
    NoResolverConfiguration,
    query,
)

from apps.profile.models import RNewUserQueue, blank_authenticate
from apps.profile.tasks import EmailNewUser
from apps.reader.models import Feature
from apps.social.models import MActivity
from utils import log as logging


class LoginForm(forms.Form):
    username = forms.CharField(
        label=_("Username or Email"),
        max_length=30,
        widget=forms.TextInput(attrs={"tabindex": 1, "class": "NB-input"}),
        error_messages={"required": "Please enter a username."},
    )
    password = forms.CharField(
        label=_("Password"),
        widget=forms.PasswordInput(attrs={"tabindex": 2, "class": "NB-input"}),
        required=False,
    )
    # error_messages={'required': 'Please enter a password.'})
    add = forms.CharField(required=False, widget=forms.HiddenInput())

    def __init__(self, *args, **kwargs):
        self.user_cache = None
        super(LoginForm, self).__init__(*args, **kwargs)

    def clean(self):
        username = self.cleaned_data.get("username", "").lower()
        password = self.cleaned_data.get("password", "")

        if "@" in username:
            user = User.objects.filter(email=username)
            if not user:
                user = User.objects.filter(email__iexact=username)
        else:
            user = User.objects.filter(username=username)
            if not user:
                user = User.objects.filter(username__iexact=username)
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
                email_user = User.objects.filter(email__iexact=username)
                if email_user:
                    email_user = email_user[0]
                    self.user_cache = authenticate(username=email_user.username, password=password)
                    if self.user_cache is None:
                        blank = blank_authenticate(email_user.username)
                        if blank:
                            email_user.set_password(email_user.username)
                            email_user.save()
                        self.user_cache = authenticate(
                            username=email_user.username, password=email_user.username
                        )
            if self.user_cache is None:
                logging.info(" ***> [%s] Bad Login" % username)
                raise forms.ValidationError(_("Whoopsy-daisy, wrong password. Try again."))
        elif username and not user:
            raise forms.ValidationError(_("That username is not registered. Please try again."))

        return self.cleaned_data

    def get_user_id(self):
        if self.user_cache:
            return self.user_cache.id
        return None

    def get_user(self):
        return self.user_cache


class SignupForm(forms.Form):
    use_required_attribute = False

    username = forms.RegexField(
        regex=r"^\w+$",
        max_length=30,
        widget=forms.TextInput(attrs={"class": "NB-input"}),
        label=_("Username"),
        error_messages={
            "required": "Please enter a username.",
            "invalid": "Your username may only contain letters and numbers.",
        },
    )
    email = forms.EmailField(
        widget=forms.TextInput(attrs={"maxlength": 75, "class": "NB-input"}),
        label=_("Email"),
        required=True,
        error_messages={"required": "Please enter an email."},
    )
    password = forms.CharField(
        widget=forms.PasswordInput(
            attrs={"class": "NB-input"},
            render_value=True,
        ),
        label=_("Password"),
        required=False,
    )
    # error_messages={'required': 'Please enter a password.'})

    def clean_username(self):
        username = self.cleaned_data["username"]
        return username

    def clean_password(self):
        if not self.cleaned_data["password"]:
            return ""
        return self.cleaned_data["password"]

    def clean_email(self):
        email = self.cleaned_data.get("email", None)
        if email:
            email_exists = User.objects.filter(email__iexact=email).count()
            if email_exists:
                raise forms.ValidationError(_("Someone is already using that email address."))
            if any(
                [
                    banned in email
                    for banned in ["mailwire24", "mailbox9", "scintillamail", "bluemailboxes", "devmailing"]
                ]
            ):
                logging.info(
                    " ***> [%s] Spammer signup banned: %s/%s"
                    % (
                        self.cleaned_data.get("username", None),
                        self.cleaned_data.get("password", None),
                        email,
                    )
                )
                raise forms.ValidationError("Seriously, fuck off spammer.")
            try:
                domain = email.rsplit("@", 1)[-1]
                if not query(domain, "MX"):
                    raise forms.ValidationError("Sorry, that email is invalid.")
            except (NXDOMAIN, NoNameservers, NoAnswer):
                raise forms.ValidationError("Sorry, that email is invalid.")
            except NoResolverConfiguration as e:
                logging.info(f" ***> ~FRFailed to check spamminess of domain: ~FY{domain} ~FR{e}")
                pass
        return self.cleaned_data["email"]

    def clean(self):
        username = self.cleaned_data.get("username", "")
        password = self.cleaned_data.get("password", "")
        email = self.cleaned_data.get("email", None)

        exists = User.objects.filter(username__iexact=username).count()
        if exists:
            user_auth = authenticate(username=username, password=password)
            if not user_auth:
                raise forms.ValidationError(_("Someone is already using that username."))

        return self.cleaned_data

    def save(self, profile_callback=None):
        username = self.cleaned_data["username"]
        password = self.cleaned_data["password"]
        email = self.cleaned_data["email"]

        exists = User.objects.filter(username__iexact=username).count()
        if exists:
            user_auth = authenticate(username=username, password=password)
            if not user_auth:
                raise forms.ValidationError(_("Someone is already using that username."))
            else:
                return user_auth

        if not password:
            password = username

        new_user = User(username=username)
        new_user.set_password(password)
        if not getattr(settings, "AUTO_ENABLE_NEW_USERS", True):
            new_user.is_active = False
        new_user.email = email
        new_user.last_login = datetime.datetime.now()
        new_user.save()
        new_user = authenticate(username=username, password=password)
        new_user = User.objects.get(username=username)
        MActivity.new_signup(user_id=new_user.pk)

        RNewUserQueue.add_user(new_user.pk)

        if new_user.email:
            EmailNewUser.delay(user_id=new_user.pk)

        if getattr(settings, "AUTO_PREMIUM_NEW_USERS", False):
            new_user.profile.activate_premium()
        elif getattr(settings, "AUTO_ENABLE_NEW_USERS", False):
            new_user.profile.activate_free()

        return new_user


class FeatureForm(forms.Form):
    use_required_attribute = False

    description = forms.CharField(required=True)

    def save(self):
        feature = Feature(
            description=self.cleaned_data["description"],
            date=datetime.datetime.utcnow() + datetime.timedelta(minutes=1),
        )
        feature.save()
        return feature
