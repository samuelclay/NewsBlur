import ipaddress
import socket
from urllib.parse import urljoin, urlparse

import httpx
import requests
from requests.structures import CaseInsensitiveDict
from requests.utils import get_encoding_from_headers

BLOCKED_PRIVATE_URL_MESSAGE = "This address points to a private or reserved network."
HTTP_SCHEMES = ("http", "https")
MAX_REDIRECTS = 5


class UnsafeUrlError(requests.RequestException, ValueError):
    pass


def normalize_url_for_safety(url):
    url = (url or "").strip()
    if url.startswith("feed://"):
        url = "http://%s" % url[7:]
    parsed = urlparse(url)
    if parsed.scheme:
        return url
    if parsed.netloc:
        return "http://%s" % url.lstrip("/")
    return "http://%s" % url


def validate_public_url(url):
    try:
        url = normalize_url_for_safety(url)
        parsed = urlparse(url)
    except ValueError as e:
        raise UnsafeUrlError("Invalid URL.") from e

    if parsed.scheme not in HTTP_SCHEMES:
        raise UnsafeUrlError("Only http and https URLs are allowed.")
    if not parsed.hostname:
        raise UnsafeUrlError("URL must include a hostname.")

    hostname = parsed.hostname.strip("[]")
    port = _port_or_default(parsed)
    addresses = _resolve_hostname(hostname, port)
    for address in addresses:
        _validate_public_ip(address)

    return url


def safe_requests_get(url, **kwargs):
    return safe_requests_request("GET", url, **kwargs)


def safe_requests_request(method, url, **kwargs):
    allow_redirects = kwargs.pop("allow_redirects", True)
    max_redirects = kwargs.pop("max_redirects", MAX_REDIRECTS)
    url = validate_public_url(url)

    if not allow_redirects:
        return requests.request(method, url, allow_redirects=False, **kwargs)

    history = []
    current_url = url
    current_method = method
    request_kwargs = dict(kwargs)

    for _ in range(max_redirects + 1):
        response = requests.request(current_method, current_url, allow_redirects=False, **request_kwargs)
        if not response.is_redirect:
            response.history = history
            return response

        location = response.headers.get("Location")
        if not location:
            response.history = history
            return response

        if len(history) >= max_redirects:
            response.close()
            raise requests.TooManyRedirects("Exceeded %s redirects for %s" % (max_redirects, url))

        next_url = validate_public_url(urljoin(response.url or current_url, location))
        history.append(response)
        current_url = next_url

        if response.status_code == 303 and current_method.upper() != "HEAD":
            current_method = "GET"
            request_kwargs.pop("data", None)
            request_kwargs.pop("json", None)

    raise requests.TooManyRedirects("Exceeded %s redirects for %s" % (max_redirects, url))


def safe_http2_get(url, headers=None, timeout=15, max_redirects=MAX_REDIRECTS):
    """GET over HTTP/2, for sites that refuse HTTP/1.1, the only version requests speaks.
    dumbingofage.com answers HTTP/1.1 with 426 Upgrade Required and serves its feed only
    over HTTP/2 (forum #13858). Every hop is checked with validate_public_url exactly like
    safe_requests_request, and the answer comes back as a requests.Response so callers
    read it the same way. httpx errors are raised as their requests equivalents because
    callers catch requests.RequestException. FetchFeed.fetch swaps this in for
    safe_requests_get with the same call (url, headers=, timeout=), so any new keyword
    passed there has to be accepted here too. The returned response carries status, headers,
    body, url, encoding, history, and http_version; request and raw are left unset.
    utils/url_safety.py
    """
    url = validate_public_url(url)
    history = []
    current_url = url

    try:
        client = httpx.Client(http2=True, timeout=timeout, follow_redirects=False)
    except ImportError as e:
        # httpx refuses http2=True when the h2 package is missing.
        raise requests.ConnectionError(str(e)) from e

    try:
        with client:
            for _ in range(max_redirects + 1):
                response = _requests_response_from_httpx(client.get(current_url, headers=headers))
                if not response.is_redirect:
                    response.history = history
                    return response

                if len(history) >= max_redirects:
                    raise requests.TooManyRedirects("Exceeded %s redirects for %s" % (max_redirects, url))

                current_url = validate_public_url(urljoin(response.url, response.headers["Location"]))
                history.append(response)
    except httpx.TimeoutException as e:
        raise requests.Timeout(str(e)) from e
    except (httpx.HTTPError, httpx.InvalidURL, UnicodeEncodeError) as e:
        # UnicodeEncodeError is httpx rejecting a non-ASCII header value, such as an odd
        # ETag a feed once sent that requests would have passed through as latin-1.
        raise requests.ConnectionError(str(e)) from e

    raise requests.TooManyRedirects("Exceeded %s redirects for %s" % (max_redirects, url))


def _requests_response_from_httpx(httpx_response):
    # The body is already read and decompressed by httpx, the same as requests does, so the
    # response is marked consumed: iter_content() then serves _content instead of streaming
    # from raw, which is None here. utils/url_safety.py
    response = requests.Response()
    response.status_code = httpx_response.status_code
    response.reason = httpx_response.reason_phrase
    response.headers = CaseInsensitiveDict(httpx_response.headers.items())
    response._content = httpx_response.content
    response._content_consumed = True
    response.url = str(httpx_response.url)
    response.encoding = get_encoding_from_headers(response.headers)
    # httpx quietly speaks HTTP/1.1 over TLS when the server's ALPN picks it, so keep the
    # protocol it really used for the fetch log in utils/feed_fetcher.py.
    response.http_version = httpx_response.http_version
    return response


def _port_or_default(parsed):
    try:
        return parsed.port or (443 if parsed.scheme == "https" else 80)
    except ValueError as e:
        raise UnsafeUrlError("Invalid URL port.") from e


def _resolve_hostname(hostname, port):
    try:
        return {ipaddress.ip_address(hostname)}
    except ValueError:
        pass

    try:
        infos = socket.getaddrinfo(hostname, port, type=socket.SOCK_STREAM)
    except (socket.gaierror, UnicodeError) as e:
        raise UnsafeUrlError("Could not resolve URL hostname.") from e

    addresses = set()
    for info in infos:
        try:
            addresses.add(ipaddress.ip_address(info[4][0]))
        except ValueError as e:
            raise UnsafeUrlError("URL resolved to an invalid IP address.") from e
    if not addresses:
        raise UnsafeUrlError("Could not resolve URL hostname.")
    return addresses


def _validate_public_ip(address):
    mapped_address = getattr(address, "ipv4_mapped", None)
    if mapped_address:
        address = mapped_address
    if (
        not address.is_global
        or address.is_private
        or address.is_loopback
        or address.is_link_local
        or address.is_multicast
        or address.is_reserved
        or address.is_unspecified
    ):
        raise UnsafeUrlError("%s %s" % (BLOCKED_PRIVATE_URL_MESSAGE, address))
