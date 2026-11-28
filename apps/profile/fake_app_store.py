"""The App Store's signatures, for tests. Apple signs transactions, renewal info and notifications with a key whose
certificate chains up to Apple's root. FakeAppStore makes a chain of the same shape for the test run and signs with
it. A test patches apps.profile.apple_notifications.apple_verifier with FakeAppStore.verifier, which trusts that root
and skips the online certificate status checks, so everything else Apple's library checks (the signature, the chain,
the bundle id, the environment) is checked for real and no test reaches Apple."""

import base64
import datetime
import uuid

import jwt
from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import NameOID

from apps.profile.apple_notifications import APPLE_APP_ID, APPLE_BUNDLE_ID
from apps.profile.apple_subscriptions import app_account_token

# fake_app_store.py: the extensions Apple's library requires on the signing certificate and on the one that issued it.
LEAF_OID = "1.2.840.113635.100.6.11.1"
INTERMEDIATE_OID = "1.2.840.113635.100.6.2.1"


def apple_time(moment):
    """A naive local time as Apple's milliseconds since the epoch."""
    return int(moment.timestamp() * 1000)


class FakeAppStore:
    def __init__(self):
        root_key, intermediate_key, self.key = (ec.generate_private_key(ec.SECP256R1()) for _ in range(3))
        root = self._certificate("Fake Apple Root", root_key, "Fake Apple Root", root_key, ca=True)
        intermediate = self._certificate(
            "Fake Apple Intermediate",
            intermediate_key,
            "Fake Apple Root",
            root_key,
            ca=True,
            oid=INTERMEDIATE_OID,
        )
        leaf = self._certificate(
            "Fake App Store Signing", self.key, "Fake Apple Intermediate", intermediate_key, oid=LEAF_OID
        )
        self.root = root.public_bytes(serialization.Encoding.DER)
        self.chain = [
            base64.b64encode(certificate.public_bytes(serialization.Encoding.DER)).decode()
            for certificate in (leaf, intermediate, root)
        ]

    def _certificate(self, subject, key, issuer, issuer_key, ca=False, oid=None):
        now = datetime.datetime.utcnow()
        builder = (
            x509.CertificateBuilder()
            .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, subject)]))
            .issuer_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, issuer)]))
            .public_key(key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(now - datetime.timedelta(days=1))
            .not_valid_after(now + datetime.timedelta(days=3650))
            .add_extension(x509.BasicConstraints(ca=ca, path_length=None), critical=True)
            .add_extension(
                x509.KeyUsage(
                    digital_signature=not ca,
                    content_commitment=False,
                    key_encipherment=False,
                    data_encipherment=False,
                    key_agreement=False,
                    key_cert_sign=ca,
                    crl_sign=ca,
                    encipher_only=False,
                    decipher_only=False,
                ),
                critical=True,
            )
            .add_extension(x509.SubjectKeyIdentifier.from_public_key(key.public_key()), critical=False)
            .add_extension(
                x509.AuthorityKeyIdentifier.from_issuer_public_key(issuer_key.public_key()), critical=False
            )
        )
        if oid:
            builder = builder.add_extension(
                x509.UnrecognizedExtension(x509.ObjectIdentifier(oid), b"\x05\x00"), critical=False
            )
        return builder.sign(issuer_key, hashes.SHA256())

    def verifier(self, environment):
        """What apps.profile.apple_notifications.apple_verifier gives, trusting this store's root."""
        return SignedDataVerifier([self.root], False, environment, APPLE_BUNDLE_ID, APPLE_APP_ID)

    def sign(self, payload, key=None):
        """Signed as the App Store signs, or with key, a key Apple never certified."""
        return jwt.encode(
            dict(payload, signedDate=apple_time(datetime.datetime.now())),
            key or self.key,
            algorithm="ES256",
            headers={"x5c": self.chain},
        )

    def transaction(self, user, product, transaction_id, original=None, purchased_at=None, days=31, **fields):
        """A subscription transaction as StoreKit signs it, bought by user with their app account token (None for a
        purchase made without one) at purchased_at, or now, for days."""
        purchased_at = purchased_at or datetime.datetime.now() - datetime.timedelta(minutes=1)
        return dict(
            {
                "transactionId": transaction_id,
                "originalTransactionId": original or transaction_id,
                "bundleId": APPLE_BUNDLE_ID,
                "productId": product,
                "type": "Auto-Renewable Subscription",
                "inAppOwnershipType": "PURCHASED",
                "purchaseDate": apple_time(purchased_at),
                "expiresDate": apple_time(purchased_at + datetime.timedelta(days=days)),
                "environment": "Production",
                "appAccountToken": app_account_token(user.pk) if user else None,
            },
            **fields,
        )

    def renewal_info(self, transaction, renews_into=None, renews=True):
        """Apple's renewal info for the subscription transaction belongs to: the product it renews into, its own unless
        a switch down is pending, and whether it renews at all."""
        return {
            "originalTransactionId": transaction["originalTransactionId"],
            "productId": transaction["productId"],
            "autoRenewProductId": renews_into or transaction["productId"],
            "autoRenewStatus": 1 if renews else 0,
            "environment": transaction["environment"],
        }

    def notification(self, kind, transaction, subtype=None, renewal_info=None):
        """An App Store Server Notification V2 body, with the transaction and renewal info signed inside it."""
        data = {
            "bundleId": APPLE_BUNDLE_ID,
            "appAppleId": APPLE_APP_ID,
            "environment": transaction["environment"],
            "signedTransactionInfo": self.sign(transaction),
        }
        if renewal_info:
            data["signedRenewalInfo"] = self.sign(renewal_info)
        payload = {
            "notificationType": kind,
            "subtype": subtype,
            "notificationUUID": str(uuid.uuid4()),
            "version": "2.0",
            "data": data,
        }
        return {"signedPayload": self.sign(payload)}
