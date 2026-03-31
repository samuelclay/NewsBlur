"""OAuth local callback flow and token storage for the NewsBlur CLI.

Implements a gh-auth-login-style flow:
1. Start a temporary HTTP server on a random port
2. Open the browser to NewsBlur's OAuth authorize endpoint
3. Capture the authorization code from the redirect callback
4. Exchange the code for an access token
5. Store the token at ~/.config/newsblur/auth.json (0600 permissions)
"""

from __future__ import annotations

import json
import os
import stat
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import httpx

CLI_OAUTH_CLIENT_ID = "newsblur-cli"
TOKEN_EXCHANGE_TIMEOUT = 30
DEFAULT_SERVER = "https://newsblur.com"
LOCAL_HOSTS = {"localhost", "127.0.0.1", "::1"}


def _is_local_server() -> bool:
    """Check if the configured server URL points to a local dev instance."""
    parsed = urlparse(get_server_url())
    return parsed.hostname in LOCAL_HOSTS


def _ssl_verify() -> bool:
    """Return False for local dev servers (self-signed certs), True otherwise."""
    return not _is_local_server()


def get_config_dir() -> Path:
    """Return ~/.config/newsblur/, creating it if needed."""
    config_dir = Path.home() / ".config" / "newsblur"
    config_dir.mkdir(parents=True, exist_ok=True)
    return config_dir


def get_config_path() -> Path:
    """Return the path to the CLI config file."""
    return get_config_dir() / "config.json"


def get_token_path() -> Path:
    """Return the path to the stored auth token file."""
    return get_config_dir() / "auth.json"


def get_server_url() -> str:
    """Return the configured server URL, or the default."""
    config_path = get_config_path()
    if config_path.exists():
        try:
            data = json.loads(config_path.read_text())
            server = data.get("server")
            if server:
                return server.rstrip("/")
        except (json.JSONDecodeError, OSError):
            pass
    return DEFAULT_SERVER


def set_server_url(server: str) -> None:
    """Persist the server URL to config."""
    config_path = get_config_path()
    data = {}
    if config_path.exists():
        try:
            data = json.loads(config_path.read_text())
        except (json.JSONDecodeError, OSError):
            pass
    data["server"] = server.rstrip("/")
    config_path.write_text(json.dumps(data, indent=2))
    os.chmod(config_path, stat.S_IRUSR | stat.S_IWUSR)


def load_token() -> str | None:
    """Load the access token from disk.

    Returns the access token string if valid, or None if missing/expired.
    If the token is expired but a refresh token is available, attempts a refresh.
    """
    token_path = get_token_path()
    if not token_path.exists():
        return None

    try:
        data = json.loads(token_path.read_text())
    except (json.JSONDecodeError, OSError):
        return None

    # Check expiry if recorded
    expires_at = data.get("expires_at")
    if expires_at and time.time() >= expires_at:
        # Try refresh
        refresh_token = data.get("refresh_token")
        if refresh_token:
            refreshed = refresh_access_token(refresh_token)
            if refreshed:
                save_token(refreshed)
                return refreshed.get("access_token")
        return None

    return data.get("access_token")


def save_token(data: dict) -> None:
    """Save token data to disk with restricted permissions (0600)."""
    token_path = get_token_path()
    token_path.write_text(json.dumps(data, indent=2))
    os.chmod(token_path, stat.S_IRUSR | stat.S_IWUSR)


def delete_token() -> None:
    """Remove the stored token file."""
    token_path = get_token_path()
    if token_path.exists():
        token_path.unlink()


def refresh_access_token(refresh_token: str) -> dict | None:
    """Refresh the access token using a refresh token.

    Returns the new token data dict, or None on failure.
    """
    try:
        resp = httpx.post(
            f"{get_server_url()}/oauth/token/",
            data={
                "grant_type": "refresh_token",
                "refresh_token": refresh_token,
                "client_id": CLI_OAUTH_CLIENT_ID,
            },
            timeout=TOKEN_EXCHANGE_TIMEOUT,
            verify=_ssl_verify(),
        )
        if resp.status_code == 200:
            token_data = resp.json()
            # Compute absolute expiry time
            if "expires_in" in token_data:
                token_data["expires_at"] = time.time() + token_data["expires_in"]
            return token_data
    except Exception:
        pass
    return None


def login_flow(server: str | None = None) -> dict:
    """Run the full OAuth local callback flow.

    Opens the browser, waits for the authorization code callback,
    exchanges it for a token, and stores it.

    Args:
        server: Server URL to authenticate against. Persisted to config if provided.

    Returns the token data dict on success.
    Raises RuntimeError on failure.
    """
    if server:
        set_server_url(server)
    code_holder: dict = {}
    code_event = threading.Event()

    class CallbackHandler(BaseHTTPRequestHandler):
        def do_GET(self):
            parsed = urlparse(self.path)
            if parsed.path == "/callback":
                params = parse_qs(parsed.query)
                if "code" in params:
                    code_holder["code"] = params["code"][0]
                    self.send_response(200)
                    self.send_header("Content-Type", "text/html")
                    self.end_headers()
                    self.wfile.write(
                        b"<html><body><h1>Login successful!</h1>"
                        b"<p>You can close this tab and return to the terminal.</p>"
                        b"</body></html>"
                    )
                elif "error" in params:
                    code_holder["error"] = params.get("error_description", params["error"])[0]
                    self.send_response(400)
                    self.send_header("Content-Type", "text/html")
                    self.end_headers()
                    self.wfile.write(
                        f"<html><body><h1>Login failed</h1><p>{code_holder['error']}</p></body></html>".encode()
                    )
                else:
                    self.send_response(400)
                    self.end_headers()
                code_event.set()
            else:
                self.send_response(404)
                self.end_headers()

        def log_message(self, format, *args):
            # Suppress HTTP server logging
            pass

    # Bind to a random available port
    server = HTTPServer(("127.0.0.1", 0), CallbackHandler)
    port = server.server_address[1]
    redirect_uri = f"http://127.0.0.1:{port}/callback"

    authorize_url = (
        f"{get_server_url()}/oauth/authorize/"
        f"?client_id={CLI_OAUTH_CLIENT_ID}"
        f"&redirect_uri={redirect_uri}"
        f"&response_type=code"
        f"&scope=read+write"
    )

    # Start server in background thread
    server_thread = threading.Thread(target=server.serve_forever, daemon=True)
    server_thread.start()

    try:
        webbrowser.open(authorize_url)

        # Wait for the callback (up to 120 seconds)
        if not code_event.wait(timeout=120):
            raise RuntimeError("Login timed out waiting for authorization callback.")

        if "error" in code_holder:
            raise RuntimeError(f"Authorization failed: {code_holder['error']}")

        code = code_holder["code"]

        # Exchange the code for a token
        resp = httpx.post(
            f"{get_server_url()}/oauth/token/",
            data={
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": redirect_uri,
                "client_id": CLI_OAUTH_CLIENT_ID,
            },
            timeout=TOKEN_EXCHANGE_TIMEOUT,
            verify=_ssl_verify(),
        )

        if resp.status_code != 200:
            raise RuntimeError(f"Token exchange failed (HTTP {resp.status_code}): {resp.text}")

        token_data = resp.json()

        # Compute absolute expiry time
        if "expires_in" in token_data:
            token_data["expires_at"] = time.time() + token_data["expires_in"]

        save_token(token_data)
        return token_data

    finally:
        server.shutdown()


def get_auth_status() -> dict:
    """Return the current authentication state.

    Returns a dict with keys: authenticated (bool), username (str|None),
    token_path (str), expires_at (float|None).
    """
    token_path = get_token_path()
    if not token_path.exists():
        return {
            "authenticated": False,
            "username": None,
            "token_path": str(token_path),
            "expires_at": None,
        }

    try:
        data = json.loads(token_path.read_text())
    except (json.JSONDecodeError, OSError):
        return {
            "authenticated": False,
            "username": None,
            "token_path": str(token_path),
            "expires_at": None,
        }

    token = data.get("access_token")
    if not token:
        return {
            "authenticated": False,
            "username": None,
            "token_path": str(token_path),
            "expires_at": None,
        }

    # Check if expired
    expires_at = data.get("expires_at")
    if expires_at and time.time() >= expires_at:
        # Try refresh
        refresh_token = data.get("refresh_token")
        if refresh_token:
            refreshed = refresh_access_token(refresh_token)
            if refreshed:
                save_token(refreshed)
                data = refreshed
            else:
                return {
                    "authenticated": False,
                    "username": None,
                    "token_path": str(token_path),
                    "expires_at": expires_at,
                    "expired": True,
                }

    # Verify the token is valid by calling the user info endpoint
    username = None
    try:
        resp = httpx.get(
            f"{get_server_url()}/oauth/user/info/",
            headers={"Authorization": f"Bearer {data.get('access_token', '')}"},
            timeout=10,
            verify=_ssl_verify(),
        )
        if resp.status_code == 200:
            user_info = resp.json()
            username = user_info.get("user_name")
    except Exception:
        pass

    return {
        "authenticated": True,
        "username": username,
        "server": get_server_url(),
        "token_path": str(token_path),
        "expires_at": data.get("expires_at"),
    }
