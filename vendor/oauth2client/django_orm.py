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

"""OAuth 2.0 utilities for Django.

Utilities for using OAuth 2.0 in conjunction with
the Django datastore.
"""

__author__ = "jcgregorio@google.com (Joe Gregorio)"

import base64
import pickle

import oauth2client
from django.db import models
from oauth2client.client import Storage as BaseStorage


class CredentialsField(models.Field):
    def __init__(self, *args, **kwargs):
        if "null" not in kwargs:
            kwargs["null"] = True
        super(CredentialsField, self).__init__(*args, **kwargs)

    def get_internal_type(self):
        return "TextField"

    def from_db_value(self, value, expression, connection):
        if value is None:
            return value
        return pickle.loads(base64.b64decode(value))

    def to_python(self, value):
        if value is None:
            return None
        if isinstance(value, oauth2client.client.Credentials):
            return value
        return pickle.loads(base64.b64decode(value))

    def get_db_prep_value(self, value, connection, prepared=False):
        if value is None:
            return None
        return base64.b64encode(pickle.dumps(value))

    def deconstruct(self):
        name, path, args, kwargs = super().deconstruct()
        del kwargs["null"]
        return name, path, args, kwargs


class FlowField(models.Field):
    def __init__(self, *args, **kwargs):
        if "null" not in kwargs:
            kwargs["null"] = True
        super(FlowField, self).__init__(*args, **kwargs)

    def get_internal_type(self):
        return "TextField"

    def to_python(self, value):
        if value is None:
            return None
        if isinstance(value, oauth2client.client.Flow):
            return value
        return pickle.loads(base64.b64decode(value))

    def from_db_value(self, value, expression, connection):
        if value is None:
            return None
        return base64.b64encode(pickle.dumps(value))

    def get_db_prep_value(self, value, connection, prepared=False):
        if value is None:
            return None
        return base64.b64encode(pickle.dumps(value))

    def deconstruct(self):
        name, path, args, kwargs = super().deconstruct()
        del kwargs["null"]
        return name, path, args, kwargs


class Storage(BaseStorage):
    """Store and retrieve a single credential to and from
    the datastore.

    This Storage helper presumes the Credentials
    have been stored as a CredenialsField
    on a db model class.
    """

    def __init__(self, model_class, key_name, key_value, property_name):
        """Constructor for Storage.

        Args:
          model: db.Model, model class
          key_name: string, key name for the entity that has the credentials
          key_value: string, key value for the entity that has the credentials
          property_name: string, name of the property that is an CredentialsProperty
        """
        self.model_class = model_class
        self.key_name = key_name
        self.key_value = key_value
        self.property_name = property_name

    def locked_get(self):
        """Retrieve Credential from datastore.

        Returns:
          oauth2client.Credentials
        """
        credential = None

        query = {self.key_name: self.key_value}
        entities = self.model_class.objects.filter(**query)
        if len(entities) > 0:
            credential = getattr(entities[0], self.property_name)
            if credential and hasattr(credential, "set_store"):
                credential.set_store(self)
        return credential

    def locked_put(self, credentials):
        """Write a Credentials to the datastore.

        Args:
          credentials: Credentials, the credentials to store.
        """
        args = {self.key_name: self.key_value}
        entity = self.model_class(**args)
        setattr(entity, self.property_name, credentials)
        entity.save()

    def locked_delete(self):
        """Delete Credentials from the datastore."""

        query = {self.key_name: self.key_value}
        entities = self.model_class.objects.filter(**query).delete()
