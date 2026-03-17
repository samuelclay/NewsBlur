"""NewsBlur-branded HTML pages for MCP OAuth flows.

Replaces FastMCP's generic OAuth UI with pages that match
NewsBlur's static page design (green/teal gradient, glass card).
"""

from __future__ import annotations

import html as html_module

from newsblur_mcp.settings import NEWSBLUR_PUBLIC_URL

LOGO_URL = f"{NEWSBLUR_PUBLIC_URL}/media/embed/logo_newsblur_blur.png"

NEWSBLUR_STYLES = """
    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,300;0,9..40,500;0,9..40,700;1,9..40,300&display=swap');

    *, *::before, *::after {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
    }

    html, body {
        height: 100%;
    }

    body {
        font-family: 'DM Sans', 'Helvetica Neue', Helvetica, sans-serif;
        -webkit-font-smoothing: antialiased;
        -moz-osx-font-smoothing: grayscale;
        background-color: #304332;
        background: linear-gradient(168deg, #3a5240 0%, #304332 35%, #1a2a1c 100%);
        display: flex;
        justify-content: center;
        align-items: center;
        min-height: 100vh;
        overflow: hidden;
    }

    /* Subtle ambient glow */
    body::before {
        content: '';
        position: fixed;
        inset: 0;
        background: radial-gradient(ellipse at 30% 20%, rgba(142, 198, 133, 0.06) 0%, transparent 60%),
                    radial-gradient(ellipse at 70% 80%, rgba(0, 0, 0, 0.15) 0%, transparent 50%);
        pointer-events: none;
    }

    .nb-card {
        position: relative;
        background: rgba(255, 255, 255, 0.055);
        backdrop-filter: blur(16px) saturate(140%);
        -webkit-backdrop-filter: blur(16px) saturate(140%);
        border-radius: 20px;
        padding: 52px 56px 48px;
        text-align: center;
        max-width: 460px;
        width: 100%;
        margin: 24px;
        /* Layered shadows for natural depth instead of border */
        box-shadow: 0 1px 2px rgba(0, 0, 0, 0.08),
                    0 4px 12px rgba(0, 0, 0, 0.12),
                    0 12px 40px rgba(0, 0, 0, 0.18),
                    0 0 0 1px rgba(255, 255, 255, 0.07) inset;
        animation: cardIn 0.5s cubic-bezier(0.16, 1, 0.3, 1) both;
    }

    @keyframes cardIn {
        from {
            opacity: 0;
            transform: translateY(12px) scale(0.98);
        }
    }

    .nb-logo {
        margin-bottom: 32px;
        animation: textIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) 0.05s both;
    }

    .nb-logo img {
        height: 32px;
        width: auto;
        opacity: 0.9;
        filter: brightness(1.1);
        /* Subtle outline for depth against dark bg */
        outline: 1px solid rgba(255, 255, 255, 0.04);
        outline-offset: 4px;
        border-radius: 2px;
    }

    .nb-icon {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 52px;
        height: 52px;
        /* Concentric radius: card is 20px with ~56px padding to icon,
           so inner elements can use their own radius freely */
        border-radius: 14px;
        margin-bottom: 20px;
        font-size: 24px;
        line-height: 1;
        animation: iconIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) 0.15s both;
    }

    @keyframes iconIn {
        from {
            opacity: 0;
            transform: scale(0.25);
            filter: blur(4px);
        }
        to {
            opacity: 1;
            transform: scale(1);
            filter: blur(0px);
        }
    }

    .nb-icon-error {
        background: rgba(197, 130, 110, 0.15);
        /* Layered shadow instead of border for soft depth */
        box-shadow: 0 0 0 1px rgba(197, 130, 110, 0.18),
                    0 2px 8px rgba(197, 130, 110, 0.08);
        color: #D4967F;
        /* Optical centering: x glyph sits slightly high, nudge down */
        padding-top: 2px;
    }

    .nb-icon-success {
        background: rgba(142, 198, 133, 0.15);
        box-shadow: 0 0 0 1px rgba(142, 198, 133, 0.18),
                    0 2px 8px rgba(142, 198, 133, 0.08);
        color: #8EC685;
        /* Optical centering: checkmark is balanced, no adjustment needed */
    }

    h1 {
        color: #fff;
        font-size: 22px;
        font-weight: 700;
        text-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
        letter-spacing: -0.3px;
        margin: 0 0 14px 0;
        line-height: 1.3;
        text-wrap: balance;
        animation: textIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) 0.2s both;
    }

    @keyframes textIn {
        from {
            opacity: 0;
            transform: translateY(6px);
        }
    }

    .nb-message {
        color: rgba(255, 255, 255, 0.7);
        font-size: 15px;
        line-height: 1.55;
        text-shadow: 0 1px 0 rgba(0, 0, 0, 0.2);
        text-wrap: pretty;
        margin-bottom: 0;
        animation: textIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) 0.25s both;
    }

    .nb-details {
        margin-top: 20px;
        text-align: left;
        animation: textIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) 0.3s both;
    }

    .nb-details summary {
        cursor: pointer;
        font-size: 13px;
        color: rgba(255, 255, 255, 0.4);
        font-weight: 500;
        letter-spacing: 0.3px;
        text-transform: uppercase;
        list-style: none;
        /* Min 40px hit area */
        padding: 10px 0;
        min-height: 40px;
        display: flex;
        align-items: center;
        transition-property: color;
        transition-duration: 0.2s;
        user-select: none;
    }

    .nb-details summary:hover {
        color: rgba(255, 255, 255, 0.6);
    }

    .nb-details summary::marker,
    .nb-details summary::-webkit-details-marker {
        display: none;
    }

    .nb-details summary::before {
        content: '\\25B8';
        display: inline-block;
        margin-right: 6px;
        transition-property: transform;
        transition-duration: 0.2s;
        font-size: 11px;
    }

    .nb-details[open] summary::before {
        transform: rotate(90deg);
    }

    .nb-detail-box {
        background: rgba(0, 0, 0, 0.2);
        /* Layered shadow instead of border */
        box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.05) inset,
                    0 2px 4px rgba(0, 0, 0, 0.1) inset;
        border-radius: 10px;
        padding: 14px 16px;
        margin-top: 8px;
    }

    .nb-detail-row {
        display: flex;
        padding: 6px 0;
        /* Subtle shadow separator instead of border */
        box-shadow: 0 1px 0 rgba(255, 255, 255, 0.04);
        gap: 12px;
    }

    .nb-detail-row:last-child {
        box-shadow: none;
    }

    .nb-detail-label {
        font-weight: 500;
        min-width: 110px;
        color: rgba(255, 255, 255, 0.35);
        font-size: 12px;
        letter-spacing: 0.2px;
        flex-shrink: 0;
        padding-top: 1px;
    }

    .nb-detail-value {
        flex: 1;
        font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
        font-size: 12px;
        color: rgba(255, 255, 255, 0.55);
        word-break: break-all;
        overflow-wrap: break-word;
        line-height: 1.5;
    }

    .nb-hint {
        margin-top: 24px;
        animation: textIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) 0.35s both;
    }

    .nb-hint a {
        color: #8EC685;
        text-decoration: none;
        font-size: 14px;
        font-weight: 500;
        /* 40px min hit area via padding */
        padding: 10px 16px;
        margin: -10px -16px;
        border-radius: 8px;
        display: inline-block;
        transition-property: color, background-color;
        transition-duration: 0.2s;
    }

    .nb-hint a:hover {
        color: #A8D8A0;
        background: rgba(142, 198, 133, 0.08);
    }

    .nb-close-hint {
        color: rgba(255, 255, 255, 0.35);
        font-size: 13px;
        margin-top: 20px;
        text-wrap: pretty;
        animation: textIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) 0.35s both;
    }

    @media (max-width: 520px) {
        .nb-card {
            padding: 36px 28px 32px;
            margin: 16px;
            border-radius: 16px;
        }
        h1 { font-size: 20px; }
        .nb-detail-row { flex-direction: column; gap: 2px; }
        .nb-detail-label { min-width: unset; }
    }
"""


def create_error_html(
    error_title: str,
    error_message: str,
    error_details: dict[str, str] | None = None,
    server_name: str | None = None,
    server_icon_url: str | None = None,
) -> str:
    """Create a NewsBlur-styled error page for OAuth errors.

    Drop-in replacement for fastmcp.server.auth.oauth_proxy.ui.create_error_html
    with the same signature.
    """
    title_escaped = html_module.escape(error_title)
    message_escaped = html_module.escape(error_message)

    details_section = ""
    if error_details:
        rows_html = "\n".join(
            f"""<div class="nb-detail-row">
                    <div class="nb-detail-label">{html_module.escape(label)}</div>
                    <div class="nb-detail-value">{html_module.escape(value)}</div>
                </div>"""
            for label, value in error_details.items()
        )
        details_section = f"""
            <details class="nb-details">
                <summary>Error Details</summary>
                <div class="nb-detail-box">
                    {rows_html}
                </div>
            </details>
        """

    logo_escaped = html_module.escape(LOGO_URL)

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="robots" content="noindex">
    <title>{title_escaped} - NewsBlur</title>
    <meta http-equiv="Content-Security-Policy"
          content="default-src 'none'; style-src 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; img-src https: data:; base-uri 'none'">
    <style>{NEWSBLUR_STYLES}</style>
</head>
<body>
    <div class="nb-card">
        <div class="nb-logo">
            <img src="{logo_escaped}" alt="NewsBlur">
        </div>
        <div class="nb-icon nb-icon-error">&times;</div>
        <h1>{title_escaped}</h1>
        <p class="nb-message">{message_escaped}</p>
        {details_section}
        <div class="nb-hint">
            <a href="https://newsblur.com">Return to NewsBlur</a>
        </div>
    </div>
</body>
</html>"""


def create_success_html(
    title: str = "Connected",
    message: str = "Authentication successful. You can close this window.",
) -> str:
    """Create a NewsBlur-styled success page for OAuth completion."""
    title_escaped = html_module.escape(title)
    message_escaped = html_module.escape(message)
    logo_escaped = html_module.escape(LOGO_URL)

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="robots" content="noindex">
    <title>{title_escaped} - NewsBlur</title>
    <meta http-equiv="Content-Security-Policy"
          content="default-src 'none'; style-src 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; img-src https: data:; base-uri 'none'">
    <style>{NEWSBLUR_STYLES}</style>
</head>
<body>
    <div class="nb-card">
        <div class="nb-logo">
            <img src="{logo_escaped}" alt="NewsBlur">
        </div>
        <div class="nb-icon nb-icon-success">&#10003;</div>
        <h1>{title_escaped}</h1>
        <p class="nb-message">{message_escaped}</p>
        <p class="nb-close-hint">You can close this window and return to your MCP client.</p>
    </div>
</body>
</html>"""


def patch_fastmcp_ui():
    """Monkey-patch FastMCP's OAuth proxy to use NewsBlur-styled pages."""
    import fastmcp.server.auth.oauth_proxy.proxy as proxy_module

    proxy_module.create_error_html = create_error_html
