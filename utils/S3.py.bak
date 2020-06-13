#!/usr/bin/env python

#  This software code is made available "AS IS" without warranties of any
#  kind.  You may copy, display, modify and redistribute the software
#  code either by itself or as incorporated into your code; provided that
#  you do not remove any proprietary notices.  Your use of this software
#  code is at your own risk and you waive any claim against Amazon
#  Digital Services, Inc. or its affiliates with respect to your use of
#  this software code. (c) 2006-2007 Amazon Digital Services, Inc. or its
#  affiliates.

import base64
import hmac
import httplib
import re
import sha
import sys
import time
import urllib
import urlparse
import xml.sax

DEFAULT_HOST = 's3.amazonaws.com'
PORTS_BY_SECURITY = { True: 443, False: 80 }
METADATA_PREFIX = 'x-amz-meta-'
AMAZON_HEADER_PREFIX = 'x-amz-'

# generates the aws canonical string for the given parameters
def canonical_string(method, bucket="", key="", query_args={}, headers={}, expires=None):
    interesting_headers = {}
    for header_key in headers:
        lk = header_key.lower()
        if lk in ['content-md5', 'content-type', 'date'] or lk.startswith(AMAZON_HEADER_PREFIX):
            interesting_headers[lk] = headers[header_key].strip()

    # these keys get empty strings if they don't exist
    if not interesting_headers.has_key('content-type'):
        interesting_headers['content-type'] = ''
    if not interesting_headers.has_key('content-md5'):
        interesting_headers['content-md5'] = ''

    # just in case someone used this.  it's not necessary in this lib.
    if interesting_headers.has_key('x-amz-date'):
        interesting_headers['date'] = ''

    # if you're using expires for query string auth, then it trumps date
    # (and x-amz-date)
    if expires:
        interesting_headers['date'] = str(expires)

    sorted_header_keys = interesting_headers.keys()
    sorted_header_keys.sort()

    buf = "%s\n" % method
    for header_key in sorted_header_keys:
        if header_key.startswith(AMAZON_HEADER_PREFIX):
            buf += "%s:%s\n" % (header_key, interesting_headers[header_key])
        else:
            buf += "%s\n" % interesting_headers[header_key]

    # append the bucket if it exists
    if bucket != "":
        buf += "/%s" % bucket

    # add the key.  even if it doesn't exist, add the slash
    buf += "/%s" % urllib.quote_plus(key)

    # handle special query string arguments

    if query_args.has_key("acl"):
        buf += "?acl"
    elif query_args.has_key("torrent"):
        buf += "?torrent"
    elif query_args.has_key("logging"):
        buf += "?logging"
    elif query_args.has_key("location"):
        buf += "?location"

    return buf

# computes the base64'ed hmac-sha hash of the canonical string and the secret
# access key, optionally urlencoding the result
def encode(aws_secret_access_key, str, urlencode=False):
    b64_hmac = base64.encodestring(hmac.new(aws_secret_access_key, str, sha).digest()).strip()
    if urlencode:
        return urllib.quote_plus(b64_hmac)
    else:
        return b64_hmac

def merge_meta(headers, metadata):
    final_headers = headers.copy()
    for k in metadata.keys():
        final_headers[METADATA_PREFIX + k] = metadata[k]

    return final_headers

# builds the query arg string
def query_args_hash_to_string(query_args):
    query_string = ""
    pairs = []
    for k, v in query_args.items():
        piece = k
        if v != None:
            piece += "=%s" % urllib.quote_plus(str(v))
        pairs.append(piece)

    return '&'.join(pairs)


class CallingFormat:
    PATH = 1
    SUBDOMAIN = 2
    VANITY = 3

    def build_url_base(protocol, server, port, bucket, calling_format):
        url_base = '%s://' % protocol

        if bucket == '':
            url_base += server
        elif calling_format == CallingFormat.SUBDOMAIN:
            url_base += "%s.%s" % (bucket, server)
        elif calling_format == CallingFormat.VANITY:
            url_base += bucket
        else:
            url_base += server

        url_base += ":%s" % port

        if (bucket != '') and (calling_format == CallingFormat.PATH):
            url_base += "/%s" % bucket

        return url_base

    build_url_base = staticmethod(build_url_base)



class Location:
    DEFAULT = None
    EU = 'EU'



class AWSAuthConnection:
    def __init__(self, aws_access_key_id, aws_secret_access_key, is_secure=True,
            server=DEFAULT_HOST, port=None, calling_format=CallingFormat.SUBDOMAIN):

        if not port:
            port = PORTS_BY_SECURITY[is_secure]

        self.aws_access_key_id = aws_access_key_id
        self.aws_secret_access_key = aws_secret_access_key
        self.is_secure = is_secure
        self.server = server
        self.port = port
        self.calling_format = calling_format

    def create_bucket(self, bucket, headers={}):
        return Response(self._make_request('PUT', bucket, '', {}, headers))

    def create_located_bucket(self, bucket, location=Location.DEFAULT, headers={}):
        if location == Location.DEFAULT:
            body = ""
        else:
            body = "<CreateBucketConstraint><LocationConstraint>" + \
                   location + \
                   "</LocationConstraint></CreateBucketConstraint>"
        return Response(self._make_request('PUT', bucket, '', {}, headers, body))

    def check_bucket_exists(self, bucket):
        return self._make_request('HEAD', bucket, '', {}, {})

    def list_bucket(self, bucket, options={}, headers={}):
        return ListBucketResponse(self._make_request('GET', bucket, '', options, headers))

    def delete_bucket(self, bucket, headers={}):
        return Response(self._make_request('DELETE', bucket, '', {}, headers))

    def put(self, bucket, key, object, headers={}):
        if not isinstance(object, S3Object):
            object = S3Object(object)

        return Response(
                self._make_request(
                    'PUT',
                    bucket,
                    key,
                    {},
                    headers,
                    object.data,
                    object.metadata))

    def get(self, bucket, key, headers={}):
        return GetResponse(
                self._make_request('GET', bucket, key, {}, headers))

    def delete(self, bucket, key, headers={}):
        return Response(
                self._make_request('DELETE', bucket, key, {}, headers))

    def get_bucket_logging(self, bucket, headers={}):
        return GetResponse(self._make_request('GET', bucket, '', { 'logging': None }, headers))

    def put_bucket_logging(self, bucket, logging_xml_doc, headers={}):
        return Response(self._make_request('PUT', bucket, '', { 'logging': None }, headers, logging_xml_doc))

    def get_bucket_acl(self, bucket, headers={}):
        return self.get_acl(bucket, '', headers)

    def get_acl(self, bucket, key, headers={}):
        return GetResponse(
                self._make_request('GET', bucket, key, { 'acl': None }, headers))

    def put_bucket_acl(self, bucket, acl_xml_document, headers={}):
        return self.put_acl(bucket, '', acl_xml_document, headers)

    def put_acl(self, bucket, key, acl_xml_document, headers={}):
        return Response(
                self._make_request(
                    'PUT',
                    bucket,
                    key,
                    { 'acl': None },
                    headers,
                    acl_xml_document))

    def list_all_my_buckets(self, headers={}):
        return ListAllMyBucketsResponse(self._make_request('GET', '', '', {}, headers))

    def get_bucket_location(self, bucket):
        return LocationResponse(self._make_request('GET', bucket, '', {'location' : None}))

    # end public methods

    def _make_request(self, method, bucket='', key='', query_args={}, headers={}, data='', metadata={}):

        server = ''
        if bucket == '':
            server = self.server
        elif self.calling_format == CallingFormat.SUBDOMAIN:
            server = "%s.%s" % (bucket, self.server)
        elif self.calling_format == CallingFormat.VANITY:
            server = bucket
        else:
            server = self.server

        path = ''

        if (bucket != '') and (self.calling_format == CallingFormat.PATH):
            path += "/%s" % bucket

        # add the slash after the bucket regardless
        # the key will be appended if it is non-empty
        path += "/%s" % urllib.quote_plus(key)


        # build the path_argument string
        # add the ? in all cases since 
        # signature and credentials follow path args
        if len(query_args):
            path += "?" + query_args_hash_to_string(query_args)

        is_secure = self.is_secure
        host = "%s:%d" % (server, self.port)
        while True:
            if (is_secure):
                connection = httplib.HTTPSConnection(host)
            else:
                connection = httplib.HTTPConnection(host)

            final_headers = merge_meta(headers, metadata);
            # add auth header
            self._add_aws_auth_header(final_headers, method, bucket, key, query_args)

            connection.request(method, path, data, final_headers)
            resp = connection.getresponse()
            if resp.status < 300 or resp.status >= 400:
                return resp
            # handle redirect
            location = resp.getheader('location')
            if not location:
                return resp
            # (close connection)
            resp.read()
            scheme, host, path, params, query, fragment \
                    = urlparse.urlparse(location)
            if scheme == "http":    is_secure = True
            elif scheme == "https": is_secure = False
            else: raise invalidURL("Not http/https: " + location)
            if query: path += "?" + query
            # retry with redirect

    def _add_aws_auth_header(self, headers, method, bucket, key, query_args):
        if not headers.has_key('Date'):
            headers['Date'] = time.strftime("%a, %d %b %Y %X GMT", time.gmtime())

        c_string = canonical_string(method, bucket, key, query_args, headers)
        headers['Authorization'] = \
            "AWS %s:%s" % (self.aws_access_key_id, encode(self.aws_secret_access_key, c_string))


class QueryStringAuthGenerator:
    # by default, expire in 1 minute
    DEFAULT_EXPIRES_IN = 60

    def __init__(self, aws_access_key_id, aws_secret_access_key, is_secure=True,
                 server=DEFAULT_HOST, port=None, calling_format=CallingFormat.SUBDOMAIN):

        if not port:
            port = PORTS_BY_SECURITY[is_secure]

        self.aws_access_key_id = aws_access_key_id
        self.aws_secret_access_key = aws_secret_access_key
        if (is_secure):
            self.protocol = 'https'
        else:
            self.protocol = 'http'

        self.is_secure = is_secure
        self.server = server
        self.port = port
        self.calling_format = calling_format
        self.__expires_in = QueryStringAuthGenerator.DEFAULT_EXPIRES_IN
        self.__expires = None

        # for backwards compatibility with older versions
        self.server_name = "%s:%s" % (self.server, self.port)

    def set_expires_in(self, expires_in):
        self.__expires_in = expires_in
        self.__expires = None

    def set_expires(self, expires):
        self.__expires = expires
        self.__expires_in = None

    def create_bucket(self, bucket, headers={}):
        return self.generate_url('PUT', bucket, '', {}, headers)

    def list_bucket(self, bucket, options={}, headers={}):
        return self.generate_url('GET', bucket, '', options, headers)

    def delete_bucket(self, bucket, headers={}):
        return self.generate_url('DELETE', bucket, '', {}, headers)

    def put(self, bucket, key, object, headers={}):
        if not isinstance(object, S3Object):
            object = S3Object(object)

        return self.generate_url(
                'PUT',
                bucket,
                key,
                {},
                merge_meta(headers, object.metadata))

    def get(self, bucket, key, headers={}):
        return self.generate_url('GET', bucket, key, {}, headers)

    def delete(self, bucket, key, headers={}):
        return self.generate_url('DELETE', bucket, key, {}, headers)

    def get_bucket_logging(self, bucket, headers={}):
        return self.generate_url('GET', bucket, '', { 'logging': None }, headers)

    def put_bucket_logging(self, bucket, logging_xml_doc, headers={}):
        return self.generate_url('PUT', bucket, '', { 'logging': None }, headers)

    def get_bucket_acl(self, bucket, headers={}):
        return self.get_acl(bucket, '', headers)

    def get_acl(self, bucket, key='', headers={}):
        return self.generate_url('GET', bucket, key, { 'acl': None }, headers)

    def put_bucket_acl(self, bucket, acl_xml_document, headers={}):
        return self.put_acl(bucket, '', acl_xml_document, headers)

    # don't really care what the doc is here.
    def put_acl(self, bucket, key, acl_xml_document, headers={}):
        return self.generate_url('PUT', bucket, key, { 'acl': None }, headers)

    def list_all_my_buckets(self, headers={}):
        return self.generate_url('GET', '', '', {}, headers)

    def make_bare_url(self, bucket, key=''):
        full_url = self.generate_url(self, bucket, key)
        return full_url[:full_url.index('?')]

    def generate_url(self, method, bucket='', key='', query_args={}, headers={}):
        expires = 0
        if self.__expires_in != None:
            expires = int(time.time() + self.__expires_in)
        elif self.__expires != None:
            expires = int(self.__expires)
        else:
            raise "Invalid expires state"

        canonical_str = canonical_string(method, bucket, key, query_args, headers, expires)
        encoded_canonical = encode(self.aws_secret_access_key, canonical_str)

        url = CallingFormat.build_url_base(self.protocol, self.server, self.port, bucket, self.calling_format)

        url += "/%s" % urllib.quote_plus(key)

        query_args['Signature'] = encoded_canonical
        query_args['Expires'] = expires
        query_args['AWSAccessKeyId'] = self.aws_access_key_id

        url += "?%s" % query_args_hash_to_string(query_args)

        return url


class S3Object:
    def __init__(self, data, metadata={}):
        self.data = data
        self.metadata = metadata

class Owner:
    def __init__(self, id='', display_name=''):
        self.id = id
        self.display_name = display_name

class ListEntry:
    def __init__(self, key='', last_modified=None, etag='', size=0, storage_class='', owner=None):
        self.key = key
        self.last_modified = last_modified
        self.etag = etag
        self.size = size
        self.storage_class = storage_class
        self.owner = owner

class CommonPrefixEntry:
    def __init(self, prefix=''):
        self.prefix = prefix

class Bucket:
    def __init__(self, name='', creation_date=''):
        self.name = name
        self.creation_date = creation_date

class Response:
    def __init__(self, http_response):
        self.http_response = http_response
        # you have to do this read, even if you don't expect a body.
        # otherwise, the next request fails.
        self.body = http_response.read()
        if http_response.status >= 300 and self.body:
            self.message = self.body
        else:
            self.message = "%03d %s" % (http_response.status, http_response.reason)



class ListBucketResponse(Response):
    def __init__(self, http_response):
        Response.__init__(self, http_response)
        if http_response.status < 300:
            handler = ListBucketHandler()
            xml.sax.parseString(self.body, handler)
            self.entries = handler.entries
            self.common_prefixes = handler.common_prefixes
            self.name = handler.name
            self.marker = handler.marker
            self.prefix = handler.prefix
            self.is_truncated = handler.is_truncated
            self.delimiter = handler.delimiter
            self.max_keys = handler.max_keys
            self.next_marker = handler.next_marker
        else:
            self.entries = []

class ListAllMyBucketsResponse(Response):
    def __init__(self, http_response):
        Response.__init__(self, http_response)
        if http_response.status < 300: 
            handler = ListAllMyBucketsHandler()
            xml.sax.parseString(self.body, handler)
            self.entries = handler.entries
        else:
            self.entries = []

class GetResponse(Response):
    def __init__(self, http_response):
        Response.__init__(self, http_response)
        response_headers = http_response.msg   # older pythons don't have getheaders
        metadata = self.get_aws_metadata(response_headers)
        self.object = S3Object(self.body, metadata)

    def get_aws_metadata(self, headers):
        metadata = {}
        for hkey in headers.keys():
            if hkey.lower().startswith(METADATA_PREFIX):
                metadata[hkey[len(METADATA_PREFIX):]] = headers[hkey]
                del headers[hkey]

        return metadata

class LocationResponse(Response):
    def __init__(self, http_response):
        Response.__init__(self, http_response)
        if http_response.status < 300: 
            handler = LocationHandler()
            xml.sax.parseString(self.body, handler)
            self.location = handler.location

class ListBucketHandler(xml.sax.ContentHandler):
    def __init__(self):
        self.entries = []
        self.curr_entry = None
        self.curr_text = ''
        self.common_prefixes = []
        self.curr_common_prefix = None
        self.name = ''
        self.marker = ''
        self.prefix = ''
        self.is_truncated = False
        self.delimiter = ''
        self.max_keys = 0
        self.next_marker = ''
        self.is_echoed_prefix_set = False

    def startElement(self, name, attrs):
        if name == 'Contents':
            self.curr_entry = ListEntry()
        elif name == 'Owner':
            self.curr_entry.owner = Owner()
        elif name == 'CommonPrefixes':
            self.curr_common_prefix = CommonPrefixEntry()


    def endElement(self, name):
        if name == 'Contents':
            self.entries.append(self.curr_entry)
        elif name == 'CommonPrefixes':
            self.common_prefixes.append(self.curr_common_prefix)
        elif name == 'Key':
            self.curr_entry.key = self.curr_text
        elif name == 'LastModified':
            self.curr_entry.last_modified = self.curr_text
        elif name == 'ETag':
            self.curr_entry.etag = self.curr_text
        elif name == 'Size':
            self.curr_entry.size = int(self.curr_text)
        elif name == 'ID':
            self.curr_entry.owner.id = self.curr_text
        elif name == 'DisplayName':
            self.curr_entry.owner.display_name = self.curr_text
        elif name == 'StorageClass':
            self.curr_entry.storage_class = self.curr_text
        elif name == 'Name':
            self.name = self.curr_text
        elif name == 'Prefix' and self.is_echoed_prefix_set:
            self.curr_common_prefix.prefix = self.curr_text
        elif name == 'Prefix':
            self.prefix = self.curr_text
            self.is_echoed_prefix_set = True
        elif name == 'Marker':
            self.marker = self.curr_text
        elif name == 'IsTruncated':
            self.is_truncated = self.curr_text == 'true'
        elif name == 'Delimiter':
            self.delimiter = self.curr_text
        elif name == 'MaxKeys':
            self.max_keys = int(self.curr_text)
        elif name == 'NextMarker':
            self.next_marker = self.curr_text

        self.curr_text = ''

    def characters(self, content):
        self.curr_text += content


class ListAllMyBucketsHandler(xml.sax.ContentHandler):
    def __init__(self):
        self.entries = []
        self.curr_entry = None
        self.curr_text = ''

    def startElement(self, name, attrs):
        if name == 'Bucket':
            self.curr_entry = Bucket()

    def endElement(self, name):
        if name == 'Name':
            self.curr_entry.name = self.curr_text
        elif name == 'CreationDate':
            self.curr_entry.creation_date = self.curr_text
        elif name == 'Bucket':
            self.entries.append(self.curr_entry)

    def characters(self, content):
        self.curr_text = content


class LocationHandler(xml.sax.ContentHandler):
    def __init__(self):
        self.location = None
        self.state = 'init'

    def startElement(self, name, attrs):
        if self.state == 'init':
            if name == 'LocationConstraint':
                self.state = 'tag_location'
                self.location = ''
            else: self.state = 'bad'
        else: self.state = 'bad'

    def endElement(self, name):
        if self.state == 'tag_location' and name == 'LocationConstraint':
            self.state = 'done'
        else: self.state = 'bad'

    def characters(self, content):
        if self.state == 'tag_location':
            self.location += content
