# Web sign-in with Apple and Google

`apps/profile/web_social_auth.py` adds browser redirects around the account protocol in
`apps/api/social_auth.py`, shared with iOS and Android. Provider buttons appear on `/account/login`,
`/account/signup`, and both forms on `/welcome` when `SOCIAL_WEB_ENABLED = True` and
that provider is configured. Browser sign-in is enabled by default. Set
`SOCIAL_WEB_ENABLED = False` in server settings to disable it. Disabled browser sign-in hides both buttons and
rejects new `/account/social/start` requests; existing in-flight attempts can finish.
The switch does not affect iOS or Android's `/api/social/` endpoints.
Username/password forms remain available. New provider users choose a username; existing
email matches must prove their NewsBlur password before linking. Email alone never links
accounts. Existing provider identities log in directly.
The username continuation also offers “Connect an existing account.” That explicit
choice sends `action=link` with the existing NewsBlur username or email and password,
so Apple and Google can use different email addresses while connecting to the same
NewsBlur account. Linking keeps the NewsBlur account email unchanged. Unknown or
incorrect credentials never create a new account, and an already linked provider
identity cannot be moved to another account through this flow.
Link responses include `can_choose_username`: it is true only when the provider email
does not already belong to a NewsBlur account. In that case, clients may offer
“Create a new account instead” and send `action=choose_username` to get a fresh username
step and ticket. When the provider email already belongs to an account, the flag is
false and `choose_username` keeps the password link step. The web continuation preserves
this choice and the entered username on refresh; returning to username selection clears
the entered username. A taken username never authenticates a different-email account
from a signup submission, even if that submission includes its correct password.

## Server and provider configuration

Apply `profile.0032_socialidentity` and install the requirements from
`config/requirements.txt`. All three clients use this one identity table and migration.

Google uses the same OAuth client as iOS and Android:

- `SOCIAL_GOOGLE_CLIENT_ID`
- `SOCIAL_GOOGLE_CLIENT_SECRET`
- Register `https://www.newsblur.com/account/social/google/callback` as an authorized
  redirect URI, in addition to the native flow's `/api/social/google/callback`.
- `SOCIAL_GOOGLE_WEB_REDIRECT_URI` can override the browser callback for development.

Apple needs a Services ID for the website:

- `SOCIAL_APPLE_WEB_CLIENT_ID`: the Services ID, grouped with the primary NewsBlur
  App ID so native and web sign-in resolve to the same provider subject. Android
  uses this same Services ID (`com.newsblur.signin`).
- `SOCIAL_APPLE_TEAM_ID`, `SOCIAL_APPLE_KEY_ID`, `SOCIAL_APPLE_PRIVATE_KEY_PATH`:
  reuse the externally mounted Sign in with Apple signing key configuration.
  NewsBlur's private secrets repository stores `keys/apple-signin.p8`; the web Ansible
  role copies it to the ignored `/srv/newsblur/config/secrets/apple-signin.p8` path
  with owner-only permissions when provisioning settings (`env` tag).
- Register `www.newsblur.com` and the exact return URL
  `https://www.newsblur.com/account/social/apple/callback` on that Services ID.
  Preserve Android's `https://www.newsblur.com/api/social/apple/callback` return URL.
- `SOCIAL_APPLE_WEB_REDIRECT_URI` can override the browser callback. Apple requires
  a registered HTTPS domain rather than localhost or an IP address.
- Configure Apple's private email relay for NewsBlur's sender domains if accepting
  Hide My Email addresses. Keep signing keys and OAuth client secrets in the private
  secrets repository, never in this application repository.

See [Apple's environment setup](https://developer.apple.com/documentation/signinwithapple/configuring-your-environment-for-sign-in-with-apple)
and [Google's OpenID Connect server flow](https://developers.google.com/identity/openid-connect/openid-connect).

## Browser behavior and verification

### Staging

Register these additional return URLs with the same provider clients:

- `https://staging.newsblur.com/account/social/google/callback`
- `https://staging.newsblur.com/account/social/apple/callback`
- `https://staging.newsblur.com/api/social/google/callback`
- `https://staging.newsblur.com/api/social/apple/callback`

Also register `staging.newsblur.com` on Apple's Services ID. The staging-specific
configuration in `ansible/roles/web/tasks/main.yml` preserves these callbacks when
server settings are recopied and explicitly enables `SOCIAL_WEB_ENABLED` on staging.
It overrides both native and browser redirect settings so mobile tests started on
staging also return there, rather than sending their authorization codes to production.
Production uses the enabled default; an explicit false override still disables it.
Local callback overrides belong in the worktree's untracked `newsblur_web/local_settings.py`.
Google credentials remain in the external common settings.
Staging shares the NewsBlur database, so accounts and identity links created there
are real accounts. A successful staging login still requires provider-console setup.

### Protocol

Start and account confirmation require CSRF-protected POSTs. Provider state, nonce,
and a browser-session verifier bind each attempt to its initiating browser. Apple
returns by cross-site POST; a 303 redirect restores the browser's SameSite=Lax session
before code exchange. Apple requests `response_type=code id_token` with `form_post`,
as described in [Apple's authorization protocol](https://developer.apple.com/documentation/signinwithapple/incorporating-sign-in-with-apple-into-other-platforms).
The callback caches the posted identity token with the one-use result. After browser
binding, the shared verifier checks its signature, Services ID audience, nonce, and
verified email. Only then does the server exchange the code using the exact configured
redirect URI. The exchange token must have a valid signature, issuer, Services ID
audience, and matching subject; email and nonce may be absent, but a supplied nonce
must match. The authorization token is removed before storing the pending session or
account ticket. Google continues using the authorization-code flow.
The callback alone is CSRF-exempt. Provider codes and identity
proofs stay server-side after callback, and state/result/ticket values expire after ten
minutes and are consumed once. The web Apple token must name the Services ID as its audience;
iOS's native endpoint continues requiring native app audiences. Android's Apple
callback verifies the Services ID and returns to its allowlisted app scheme.

`apps/api/social_auth.py` owns token verification and `complete_ticket`, the shared
account creation/linking implementation. `apps/profile/web_social_auth.py` owns browser
session binding and HTML responses. Mobile callbacks stay under `/api/social/`, while
website callbacks stay under `/account/social/`; neither transport replaces the other.

The welcome and signup views explicitly load/set the CSRF cookie before rendering
provider forms because the site does not install global CSRF middleware. This covers
both a fresh browser and an existing cookie, including direct visits to `/welcome`.

The continuation page supports username conflicts and incorrect-password retries.
Successful new accounts preserve referral and gift attribution, and safe same-host
return paths survive sign-in. External return URLs fall back to `/`. Provider cancellation
and expired attempts offer a return to ordinary login. A cookie remembers the last
successful provider for its button's “Last used” badge.

Run the focused tests inside the web container:

```sh
docker exec -t newsblur_web_ftux-combined python manage.py test apps.api.test_social_auth apps.profile.test_web_social_auth --noinput -v 1
```

These tests cover the transport and real database account behavior with mocked provider
responses, including real signed Apple JWTs for authorization and exchange validation.
Real Apple and Google round trips still need verification after provider
console configuration: create an account, log out and return, sign in to an account
created on iOS, connect an existing password account, cancel, and retry an expired flow.
