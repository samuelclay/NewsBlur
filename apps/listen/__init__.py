"""Listen: stories read aloud with ElevenLabs text to speech.

Django builds per-story manifests and segment jobs and enforces Premium Archive limits; the node stream server
(node/listen.coffee) streams each segment from ElevenLabs and caches it in S3.
"""

default_app_config = "apps.listen.apps.ListenConfig"
