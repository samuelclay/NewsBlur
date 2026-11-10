# Apple subscription renewals

`apps/profile/views.py:ios_subscription_status` accepts App Store Server Notifications V2 at
`https://newsblur.com/profile/ios_subscription_status`. Apple signs the notification and its
nested transaction separately. `apps/profile/apple_notifications.py` verifies both with
Apple's official server library, the bundled Apple Root CA G3 certificate, online certificate
checks, bundle ID `com.newsblur.NewsBlur`, and production app ID `463981119`.

The root certificate in `apps/profile/certificates/AppleRootCA-G3.cer` was downloaded from
https://www.apple.com/certificateauthority/AppleRootCA-G3.cer. Its SHA-256 fingerprint is
`63343ABFB89A6A03EBB57E9B3F5FA7BE7C4F5C756F3017B3A8C488C3653E9179`.

## Processing scope

Verified renewal notifications restore expired/free accounts and renew an existing matching
tier. `PaymentHistory.apple_original_transaction_id` preserves the account mapping across
renewals; `apple_expires_date` preserves Apple's actual expiration through later history
reconciliation. Existing client receipts from the same period are reconciled, and replaying a
transaction does not create another payment or extend access again.

Account ownership must match an existing iOS payment. Missing or ambiguous mappings return
HTTP 503 so Apple retries; they require investigation if the client never supplies a real
transaction ID. Invalid signatures or malformed requests return 400. Temporary certificate
verification failures return 503. Unexpected processing failures remain server errors, allowing
Apple to retry. Logs contain notification type/UUID and processing status, never signed payloads.

This is additive renewal processing. Paid cross-tier changes and lifetime accounts are left
unchanged. Existing client purchase handling remains responsible for tier upgrades. Refunds,
revocations, billing retry and expiration events are acknowledged and logged without changing
entitlements; existing expiration jobs continue to apply. Sandbox transactions are verified but
never grant access. Apple `TEST` notifications are verified and acknowledged without account writes.
Payment amounts retain the existing integer USD plan values, not localized Apple proceeds.

## Deployment and Apple delivery test

1. Build and publish the Python image with `make push_web`, which installs the pinned official
   Apple library and compatible cryptography dependencies from `config/requirements.txt`.
2. Apply migration `0031_paymenthistory_apple_transaction` before the new application code
   serves account requests. It adds two nullable fields and an index, with no data rewrite.
3. Deploy staging with `make staging` (`ansible/group_vars/staging.yml` selects the branch).
4. In App Store Connect, under NewsBlur > App Information > App Store Server Notifications,
   set the sandbox URL to `https://staging.newsblur.com/profile/ios_subscription_status`
   and choose Version 2. Leave production configuration until production deployment is approved.
5. Use Apple's App Store Server API sandbox `request_test_notification()` and then
   `get_test_notification_status(token)`. Verify `SUCCESS` and HTTP 200, and match the verified
   notification UUID in server logs. A plain unsigned HTTP probe is not an Apple delivery test.
6. After production approval, run both `make deploy` and `make celery`: the shared payment-history
   model is used by web requests and task workers. Verify the migration is applied and all servers
   are healthy before selecting Version 2 for the production URL in App Store Connect.
7. Request and verify a production Apple test notification as well.

The API signing key and its metadata live in the private `secrets-newsblur` repository under
`certificates/ios/SubscriptionKey_<key-id>.p8` and `certificates/ios/app_store_server.json`.
Keep the key file mode 0600. Only API diagnostics require this key; notification verification
uses public Apple certificates and does not require deploying the private key to web servers.

The official API client is constructed with the private key bytes, key ID, issuer ID, bundle ID,
and `Environment.PRODUCTION` or `Environment.SANDBOX`. For an account investigation, call
`get_all_subscription_statuses(original_transaction_id)` and verify the returned signed
transaction and signed renewal info before using their dates or status. Do not infer a renewal
from an old locally stored receipt or from the customer's reported payment date alone.
