"""
IP-based rate tracking for identifying automated/abusive request patterns.

Three tracking systems:
1. Reader rate tracking - counts requests to /reader/* endpoints
2. Fail2ban-style tracking - counts 404s and suspicious paths per IP
3. Attack payload detection - detects and auto-bans IPs sending malicious payloads

See apps/profile/middleware.py for middleware integration.
"""
import datetime
import json
import re
import time
from urllib.parse import unquote_plus

import redis
from django.conf import settings
from prometheus_client import Counter

# Prometheus metrics - low cardinality (safe for high-volume scraping)
READER_REQUESTS = Counter(
    "newsblur_reader_requests_total",
    "Total reader endpoint requests",
    ["endpoint", "user_agent"],
)
ABUSE_REQUESTS_TOTAL = Counter(
    "newsblur_rate_limit_abuse_requests_total",
    "Total requests from IPs exceeding threshold",
)

# Soft launch metrics - track what WOULD be denied without actually denying
WOULD_BE_DENIED_TOTAL = Counter(
    "newsblur_rate_limit_would_deny_total",
    "Total requests that would be denied if rate limiting was enabled",
)


class IPRateTracker:
    """
    Track request rates by IP address for /reader/* endpoints.

    Stores data in Redis using REDIS_STATISTICS_POOL (db 3):
    - ipr:{ip}:{endpoint}:{window} -> request count (TTL: 1 hour)
    - ipr:meta:{ip} -> hash with user info (TTL: 2 hours)
    - ipr:top:{window} -> sorted set of IPs by total count (TTL: 1 hour)
    - ipr:agg:{endpoint}:{user_agent}:{window} -> aggregate count (TTL: 1 hour)
    """

    WINDOW_MINUTES = 5
    TTL_SECONDS = 3600  # 1 hour
    META_TTL_SECONDS = 7200  # 2 hours
    ABUSE_THRESHOLD = 300  # requests per 5-min window

    # User agent classification patterns
    UA_PATTERNS = {
        "ios": ["newsblur iphone", "newsblur ipad", "newsblur ios"],
        "android": ["newsblur android", "newsblur-android"],
        "web": ["mozilla", "chrome", "safari", "firefox", "edge", "opera"],
        "api": ["python-requests", "python-urllib", "curl", "httpie", "wget", "okhttp", "java"],
    }

    def __init__(self):
        self._redis = None

    @property
    def redis(self):
        """Lazy Redis connection using statistics pool."""
        if self._redis is None:
            self._redis = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        return self._redis

    def get_current_window(self):
        """
        Return current 5-minute window as string (e.g., '202512161430').
        Windows align to 5-minute boundaries (00, 05, 10, 15, ...).
        """
        now = datetime.datetime.utcnow()
        # Round down to nearest 5 minutes
        minute = (now.minute // self.WINDOW_MINUTES) * self.WINDOW_MINUTES
        window_time = now.replace(minute=minute, second=0, microsecond=0)
        return window_time.strftime("%Y%m%d%H%M")

    def get_ip(self, request):
        """
        Extract client IP from request, handling proxy headers.
        X-Forwarded-For may contain multiple IPs; use the first (client).
        """
        forwarded = request.META.get("HTTP_X_FORWARDED_FOR")
        if forwarded:
            # X-Forwarded-For: client, proxy1, proxy2
            return forwarded.split(",")[0].strip()
        return request.META.get("REMOTE_ADDR", "unknown")

    def get_user_agent_type(self, request):
        """
        Classify User-Agent into: ios, android, web, api, or unknown.
        """
        ua = request.META.get("HTTP_USER_AGENT", "").lower()

        for ua_type, patterns in self.UA_PATTERNS.items():
            if any(pattern in ua for pattern in patterns):
                return ua_type

        return "unknown"

    def get_user_info(self, request):
        """
        Extract user info from request.
        Returns (user_id, username) tuple.
        """
        if hasattr(request, "user") and request.user.is_authenticated:
            return str(request.user.pk), request.user.username
        return "0", "anonymous"

    def track_request(self, request, endpoint):
        """
        Record a request for rate tracking.

        Args:
            request: Django HttpRequest
            endpoint: Endpoint shortcode (feeds, feed, river, starred, read)
        """
        ip = self.get_ip(request)
        ua_type = self.get_user_agent_type(request)
        user_id, username = self.get_user_info(request)
        method = request.method
        window = self.get_current_window()
        now_ts = str(int(time.time()))

        # Increment Prometheus counter (low cardinality)
        READER_REQUESTS.labels(endpoint=endpoint, user_agent=ua_type).inc()

        # Redis pipeline for atomic updates
        pipe = self.redis.pipeline()

        # 1. Per-IP per-endpoint counter
        ip_endpoint_key = f"ipr:{ip}:{endpoint}:{window}"
        pipe.incr(ip_endpoint_key)
        pipe.expire(ip_endpoint_key, self.TTL_SECONDS)

        # 2. Per-IP total counter (for top offenders)
        ip_total_key = f"ipr:{ip}:total:{window}"
        pipe.incr(ip_total_key)
        pipe.expire(ip_total_key, self.TTL_SECONDS)

        # 3. Update top offenders sorted set
        top_key = f"ipr:top:{window}"
        pipe.zincrby(top_key, 1, ip)
        pipe.expire(top_key, self.TTL_SECONDS)

        # 4. Aggregate counter (for Prometheus low-cardinality)
        agg_key = f"ipr:agg:{endpoint}:{ua_type}:{window}"
        pipe.incr(agg_key)
        pipe.expire(agg_key, self.TTL_SECONDS)

        # 5. Update IP metadata
        meta_key = f"ipr:meta:{ip}"
        meta_updates = {
            "user_id": user_id,
            "username": username,
            "user_agent": ua_type,
            "last_seen": now_ts,
        }
        # Add method to methods set (stored as comma-separated)
        pipe.hset(meta_key, mapping=meta_updates)
        pipe.hsetnx(meta_key, "first_seen", now_ts)
        pipe.expire(meta_key, self.META_TTL_SECONDS)

        # Execute pipeline
        results = pipe.execute()

        # Get the current total count for this IP (result index 2 is the incr result)
        current_count = results[2]  # ip_total_key incr result

        # Track abuse if threshold exceeded
        if current_count > self.ABUSE_THRESHOLD:
            ABUSE_REQUESTS_TOTAL.inc()

    def get_ip_metadata(self, ip):
        """
        Get metadata hash for an IP address.
        """
        meta_key = f"ipr:meta:{ip}"
        return self.redis.hgetall(meta_key)

    def get_top_offenders(self, window=None, limit=50):
        """
        Get top IPs by request count for the current or specified window.

        Returns list of dicts with ip, count, and metadata.
        """
        if window is None:
            window = self.get_current_window()

        top_key = f"ipr:top:{window}"
        top_ips = self.redis.zrevrange(top_key, 0, limit - 1, withscores=True)

        results = []
        for ip_bytes, count in top_ips:
            ip = ip_bytes if isinstance(ip_bytes, str) else ip_bytes.decode("utf-8")
            meta = self.get_ip_metadata(ip)
            results.append(
                {
                    "ip": ip,
                    "count": int(count),
                    "user_id": meta.get("user_id", "0"),
                    "username": meta.get("username", "unknown"),
                    "user_agent": meta.get("user_agent", "unknown"),
                    "first_seen": meta.get("first_seen"),
                    "last_seen": meta.get("last_seen"),
                }
            )

        return results

    def get_ip_counts(self, ip, window=None):
        """
        Get per-endpoint counts for a specific IP in the current window.
        """
        if window is None:
            window = self.get_current_window()

        endpoints = ["feeds", "feed", "refresh", "river", "starred", "read"]
        counts = {}

        for endpoint in endpoints:
            key = f"ipr:{ip}:{endpoint}:{window}"
            count = self.redis.get(key)
            counts[endpoint] = int(count) if count else 0

        total_key = f"ipr:{ip}:total:{window}"
        total = self.redis.get(total_key)
        counts["total"] = int(total) if total else 0

        return counts

    def is_rate_limited(self, ip, window=None):
        """
        Check if an IP exceeds the rate limit threshold.

        Currently returns True/False for tracking only.
        When IP_RATE_LIMITING_ENABLED is True, this can be used
        to actually block requests.
        """
        if window is None:
            window = self.get_current_window()

        total_key = f"ipr:{ip}:total:{window}"
        count = self.redis.get(total_key)

        if count is None:
            return False

        threshold = getattr(settings, "IP_RATE_LIMIT_THRESHOLD", self.ABUSE_THRESHOLD)
        return int(count) > threshold

    def track_would_be_denied(self, request, endpoint):
        """
        Record that a request WOULD have been denied if rate limiting was enforced.

        This stores detailed information in Redis for debugging and exposes
        metrics in Prometheus for Grafana dashboards.

        Called by middleware when rate limit is exceeded but enforcement is disabled.
        """
        ip = self.get_ip(request)
        ua_type = self.get_user_agent_type(request)
        user_id, username = self.get_user_info(request)
        window = self.get_current_window()
        now_ts = str(int(time.time()))

        # Increment Prometheus counter
        WOULD_BE_DENIED_TOTAL.inc()

        # Get current request count for this IP
        total_key = f"ipr:{ip}:total:{window}"
        count = self.redis.get(total_key)
        request_count = int(count) if count else 0

        # Store denial event in Redis list (for debugging/investigation)
        # Key: ipr:denied:{window} -> list of JSON denial records
        denial_key = f"ipr:denied:{window}"
        denial_record = {
            "ip": ip,
            "user_id": user_id,
            "username": username,
            "user_agent": ua_type,
            "endpoint": endpoint,
            "request_count": request_count,
            "threshold": self.ABUSE_THRESHOLD,
            "timestamp": now_ts,
            "path": request.path[:200],  # Truncate long paths
        }

        pipe = self.redis.pipeline()

        # Add to denial list (keep last 1000 per window)
        pipe.lpush(denial_key, json.dumps(denial_record))
        pipe.ltrim(denial_key, 0, 999)
        pipe.expire(denial_key, self.TTL_SECONDS)

        # Track unique IPs that would be denied in this window
        denied_ips_key = f"ipr:denied_ips:{window}"
        pipe.sadd(denied_ips_key, ip)
        pipe.expire(denied_ips_key, self.TTL_SECONDS)

        # Store per-IP denial count (how many requests this IP was denied)
        denied_count_key = f"ipr:denied_count:{ip}:{window}"
        pipe.incr(denied_count_key)
        pipe.expire(denied_count_key, self.TTL_SECONDS)

        pipe.execute()

    def get_denied_requests(self, window=None, limit=100):
        """
        Get list of requests that would have been denied.

        Useful for debugging and investigation when users complain.
        Returns list of denial records with full details.
        """
        if window is None:
            window = self.get_current_window()

        denial_key = f"ipr:denied:{window}"
        denials = self.redis.lrange(denial_key, 0, limit - 1)

        results = []
        for denial_bytes in denials:
            denial = denial_bytes if isinstance(denial_bytes, str) else denial_bytes.decode("utf-8")
            try:
                results.append(json.loads(denial))
            except Exception:
                pass

        return results

    def get_denied_ips_summary(self, window=None):
        """
        Get summary of IPs that would have been denied.

        Returns dict with IP -> {count, username, user_agent, last_endpoint}.
        """
        if window is None:
            window = self.get_current_window()

        denied_ips_key = f"ipr:denied_ips:{window}"
        denied_ips = self.redis.smembers(denied_ips_key)

        results = {}
        for ip_bytes in denied_ips:
            ip = ip_bytes if isinstance(ip_bytes, str) else ip_bytes.decode("utf-8")
            denied_count_key = f"ipr:denied_count:{ip}:{window}"
            count = self.redis.get(denied_count_key)
            meta = self.get_ip_metadata(ip)

            # Decode metadata
            username = meta.get(b"username", meta.get("username", b"unknown"))
            if isinstance(username, bytes):
                username = username.decode("utf-8")
            ua = meta.get(b"user_agent", meta.get("user_agent", b"unknown"))
            if isinstance(ua, bytes):
                ua = ua.decode("utf-8")

            results[ip] = {
                "denied_count": int(count) if count else 0,
                "username": username,
                "user_agent": ua,
            }

        return results


# Prometheus metrics for fail2ban-style tracking
SCANNER_404_TOTAL = Counter(
    "newsblur_scanner_404_total",
    "Total 404 responses by IP category",
    ["category"],  # suspicious_path, normal_404
)


class ScannerTracker:
    """
    Fail2ban-style tracker for detecting vulnerability scanners.

    Tracks:
    - 404 responses per IP
    - Requests to suspicious paths (.php, wp-*, xmlrpc, etc.)

    Redis keys (db 3, REDIS_STATISTICS_POOL):
    - scan:404:{ip}:{window} -> 404 count
    - scan:sus:{ip}:{window} -> suspicious path count
    - scan:top:{window} -> sorted set of IPs by 404 count
    - scan:meta:{ip} -> hash with sample paths, first/last seen
    """

    WINDOW_MINUTES = 5
    TTL_SECONDS = 3600  # 1 hour
    META_TTL_SECONDS = 7200  # 2 hours
    SCANNER_THRESHOLD = 10  # 404s per 5-min window to be flagged

    # Patterns that indicate vulnerability scanning
    SUSPICIOUS_PATTERNS = [
        r"\.php$",
        r"\.asp$",
        r"\.aspx$",
        r"\.jsp$",
        r"\.cgi$",
        r"^/wp-",
        r"/wordpress",
        r"/xmlrpc",
        r"/admin",
        r"/phpmyadmin",
        r"/mysql",
        r"/backup",
        r"/config",
        r"/\.env",
        r"/\.git",
        r"/shell",
        r"/eval",
        r"/cmd",
    ]

    def __init__(self):
        self._redis = None
        self._suspicious_re = re.compile("|".join(self.SUSPICIOUS_PATTERNS), re.IGNORECASE)

    @property
    def redis(self):
        if self._redis is None:
            self._redis = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        return self._redis

    def get_current_window(self):
        now = datetime.datetime.utcnow()
        minute = (now.minute // self.WINDOW_MINUTES) * self.WINDOW_MINUTES
        window_time = now.replace(minute=minute, second=0, microsecond=0)
        return window_time.strftime("%Y%m%d%H%M")

    def get_ip(self, request):
        forwarded = request.META.get("HTTP_X_FORWARDED_FOR")
        if forwarded:
            return forwarded.split(",")[0].strip()
        return request.META.get("REMOTE_ADDR", "unknown")

    def is_suspicious_path(self, path):
        """Check if path matches vulnerability scanning patterns."""
        return bool(self._suspicious_re.search(path))

    def track_404(self, request, path):
        """
        Track a 404 response for potential scanner detection.

        Call this from middleware when response.status_code == 404.
        """
        ip = self.get_ip(request)
        window = self.get_current_window()
        now_ts = str(int(time.time()))
        is_suspicious = self.is_suspicious_path(path)

        # Increment Prometheus counter
        category = "suspicious_path" if is_suspicious else "normal_404"
        SCANNER_404_TOTAL.labels(category=category).inc()

        pipe = self.redis.pipeline()

        # 1. Increment 404 counter for this IP
        key_404 = f"scan:404:{ip}:{window}"
        pipe.incr(key_404)
        pipe.expire(key_404, self.TTL_SECONDS)

        # 2. If suspicious, also track suspicious count
        if is_suspicious:
            key_sus = f"scan:sus:{ip}:{window}"
            pipe.incr(key_sus)
            pipe.expire(key_sus, self.TTL_SECONDS)

        # 3. Update top scanners sorted set
        top_key = f"scan:top:{window}"
        pipe.zincrby(top_key, 1, ip)
        pipe.expire(top_key, self.TTL_SECONDS)

        # 4. Update metadata with sample path
        meta_key = f"scan:meta:{ip}"
        pipe.hset(meta_key, "last_path", path[:200])  # Truncate long paths
        pipe.hset(meta_key, "last_seen", now_ts)
        pipe.hsetnx(meta_key, "first_seen", now_ts)
        pipe.hsetnx(meta_key, "first_path", path[:200])
        pipe.expire(meta_key, self.META_TTL_SECONDS)

        pipe.execute()

    def get_ip_metadata(self, ip):
        meta_key = f"scan:meta:{ip}"
        return self.redis.hgetall(meta_key)

    def get_top_scanners(self, window=None, limit=50):
        """Get IPs with most 404s in the current window."""
        if window is None:
            window = self.get_current_window()

        top_key = f"scan:top:{window}"
        top_ips = self.redis.zrevrange(top_key, 0, limit - 1, withscores=True)

        results = []
        for ip_bytes, count in top_ips:
            ip = ip_bytes if isinstance(ip_bytes, str) else ip_bytes.decode("utf-8")
            meta = self.get_ip_metadata(ip)

            # Get suspicious count
            sus_key = f"scan:sus:{ip}:{window}"
            sus_count = self.redis.get(sus_key)

            results.append(
                {
                    "ip": ip,
                    "total_404s": int(count),
                    "suspicious_404s": int(sus_count) if sus_count else 0,
                    "last_path": meta.get("last_path", "unknown"),
                    "first_path": meta.get("first_path", "unknown"),
                    "first_seen": meta.get("first_seen"),
                    "last_seen": meta.get("last_seen"),
                }
            )

        return results

    def is_scanner(self, ip, window=None):
        """
        Check if IP is flagged as a scanner.

        For now just returns True/False for tracking.
        When blocking is enabled, this can be used to block requests.
        """
        if window is None:
            window = self.get_current_window()

        key_404 = f"scan:404:{ip}:{window}"
        count = self.redis.get(key_404)

        if count is None:
            return False

        return int(count) >= self.SCANNER_THRESHOLD


# Prometheus metrics for attack detection
ATTACK_DETECTED_TOTAL = Counter(
    "newsblur_attack_detected_total",
    "Total attack payloads detected and blocked",
    ["attack_type"],
)
ATTACK_BANNED_CHECK_TOTAL = Counter(
    "newsblur_attack_banned_check_total",
    "Total requests blocked from already-banned IPs",
)


def _get_client_ip(request):
    """
    Extract the real client IP from a proxied request.

    Relies on the known proxy chain: Client → HAProxy → Nginx → Django.
    HAProxy's ``option forwardfor`` appends the real TCP source IP.
    Nginx's ``$proxy_add_x_forwarded_for`` appends ``$remote_addr``.
    Because nginx has ``set_real_ip_from 0.0.0.0/0``, its appended value
    is the *leftmost* XFF entry (spoofable).  The real client IP is
    therefore always second-to-last (index -2): the entry HAProxy added
    from the TCP connection, which cannot be forged at the HTTP layer.

    If XFF has fewer than 2 entries (e.g. dev without HAProxy), fall back
    to the single entry or REMOTE_ADDR.
    """
    forwarded = request.META.get("HTTP_X_FORWARDED_FOR")
    if forwarded:
        parts = [p.strip() for p in forwarded.split(",")]
        if len(parts) >= 2:
            return parts[-2]
        return parts[0]
    return request.META.get("REMOTE_ADDR", "unknown")


class AttackDetector:
    """
    Detect malicious payloads in request query strings, POST bodies, and paths.

    Auto-bans IPs for 24 hours on first detection. Subsequent requests from
    banned IPs are rejected immediately without payload inspection.

    Redis keys (db 3, REDIS_STATISTICS_POOL):
    - atk:ban:{ip} -> "1" with TTL (banned IP marker)
    - atk:log:{ip} -> hash with attack details (for investigation)
    """

    BAN_TTL_SECONDS = 86400  # 24 hours

    # Content types where POST body should be scanned (text-based only).
    # Multipart uploads (file uploads) are skipped to avoid buffering large files.
    SCANNABLE_CONTENT_TYPES = (
        "application/x-www-form-urlencoded",
        "application/json",
        "text/plain",
        "text/xml",
        "application/xml",
    )

    # Max POST body bytes to read for scanning
    MAX_BODY_SCAN_BYTES = 8192

    # Attack patterns grouped by type for logging.
    # Keep these tight to avoid false positives on legitimate content
    # (archived web pages, RSS feeds, user comments often contain code snippets).
    ATTACK_PATTERNS = {
        "jndi": [
            r"\$\{jndi:",  # Log4Shell: ${jndi:ldap://...} (was \$\{ which matched JS template literals)
        ],
        "xss": [
            r"<\s*script[^a-zA-Z]",  # <script> tags (require non-alpha after to avoid <scriptName)
        ],
        "sqli": [
            r"(?:UNION\s+(?:ALL\s+)?SELECT)",  # UNION SELECT
            r"(?:;\s*DROP\s+TABLE)",  # ; DROP TABLE
        ],
        "traversal": [
            r"\.\./\.\./\.\./",  # Path traversal (require 3+ levels to reduce false positives)
        ],
        "nullbyte": [
            r"\x00",  # Null byte injection
            r"%00",  # URL-encoded null byte
        ],
    }

    def __init__(self):
        self._redis = None
        # Compile all patterns into a single regex for fast matching, plus keep
        # individual type regexes for classification
        self._type_patterns = {}
        all_patterns = []
        for attack_type, patterns in self.ATTACK_PATTERNS.items():
            combined = "|".join(patterns)
            self._type_patterns[attack_type] = re.compile(combined, re.IGNORECASE)
            all_patterns.extend(patterns)
        self._combined_re = re.compile("|".join(all_patterns), re.IGNORECASE)

    @property
    def redis(self):
        if self._redis is None:
            self._redis = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        return self._redis

    def get_ip(self, request):
        return _get_client_ip(request)

    def is_banned(self, ip):
        """Check if an IP is currently banned. Fast Redis GET."""
        try:
            return bool(self.redis.get(f"atk:ban:{ip}"))
        except Exception:
            return False

    def ban_ip(self, ip, attack_type, payload_sample, request):
        """Ban an IP and store attack details for investigation."""
        pipe = self.redis.pipeline()

        # Set ban marker with TTL
        ban_key = f"atk:ban:{ip}"
        pipe.set(ban_key, "1", ex=self.BAN_TTL_SECONDS)

        # Store attack log for investigation
        log_key = f"atk:log:{ip}"
        log_data = {
            "attack_type": attack_type,
            "payload_sample": payload_sample[:500],
            "path": request.path[:200],
            "user_agent": request.META.get("HTTP_USER_AGENT", "")[:200],
            "banned_at": str(int(time.time())),
        }
        pipe.hset(log_key, mapping=log_data)
        pipe.expire(log_key, self.BAN_TTL_SECONDS)

        pipe.execute()

    def classify_attack(self, payload):
        """Return the attack type if payload matches, or None."""
        for attack_type, pattern in self._type_patterns.items():
            if pattern.search(payload):
                return attack_type
        return None

    def _check_payload(self, payload):
        """Check a single payload string for attack patterns. Returns (attack_type, sample) or (None, None)."""
        if payload and self._combined_re.search(payload):
            attack_type = self.classify_attack(payload)
            if attack_type:
                return attack_type, payload[:200]
        return None, None

    def check_request(self, request):
        """
        Inspect request for malicious payloads.

        Checks raw and URL-decoded query strings, URL path, and POST body.
        Returns (attack_type, payload_sample) if attack detected, or (None, None).
        """
        # Check query string (raw first, then decoded to catch encoded payloads).
        # unquote_plus handles both %XX encoding and + as space (form encoding).
        query_string = request.META.get("QUERY_STRING", "")
        if query_string:
            result = self._check_payload(query_string)
            if result[0]:
                return result
            decoded_qs = unquote_plus(query_string)
            if decoded_qs != query_string:
                result = self._check_payload(decoded_qs)
                if result[0]:
                    return result

        # Check URL path
        result = self._check_payload(request.path)
        if result[0]:
            return result

        # Check POST body for text-based content types only.
        # Skip multipart/form-data (file uploads) to avoid buffering large files.
        if request.method == "POST":
            content_type = request.META.get("CONTENT_TYPE", "").split(";")[0].strip().lower()
            if content_type in self.SCANNABLE_CONTENT_TYPES:
                try:
                    # Scan first MAX_BODY_SCAN_BYTES of any text POST. Django buffers
                    # the full body for these content types anyway (request.POST / json),
                    # so this adds no extra memory cost. Slicing limits regex work, not I/O.
                    body = request.body[: self.MAX_BODY_SCAN_BYTES].decode("utf-8", errors="replace")
                    result = self._check_payload(body)
                    if result[0]:
                        return result
                    # Decode form bodies with unquote_plus (+ → space, %XX → char).
                    # jQuery $.ajax default POSTs are form-encoded, so attack payloads
                    # like %27+OR+1%3D1 must be decoded to ' OR 1=1 for regex matching.
                    if content_type == "application/x-www-form-urlencoded":
                        decoded_body = unquote_plus(body)
                        if decoded_body != body:
                            result = self._check_payload(decoded_body)
                            if result[0]:
                                return result
                except Exception:
                    pass

        return None, None
