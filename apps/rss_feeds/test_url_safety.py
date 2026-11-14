import socket
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from unittest import TestCase
from unittest.mock import patch

import requests

from utils.url_safety import (
    UnsafeUrlError,
    safe_http2_get,
    safe_requests_get,
    validate_public_url,
)


class Test_BackslashUrlSafety(TestCase):
    PUBLIC_DNS = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 80))]

    @patch("utils.url_safety.socket.getaddrinfo", return_value=PUBLIC_DNS)
    def test_rejects_backslashes_before_dns(self, mock_dns):
        for url in (
            r"http://127.0.0.1:8761\@example.com/feed.xml",
            r"https://127.0.0.1:8761\@example.com/feed.xml",
            r"feed://127.0.0.1:8761\@example.com/feed.xml",
            r"//127.0.0.1:8761\@example.com/feed.xml",
            r"127.0.0.1:8761\@example.com/feed.xml",
            r"http://example.com/feed\name.xml",
        ):
            with self.subTest(url=url):
                with self.assertRaises(UnsafeUrlError):
                    validate_public_url(url)
        mock_dns.assert_not_called()

    def test_backslash_payload_never_reaches_loopback(self):
        received_paths = []

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                received_paths.append(self.path)
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"<rss><channel><title>Internal feed</title></channel></rss>")

            def log_message(self, *args):
                pass

        original_getaddrinfo = socket.getaddrinfo

        def resolve(host, *args, **kwargs):
            if host == "example.com":
                return self.PUBLIC_DNS
            return original_getaddrinfo(host, *args, **kwargs)

        with ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                port = server.server_port
                with requests.Session() as session:
                    session.trust_env = False
                    with patch("utils.url_safety.socket.getaddrinfo", side_effect=resolve), patch(
                        "requests.sessions.Session", return_value=session
                    ):
                        with self.assertRaises(UnsafeUrlError):
                            safe_requests_get("http://127.0.0.1:%s/feed.xml" % port, timeout=2)
                        for allow_redirects in (True, False):
                            with self.subTest(allow_redirects=allow_redirects):
                                with self.assertRaises(UnsafeUrlError):
                                    safe_requests_get(
                                        r"http://127.0.0.1:%s\@example.com/feed.xml" % port,
                                        timeout=2,
                                        allow_redirects=allow_redirects,
                                    )
                self.assertEqual(received_paths, [])
            finally:
                server.shutdown()
                thread.join(timeout=2)

    @patch("utils.url_safety.socket.getaddrinfo", return_value=PUBLIC_DNS)
    @patch("utils.url_safety.requests.request")
    def test_rejects_backslash_redirect_before_second_request(self, mock_request, mock_dns):
        for location in (
            r"http://127.0.0.1:8761\@example.com/feed.xml",
            r"//127.0.0.1:8761\@example.com/feed.xml",
        ):
            with self.subTest(location=location):
                redirect = requests.Response()
                redirect.status_code = 302
                redirect.url = "http://example.com/start"
                redirect.headers["Location"] = location
                success = requests.Response()
                success.status_code = 200
                mock_request.reset_mock()
                mock_request.side_effect = [redirect, success]
                with self.assertRaises(UnsafeUrlError):
                    safe_requests_get(redirect.url)
                mock_request.assert_called_once()

    @patch("utils.url_safety.socket.getaddrinfo", return_value=PUBLIC_DNS)
    @patch("utils.url_safety.httpx.Client")
    def test_http2_rejects_backslash_before_connecting(self, mock_client, mock_dns):
        with self.assertRaises(UnsafeUrlError):
            safe_http2_get(r"https://127.0.0.1:8761\@example.com/feed.xml")
        mock_client.assert_not_called()

    @patch("utils.url_safety.socket.getaddrinfo", return_value=PUBLIC_DNS)
    def test_preserves_valid_urls_and_encoded_path_backslashes(self, mock_dns):
        for url in (
            "http://example.com/feed.xml",
            "https://user:password@example.com/feed.xml?limit=10#latest",
            "https://example.com/feed%5Cname.xml",
        ):
            with self.subTest(url=url):
                self.assertEqual(validate_public_url(url), url)
        self.assertEqual(validate_public_url("feed://example.com/feed.xml"), "http://example.com/feed.xml")
