"""S3 cache of generated Listen audio (apps/listen/storage.py).

Segments live in the private bucket settings.S3_LISTEN_BUCKET_NAME under listen/, which expires objects after
30 days. Nothing here holds credentials outside Django: the node stream server uploads through a presigned PUT
and players download through presigned GETs. Bucket names contain dots, so URLs must be path-style for TLS.
"""

import hashlib
import json

import boto3
import redis
from botocore.config import Config
from django.conf import settings

OUTPUT_FORMAT = "mp3_44100_64"
BYTES_PER_SECOND = 64000 / 8
URL_EXPIRATION_SECONDS = 6 * 60 * 60
CACHED_MARKER_SECONDS = 29 * 24 * 60 * 60

_client = None


def s3_client():
    global _client
    if _client is None:
        _client = boto3.client(
            "s3",
            aws_access_key_id=settings.S3_ACCESS_KEY,
            aws_secret_access_key=settings.S3_SECRET,
            region_name="us-east-1",
            config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
        )
    return _client


def _redis():
    return redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)


def cache_key(model, voice_id, voice_settings, language_code, text, previous_text="", next_text=""):
    """Identical requests to ElevenLabs produce interchangeable audio, so they share one cache entry."""
    payload = json.dumps(
        [model, voice_id, voice_settings, language_code, OUTPUT_FORMAT, text, previous_text, next_text],
        sort_keys=True,
        ensure_ascii=False,
    )
    return hashlib.sha1(payload.encode("utf-8")).hexdigest()


def object_key(key):
    """One S3 object per cache key. The key alone decides identity, so the same text in two feeds (a publisher's
    main and category feeds) shares one cached object, matching the shared listen:cached marker."""
    return f"listen/segments/{key}.mp3"


def cached_segment(key):
    """{"duration", "bytes"} for a segment node already uploaded, else None."""
    marker = _redis().get(f"listen:cached:{key}")
    if not marker:
        return None
    try:
        return json.loads(marker)
    except ValueError:
        return None


def presigned_get(s3_key):
    return s3_client().generate_presigned_url(
        "get_object",
        Params={"Bucket": settings.S3_LISTEN_BUCKET_NAME, "Key": s3_key},
        ExpiresIn=URL_EXPIRATION_SECONDS,
    )


def presigned_put(s3_key):
    return s3_client().generate_presigned_url(
        "put_object",
        Params={"Bucket": settings.S3_LISTEN_BUCKET_NAME, "Key": s3_key, "ContentType": "audio/mpeg"},
        ExpiresIn=URL_EXPIRATION_SECONDS,
    )


def duration_from_bytes(size):
    return round(size / BYTES_PER_SECOND, 2)
