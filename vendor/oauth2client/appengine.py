# Copyright (C) 2010 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Utilities for Google App Engine

Utilities for making it easier to use OAuth 2.0 on Google App Engine.
"""

__author__ = "jcgregorio@google.com (Joe Gregorio)"

import base64
import logging
import pickle
import time

import httplib2
from google.appengine.api import app_identity, users
from google.appengine.ext import db, webapp
from google.appengine.ext.webapp.util import login_required, run_wsgi_app
from oauth2client import util
from oauth2client.anyjson import simplejson
from oauth2client.client import (
    AccessTokenRefreshError,
    AssertionCredentials,
    Credentials,
    Flow,
    OAuth2WebServerFlow,
    Storage,
)

from . import clientsecrets

logger = logging.getLogger(__name__)

OAUTH2CLIENT_NAMESPACE = "oauth2client#ns"


class InvalidClientSecretsError(Exception):
    """The client_secrets.json file is malformed or missing required fields."""

    pass


class AppAssertionCredentials(AssertionCredentials):
    """Credentials object for App Engine Assertion Grants

    This object will allow an App Engine application to identify itself to Google
    and other OAuth 2.0 servers that can verify assertions. It can be used for
    the purpose of accessing data stored under an account assigned to the App
    Engine application itself.

    This credential does not require a flow to instantiate because it represents
    a two legged flow, and therefore has all of the required information to
    generate and refresh its own access tokens.
    """

    @util.positional(2)
    def __init__(self, scope, **kwargs):
        """Constructor for AppAssertionCredentials

        Args:
          scope: string or list of strings, scope(s) of the credentials being
            requested.
        """
        if type(scope) is list:
            scope = " ".join(scope)
        self.scope = scope

        super(AppAssertionCredentials, self).__init__("ignored")  # assertion_type is ignore in this subclass.

    @classmethod
    def from_json(cls, json):
        data = simplejson.loads(json)
        return AppAssertionCredentials(data["scope"])

    def _refresh(self, http_request):
        """Refreshes the access_token.

        Since the underlying App Engine app_identity implementation does its own
        caching we can skip all the storage hoops and just to a refresh using the
        API.

        Args:
          http_request: callable, a callable that matches the method signature of
            httplib2.Http.request, used to make the refresh request.

        Raises:
          AccessTokenRefreshError: When the refresh fails.
        """
        try:
            (token, _) = app_identity.get_access_token(self.scope)
        except app_identity.Error as e:
            raise AccessTokenRefreshError(str(e))
        self.access_token = token


class FlowProperty(db.Property):
    """App Engine datastore Property for Flow.

    Utility property that allows easy storage and retreival of an
    oauth2client.Flow"""

    # Tell what the user type is.
    data_type = Flow

    # For writing to datastore.
    def get_value_for_datastore(self, model_instance):
        flow = super(FlowProperty, self).get_value_for_datastore(model_instance)
        return db.Blob(pickle.dumps(flow))

    # For reading from datastore.
    def make_value_from_datastore(self, value):
        if value is None:
            return None
        return pickle.loads(value)

    def validate(self, value):
        if value is not None and not isinstance(value, Flow):
            raise db.BadValueError(
                "Property %s must be convertible " "to a FlowThreeLegged instance (%s)" % (self.name, value)
            )
        return super(FlowProperty, self).validate(value)

    def empty(self, value):
        return not value


class CredentialsProperty(db.Property):
    """App Engine datastore Property for Credentials.

    Utility property that allows easy storage and retrieval of
    oath2client.Credentials
    """

    # Tell what the user type is.
    data_type = Credentials

    # For writing to datastore.
    def get_value_for_datastore(self, model_instance):
        logger.info("get: Got type " + str(type(model_instance)))
        cred = super(CredentialsProperty, self).get_value_for_datastore(model_instance)
        if cred is None:
            cred = ""
        else:
            cred = cred.to_json()
        return db.Blob(cred)

    # For reading from datastore.
    def make_value_from_datastore(self, value):
        logger.info("make: Got type " + str(type(value)))
        if value is None:
            return None
        if len(value) == 0:
            return None
        try:
            credentials = Credentials.new_from_json(value)
        except ValueError:
            credentials = None
        return credentials

    def validate(self, value):
        value = super(CredentialsProperty, self).validate(value)
        logger.info("validate: Got type " + str(type(value)))
        if value is not None and not isinstance(value, Credentials):
            raise db.BadValueError(
                "Property %s must be convertible " "to a Credentials instance (%s)" % (self.name, value)
            )
        # if value is not None and not isinstance(value, Credentials):
        #  return None
        return value


class StorageByKeyName(Storage):
    """Store and retrieve a single credential to and from
    the App Engine datastore.

    This Storage helper presumes the Credentials
    have been stored as a CredenialsProperty
    on a datastore model class, and that entities
    are stored by key_name.
    """

    @util.positional(4)
    def __init__(self, model, key_name, property_name, cache=None):
        """Constructor for Storage.

        Args:
          model: db.Model, model class
          key_name: string, key name for the entity that has the credentials
          property_name: string, name of the property that is a CredentialsProperty
          cache: memcache, a write-through cache to put in front of the datastore
        """
        self._model = model
        self._key_name = key_name
        self._property_name = property_name
        self._cache = cache

    def locked_get(self):
        """Retrieve Credential from datastore.

        Returns:
          oauth2client.Credentials
        """
        if self._cache:
            json = self._cache.get(self._key_name)
            if json:
                return Credentials.new_from_json(json)

        credential = None
        entity = self._model.get_by_key_name(self._key_name)
        if entity is not None:
            credential = getattr(entity, self._property_name)
            if credential and hasattr(credential, "set_store"):
                credential.set_store(self)
                if self._cache:
                    self._cache.set(self._key_name, credential.to_json())

        return credential

    def locked_put(self, credentials):
        """Write a Credentials to the datastore.

        Args:
          credentials: Credentials, the credentials to store.
        """
        entity = self._model.get_or_insert(self._key_name)
        setattr(entity, self._property_name, credentials)
        entity.put()
        if self._cache:
            self._cache.set(self._key_name, credentials.to_json())

    def locked_delete(self):
        """Delete Credential from datastore."""

        if self._cache:
            self._cache.delete(self._key_name)

        entity = self._model.get_by_key_name(self._key_name)
        if entity is not None:
            entity.delete()


class CredentialsModel(db.Model):
    """Storage for OAuth 2.0 Credentials

    Storage of the model is keyed by the user.user_id().
    """

    credentials = CredentialsProperty()


class OAuth2Decorator(object):
    """Utility for making OAuth 2.0 easier.

    Instantiate and then use with oauth_required or oauth_aware
    as decorators on webapp.RequestHandler methods.

    Example:

      decorator = OAuth2Decorator(
          client_id='837...ent.com',
          client_secret='Qh...wwI',
          scope='https://www.googleapis.com/auth/plus')


      class MainHandler(webapp.RequestHandler):

        @decorator.oauth_required
        def get(self):
          http = decorator.http()
          # http is authorized with the user's Credentials and can be used
          # in API calls

    """

    @util.positional(4)
    def __init__(
        self,
        client_id,
        client_secret,
        scope,
        auth_uri="https://accounts.google.com/o/oauth2/auth",
        token_uri="https://accounts.google.com/o/oauth2/token",
        user_agent=None,
        message=None,
        callback_path="/oauth2callback",
        **kwargs
    ):
        """Constructor for OAuth2Decorator

        Args:
          client_id: string, client identifier.
          client_secret: string client secret.
          scope: string or list of strings, scope(s) of the credentials being
            requested.
          auth_uri: string, URI for authorization endpoint. For convenience
            defaults to Google's endpoints but any OAuth 2.0 provider can be used.
          token_uri: string, URI for token endpoint. For convenience
            defaults to Google's endpoints but any OAuth 2.0 provider can be used.
          user_agent: string, User agent of your application, default to None.
          message: Message to display if there are problems with the OAuth 2.0
            configuration. The message may contain HTML and will be presented on the
            web interface for any method that uses the decorator.
          callback_path: string, The absolute path to use as the callback URI. Note
            that this must match up with the URI given when registering the
            application in the APIs Console.
          **kwargs: dict, Keyword arguments are be passed along as kwargs to the
            OAuth2WebServerFlow constructor.
        """
        self.flow = None
        self.credentials = None
        self._client_id = client_id
        self._client_secret = client_secret
        self._scope = scope
        self._auth_uri = auth_uri
        self._token_uri = token_uri
        self._user_agent = user_agent
        self._kwargs = kwargs
        self._message = message
        self._in_error = False
        self._callback_path = callback_path

    def _display_error_message(self, request_handler):
        request_handler.response.out.write("<html><body>")
        request_handler.response.out.write(self._message)
        request_handler.response.out.write("</body></html>")

    def oauth_required(self, method):
        """Decorator that starts the OAuth 2.0 dance.

        Starts the OAuth dance for the logged in user if they haven't already
        granted access for this application.

        Args:
          method: callable, to be decorated method of a webapp.RequestHandler
            instance.
        """

        def check_oauth(request_handler, *args, **kwargs):
            if self._in_error:
                self._display_error_message(request_handler)
                return

            user = users.get_current_user()
            # Don't use @login_decorator as this could be used in a POST request.
            if not user:
                request_handler.redirect(users.create_login_url(request_handler.request.uri))
                return

            self._create_flow(request_handler)

            # Store the request URI in 'state' so we can use it later
            self.flow.params["state"] = request_handler.request.url
            self.credentials = StorageByKeyName(CredentialsModel, user.user_id(), "credentials").get()

            if not self.has_credentials():
                return request_handler.redirect(self.authorize_url())
            try:
                method(request_handler, *args, **kwargs)
            except AccessTokenRefreshError:
                return request_handler.redirect(self.authorize_url())

        return check_oauth

    def _create_flow(self, request_handler):
        """Create the Flow object.

        The Flow is calculated lazily since we don't know where this app is
        running until it receives a request, at which point redirect_uri can be
        calculated and then the Flow object can be constructed.

        Args:
          request_handler: webapp.RequestHandler, the request handler.
        """
        if self.flow is None:
            redirect_uri = request_handler.request.relative_url(
                self._callback_path
            )  # Usually /oauth2callback
            self.flow = OAuth2WebServerFlow(
                self._client_id,
                self._client_secret,
                self._scope,
                redirect_uri=redirect_uri,
                user_agent=self._user_agent,
                auth_uri=self._auth_uri,
                token_uri=self._token_uri,
                **self._kwargs
            )

    def oauth_aware(self, method):
        """Decorator that sets up for OAuth 2.0 dance, but doesn't do it.

        Does all the setup for the OAuth dance, but doesn't initiate it.
        This decorator is useful if you want to create a page that knows
        whether or not the user has granted access to this application.
        From within a method decorated with @oauth_aware the has_credentials()
        and authorize_url() methods can be called.

        Args:
          method: callable, to be decorated method of a webapp.RequestHandler
            instance.
        """

        def setup_oauth(request_handler, *args, **kwargs):
            if self._in_error:
                self._display_error_message(request_handler)
                return

            user = users.get_current_user()
            # Don't use @login_decorator as this could be used in a POST request.
            if not user:
                request_handler.redirect(users.create_login_url(request_handler.request.uri))
                return

            self._create_flow(request_handler)

            self.flow.params["state"] = request_handler.request.url
            self.credentials = StorageByKeyName(CredentialsModel, user.user_id(), "credentials").get()
            method(request_handler, *args, **kwargs)

        return setup_oauth

    def has_credentials(self):
        """True if for the logged in user there are valid access Credentials.

        Must only be called from with a webapp.RequestHandler subclassed method
        that had been decorated with either @oauth_required or @oauth_aware.
        """
        return self.credentials is not None and not self.credentials.invalid

    def authorize_url(self):
        """Returns the URL to start the OAuth dance.

        Must only be called from with a webapp.RequestHandler subclassed method
        that had been decorated with either @oauth_required or @oauth_aware.
        """
        url = self.flow.step1_get_authorize_url()
        return str(url)

    def http(self):
        """Returns an authorized http instance.

        Must only be called from within an @oauth_required decorated method, or
        from within an @oauth_aware decorated method where has_credentials()
        returns True.
        """
        return self.credentials.authorize(httplib2.Http())

    @property
    def callback_path(self):
        """The absolute path where the callback will occur.

        Note this is the absolute path, not the absolute URI, that will be
        calculated by the decorator at runtime. See callback_handler() for how this
        should be used.

        Returns:
          The callback path as a string.
        """
        return self._callback_path

    def callback_handler(self):
        """RequestHandler for the OAuth 2.0 redirect callback.

        Usage:
           app = webapp.WSGIApplication([
             ('/index', MyIndexHandler),
             ...,
             (decorator.callback_path, decorator.callback_handler())
           ])

        Returns:
          A webapp.RequestHandler that handles the redirect back from the
          server during the OAuth 2.0 dance.
        """
        decorator = self

        class OAuth2Handler(webapp.RequestHandler):
            """Handler for the redirect_uri of the OAuth 2.0 dance."""

            @login_required
            def get(self):
                error = self.request.get("error")
                if error:
                    errormsg = self.request.get("error_description", error)
                    self.response.out.write("The authorization request failed: %s" % errormsg)
                else:
                    user = users.get_current_user()
                    decorator._create_flow(self)
                    credentials = decorator.flow.step2_exchange(self.request.params)
                    StorageByKeyName(CredentialsModel, user.user_id(), "credentials").put(credentials)
                    self.redirect(str(self.request.get("state")))

        return OAuth2Handler

    def callback_application(self):
        """WSGI application for handling the OAuth 2.0 redirect callback.

        If you need finer grained control use `callback_handler` which returns just
        the webapp.RequestHandler.

        Returns:
          A webapp.WSGIApplication that handles the redirect back from the
          server during the OAuth 2.0 dance.
        """
        return webapp.WSGIApplication([(self.callback_path, self.callback_handler())])


class OAuth2DecoratorFromClientSecrets(OAuth2Decorator):
    """An OAuth2Decorator that builds from a clientsecrets file.

    Uses a clientsecrets file as the source for all the information when
    constructing an OAuth2Decorator.

    Example:

      decorator = OAuth2DecoratorFromClientSecrets(
        os.path.join(os.path.dirname(__file__), 'client_secrets.json')
        scope='https://www.googleapis.com/auth/plus')


      class MainHandler(webapp.RequestHandler):

        @decorator.oauth_required
        def get(self):
          http = decorator.http()
          # http is authorized with the user's Credentials and can be used
          # in API calls
    """

    @util.positional(3)
    def __init__(self, filename, scope, message=None, cache=None):
        """Constructor

        Args:
          filename: string, File name of client secrets.
          scope: string or list of strings, scope(s) of the credentials being
            requested.
          message: string, A friendly string to display to the user if the
            clientsecrets file is missing or invalid. The message may contain HTML and
            will be presented on the web interface for any method that uses the
            decorator.
          cache: An optional cache service client that implements get() and set()
            methods. See clientsecrets.loadfile() for details.
        """
        try:
            client_type, client_info = clientsecrets.loadfile(filename, cache=cache)
            if client_type not in [clientsecrets.TYPE_WEB, clientsecrets.TYPE_INSTALLED]:
                raise InvalidClientSecretsError("OAuth2Decorator doesn't support this OAuth 2.0 flow.")
            super(OAuth2DecoratorFromClientSecrets, self).__init__(
                client_info["client_id"],
                client_info["client_secret"],
                scope,
                auth_uri=client_info["auth_uri"],
                token_uri=client_info["token_uri"],
                message=message,
            )
        except clientsecrets.InvalidClientSecretsError:
            self._in_error = True
        if message is not None:
            self._message = message
        else:
            self._message = "Please configure your application for OAuth 2.0"


@util.positional(2)
def oauth2decorator_from_clientsecrets(filename, scope, message=None, cache=None):
    """Creates an OAuth2Decorator populated from a clientsecrets file.

    Args:
      filename: string, File name of client secrets.
      scope: string or list of strings, scope(s) of the credentials being
        requested.
      message: string, A friendly string to display to the user if the
        clientsecrets file is missing or invalid. The message may contain HTML and
        will be presented on the web interface for any method that uses the
        decorator.
      cache: An optional cache service client that implements get() and set()
        methods. See clientsecrets.loadfile() for details.

    Returns: An OAuth2Decorator

    """
    return OAuth2DecoratorFromClientSecrets(filename, scope, message=message, cache=cache)
