"""Tests for CLI auth status (newsblur_mcp/cli/auth.py, cli/commands/auth.py).

A failed /oauth/user/info/ fetch must never present as "Tier: Free" — that
misreports paying subscribers (forum #13801). The failure reason is recorded
in profile_error and rendered as an Unknown tier instead.
"""

import json
import time

import httpx
import pytest

from newsblur_mcp.cli import auth as cli_auth
from newsblur_mcp.cli.commands.auth import _tier_line


@pytest.fixture
def stored_token(tmp_path, monkeypatch):
    """Store a valid, unexpired token and isolate config in tmp_path."""
    token_path = tmp_path / "auth.json"
    token_path.write_text(json.dumps({"access_token": "test-token", "expires_at": time.time() + 3600}))
    monkeypatch.setattr(cli_auth, "get_token_path", lambda: token_path)
    monkeypatch.setattr(cli_auth, "get_config_path", lambda: tmp_path / "config.json")
    monkeypatch.setattr(cli_auth, "get_server_url", lambda: "https://newsblur.test")
    return token_path


def test_auth_status_reports_archive_tier_from_user_info(stored_token, monkeypatch):
    def fake_get(url, **kwargs):
        request = httpx.Request("GET", url)
        return httpx.Response(
            200,
            request=request,
            json={
                "data": {
                    "name": "archiveuser",
                    "email": "archive@example.com",
                    "is_premium": True,
                    "is_archive": True,
                    "is_pro": False,
                    "feed_count": 42,
                },
                "result": "ok",
            },
        )

    monkeypatch.setattr(cli_auth.httpx, "get", fake_get)
    info = cli_auth.get_auth_status()
    assert info["authenticated"]
    assert info["is_archive"]
    assert "profile_error" not in info
    assert "Archive" in _tier_line(info)


def test_auth_status_records_error_when_user_info_request_fails(stored_token, monkeypatch):
    def fake_get(url, **kwargs):
        raise httpx.ConnectError("connection refused")

    monkeypatch.setattr(cli_auth.httpx, "get", fake_get)
    info = cli_auth.get_auth_status()
    assert info["authenticated"]
    assert "is_premium" not in info
    assert "ConnectError" in info["profile_error"]


def test_auth_status_records_error_on_non_200_response(stored_token, monkeypatch):
    def fake_get(url, **kwargs):
        request = httpx.Request("GET", url)
        return httpx.Response(502, request=request, text="Bad Gateway")

    monkeypatch.setattr(cli_auth.httpx, "get", fake_get)
    info = cli_auth.get_auth_status()
    assert info["authenticated"]
    assert "is_premium" not in info
    assert "502" in info["profile_error"]


def test_tier_line_shows_unknown_not_free_when_fetch_failed():
    info = {"authenticated": True, "profile_error": "ConnectError: connection refused"}
    line = _tier_line(info)
    assert "Free" not in line
    assert "Unknown" in line
    assert "connection refused" in line


def test_tier_line_shows_free_only_when_server_said_free():
    info = {"authenticated": True, "is_premium": False, "is_archive": False, "is_pro": False}
    assert "Free" in _tier_line(info)
