#!/usr/bin/env python
#
# Copyright 2010 Facebook
# Copyright 2015 Mobolic
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

"""Python client library for the Facebook Platform.

This client library is designed to support the Graph API and the
official Facebook JavaScript SDK, which is the canonical way to
implement Facebook authentication. Read more about the Graph API at
https://developers.facebook.com/docs/graph-api.

"""

import hashlib
import hmac
import binascii
import base64
import requests
import json
import re

try:
    from urllib.parse import parse_qs, urlencode, urlparse
except ImportError:
    from urllib.parse import parse_qs, urlparse
    from urllib.parse import urlencode



__version__ = "3.2.0-pre"

FACEBOOK_GRAPH_URL = "https://graph.facebook.com/"
FACEBOOK_WWW_URL = "https://www.facebook.com/"
FACEBOOK_OAUTH_DIALOG_PATH = "dialog/oauth?"
VALID_API_VERSIONS = ["2.8", "2.9", "2.10", "2.11", "2.12", "3.0", "3.1"]
VALID_SEARCH_TYPES = ["place", "placetopic"]


class GraphAPI(object):
    """A client for the Facebook Graph API.

    https://developers.facebook.com/docs/graph-api

    The Graph API is made up of the objects in Facebook (e.g., people,
    pages, events, photos) and the connections between them (e.g.,
    friends, photo tags, and event RSVPs). This client provides access
    to those primitive types in a generic way. For example, given an
    OAuth access token, this will fetch the profile of the active user
    and the list of the user's friends:

       graph = facebook.GraphAPI(access_token)
       user = graph.get_object("me")
       friends = graph.get_connections(user["id"], "friends")

    You can see a list of all of the objects and connections supported
    by the API at https://developers.facebook.com/docs/graph-api/reference/.

    You can obtain an access token via OAuth or by using the Facebook
    JavaScript SDK. See
    https://developers.facebook.com/docs/facebook-login for details.

    If you are using the JavaScript SDK, you can use the
    get_user_from_cookie() method below to get the OAuth access token
    for the active user from the cookie saved by the SDK.

    """

    def __init__(
        self,
        access_token=None,
        timeout=None,
        version=None,
        proxies=None,
        session=None,
    ):
        # The default version is only used if the version kwarg does not exist.
        default_version = VALID_API_VERSIONS[0]

        self.access_token = access_token
        self.timeout = timeout
        self.proxies = proxies
        self.session = session or requests.Session()

        if version:
            version_regex = re.compile("^\d\.\d{1,2}$")
            match = version_regex.search(str(version))
            if match is not None:
                if str(version) not in VALID_API_VERSIONS:
                    raise GraphAPIError(
                        "Valid API versions are "
                        + str(VALID_API_VERSIONS).strip("[]")
                    )
                else:
                    self.version = "v" + str(version)
            else:
                raise GraphAPIError(
                    "Version number should be in the"
                    " following format: #.# (e.g. 2.0)."
                )
        else:
            self.version = "v" + default_version

    def get_permissions(self, user_id):
        """Fetches the permissions object from the graph."""
        response = self.request(
            "{0}/{1}/permissions".format(self.version, user_id), {}
        )["data"]
        return {x["permission"] for x in response if x["status"] == "granted"}

    def get_object(self, id, **args):
        """Fetches the given object from the graph."""
        return self.request("{0}/{1}".format(self.version, id), args)

    def get_objects(self, ids, **args):
        """Fetches all of the given object from the graph.

        We return a map from ID to object. If any of the IDs are
        invalid, we raise an exception.
        """
        args["ids"] = ",".join(ids)
        return self.request(self.version + "/", args)

    def search(self, type, **args):
        """https://developers.facebook.com/docs/places/search"""
        if type not in VALID_SEARCH_TYPES:
            raise GraphAPIError(
                "Valid types are: %s" % ", ".join(VALID_SEARCH_TYPES)
            )

        args["type"] = type
        return self.request(self.version + "/search/", args)

    def get_connections(self, id, connection_name, **args):
        """Fetches the connections for given object."""
        return self.request(
            "{0}/{1}/{2}".format(self.version, id, connection_name), args
        )

    def get_all_connections(self, id, connection_name, **args):
        """Get all pages from a get_connections call

        This will iterate over all pages returned by a get_connections call
        and yield the individual items.
        """
        while True:
            page = self.get_connections(id, connection_name, **args)
            for post in page["data"]:
                yield post
            next = page.get("paging", {}).get("next")
            if not next:
                return
            args = parse_qs(urlparse(next).query)
            del args["access_token"]

    def put_object(self, parent_object, connection_name, **data):
        """Writes the given object to the graph, connected to the given parent.

        For example,

            graph.put_object("me", "feed", message="Hello, world")

        writes "Hello, world" to the active user's wall. Likewise, this
        will comment on the first post of the active user's feed:

            feed = graph.get_connections("me", "feed")
            post = feed["data"][0]
            graph.put_object(post["id"], "comments", message="First!")

        Certain operations require extended permissions. See
        https://developers.facebook.com/docs/facebook-login/permissions
        for details about permissions.

        """
        assert self.access_token, "Write operations require an access token"
        return self.request(
            "{0}/{1}/{2}".format(self.version, parent_object, connection_name),
            post_args=data,
            method="POST",
        )

    def put_comment(self, object_id, message):
        """Writes the given comment on the given post."""
        return self.put_object(object_id, "comments", message=message)

    def put_like(self, object_id):
        """Likes the given post."""
        return self.put_object(object_id, "likes")

    def delete_object(self, id):
        """Deletes the object with the given ID from the graph."""
        return self.request(
            "{0}/{1}".format(self.version, id), method="DELETE"
        )

    def delete_request(self, user_id, request_id):
        """Deletes the Request with the given ID for the given user."""
        return self.request(
            "{0}_{1}".format(request_id, user_id), method="DELETE"
        )

    def put_photo(self, image, album_path="me/photos", **kwargs):
        """
        Upload an image using multipart/form-data.

        image - A file object representing the image to be uploaded.
        album_path - A path representing where the image should be uploaded.

        """
        return self.request(
            "{0}/{1}".format(self.version, album_path),
            post_args=kwargs,
            files={"source": image},
            method="POST",
        )

    def get_version(self):
        """Fetches the current version number of the Graph API being used."""
        args = {"access_token": self.access_token}
        try:
            response = self.session.request(
                "GET",
                FACEBOOK_GRAPH_URL + self.version + "/me",
                params=args,
                timeout=self.timeout,
                proxies=self.proxies,
            )
        except requests.HTTPError as e:
            response = json.loads(e.read())
            raise GraphAPIError(response)

        try:
            headers = response.headers
            version = headers["facebook-api-version"].replace("v", "")
            return str(version)
        except Exception:
            raise GraphAPIError("API version number not available")

    def request(
        self, path, args=None, post_args=None, files=None, method=None
    ):
        """Fetches the given path in the Graph API.

        We translate args to a valid query string. If post_args is
        given, we send a POST request to the given path with the given
        arguments.

        """
        if args is None:
            args = dict()
        if post_args is not None:
            method = "POST"

        # Add `access_token` to post_args or args if it has not already been
        # included.
        if self.access_token:
            # If post_args exists, we assume that args either does not exists
            # or it does not need `access_token`.
            if post_args and "access_token" not in post_args:
                post_args["access_token"] = self.access_token
            elif "access_token" not in args:
                args["access_token"] = self.access_token

        try:
            response = self.session.request(
                method or "GET",
                FACEBOOK_GRAPH_URL + path,
                timeout=self.timeout,
                params=args,
                data=post_args,
                proxies=self.proxies,
                files=files,
            )
        except requests.HTTPError as e:
            response = json.loads(e.read())
            raise GraphAPIError(response)

        headers = response.headers
        if "json" in headers["content-type"]:
            result = response.json()
        elif "image/" in headers["content-type"]:
            mimetype = headers["content-type"]
            result = {
                "data": response.content,
                "mime-type": mimetype,
                "url": response.url,
            }
        elif "access_token" in parse_qs(response.text):
            query_str = parse_qs(response.text)
            if "access_token" in query_str:
                result = {"access_token": query_str["access_token"][0]}
                if "expires" in query_str:
                    result["expires"] = query_str["expires"][0]
            else:
                raise GraphAPIError(response.json())
        else:
            raise GraphAPIError("Maintype was not text, image, or querystring")

        if result and isinstance(result, dict) and result.get("error"):
            raise GraphAPIError(result)
        return result

    def get_app_access_token(self, app_id, app_secret, offline=False):
        """
        Get the application's access token as a string.
        If offline=True, use the concatenated app ID and secret
        instead of making an API call.
        <https://developers.facebook.com/docs/facebook-login/
        access-tokens#apptokens>
        """
        if offline:
            return "{0}|{1}".format(app_id, app_secret)
        else:
            args = {
                "grant_type": "client_credentials",
                "client_id": app_id,
                "client_secret": app_secret,
            }

            return self.request(
                "{0}/oauth/access_token".format(self.version), args=args
            )["access_token"]

    def get_access_token_from_code(
        self, code, redirect_uri, app_id, app_secret
    ):
        """Get an access token from the "code" returned from an OAuth dialog.

        Returns a dict containing the user-specific access token and its
        expiration date (if applicable).

        """
        args = {
            "code": code,
            "redirect_uri": redirect_uri,
            "client_id": app_id,
            "client_secret": app_secret,
        }

        return self.request(
            "{0}/oauth/access_token".format(self.version), args
        )

    def extend_access_token(self, app_id, app_secret):
        """
        Extends the expiration time of a valid OAuth access token. See
        <https://developers.facebook.com/docs/facebook-login/access-tokens/
        expiration-and-extension>

        """
        args = {
            "client_id": app_id,
            "client_secret": app_secret,
            "grant_type": "fb_exchange_token",
            "fb_exchange_token": self.access_token,
        }

        return self.request(
            "{0}/oauth/access_token".format(self.version), args=args
        )

    def debug_access_token(self, token, app_id, app_secret):
        """
        Gets information about a user access token issued by an app. See
        <https://developers.facebook.com/docs/facebook-login/
        access-tokens/debugging-and-error-handling>

        We can generate the app access token by concatenating the app
        id and secret: <https://developers.facebook.com/docs/
        facebook-login/access-tokens#apptokens>

        """
        args = {
            "input_token": token,
            "access_token": "{0}|{1}".format(app_id, app_secret),
        }
        return self.request(self.version + "/" + "debug_token", args=args)

    def get_auth_url(self, app_id, canvas_url, perms=None, **kwargs):
        """Build a URL to create an OAuth dialog."""
        url = "{0}{1}/{2}".format(
            FACEBOOK_WWW_URL, self.version, FACEBOOK_OAUTH_DIALOG_PATH
        )

        args = {"client_id": app_id, "redirect_uri": canvas_url}
        if perms:
            args["scope"] = ",".join(perms)
        args.update(kwargs)
        return url + urlencode(args)


class GraphAPIError(Exception):
    def __init__(self, result):
        self.result = result
        self.code = None
        try:
            self.type = result["error_code"]
        except (KeyError, TypeError):
            self.type = ""

        # OAuth 2.0 Draft 10
        try:
            self.message = result["error_description"]
        except (KeyError, TypeError):
            # OAuth 2.0 Draft 00
            try:
                self.message = result["error"]["message"]
                self.code = result["error"].get("code")
                if not self.type:
                    self.type = result["error"].get("type", "")
            except (KeyError, TypeError):
                # REST server style
                try:
                    self.message = result["error_msg"]
                except (KeyError, TypeError):
                    self.message = result

        Exception.__init__(self, self.message)


def get_user_from_cookie(cookies, app_id, app_secret):
    """Parses the cookie set by the official Facebook JavaScript SDK.

    cookies should be a dictionary-like object mapping cookie names to
    cookie values.

    If the user is logged in via Facebook, we return a dictionary with
    the keys "uid" and "access_token". The former is the user's
    Facebook ID, and the latter can be used to make authenticated
    requests to the Graph API. If the user is not logged in, we
    return None.

    Read more about Facebook authentication at
    https://developers.facebook.com/docs/facebook-login.

    """
    cookie = cookies.get("fbsr_" + app_id, "")
    if not cookie:
        return None
    parsed_request = parse_signed_request(cookie, app_secret)
    if not parsed_request:
        return None
    try:
        result = GraphAPI().get_access_token_from_code(
            parsed_request["code"], "", app_id, app_secret
        )
    except GraphAPIError:
        return None
    result["uid"] = parsed_request["user_id"]
    return result


def parse_signed_request(signed_request, app_secret):
    """ Return dictionary with signed request data.

    We return a dictionary containing the information in the
    signed_request. This includes a user_id if the user has authorised
    your application, as well as any information requested.

    If the signed_request is malformed or corrupted, False is returned.

    """
    try:
        encoded_sig, payload = list(map(str, signed_request.split(".", 1)))

        sig = base64.urlsafe_b64decode(
            encoded_sig + "=" * ((4 - len(encoded_sig) % 4) % 4)
        )
        data = base64.urlsafe_b64decode(
            payload + "=" * ((4 - len(payload) % 4) % 4)
        )
    except IndexError:
        # Signed request was malformed.
        return False
    except TypeError:
        # Signed request had a corrupted payload.
        return False
    except binascii.Error:
        # Signed request had a corrupted payload.
        return False

    data = json.loads(data.decode("ascii"))
    if data.get("algorithm", "").upper() != "HMAC-SHA256":
        return False

    # HMAC can only handle ascii (byte) strings
    # https://bugs.python.org/issue5285
    app_secret = app_secret.encode("ascii")
    payload = payload.encode("ascii")

    expected_sig = hmac.new(
        app_secret, msg=payload, digestmod=hashlib.sha256
    ).digest()
    if sig != expected_sig:
        return False

    return data