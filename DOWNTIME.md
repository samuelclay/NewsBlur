# Downtime Investigation

When the user reports downtime (e.g., StatusCake alerts, user complaints, or "the site is down"), immediately run the health check script.

## Health Check Script

```bash
# First: quick HAProxy overview (fastest, ~4s)
./utils/check_health.sh --haproxy

# Then: full infrastructure check (~13s, all 45 servers in parallel)
./utils/check_health.sh

# Quick mode: one server per group (~7s)
./utils/check_health.sh --quick

# Check a specific group: web, postgres, mongo, redis, node, task, consul, elasticsearch
./utils/check_health.sh --group web
```

This script runs from the local machine, SSHes into all production servers via `utils/ssh_hz.sh`, and checks:
- **HAProxy**: Queries the stats socket on `hwww` for all backend statuses (UP/DOWN/MAINT)
- **Web servers** (`happ-web-01` through `06`): Curls `localhost:8000/_haproxychk`
- **Databases**: Hits Flask health monitor on port 5579 (`/db_check/postgres`, `/db_check/mongo`, `/db_check/redis_*`, `/db_check/elasticsearch`)
- **Node services**: Checks Docker container status on `hnode-*` servers
- **Task workers**: Checks Docker container status on `htask-*` servers
- **Consul**: Checks leader status on `hdb-consul-*` servers

## If All Checks Pass (False Alarm)

If all checks pass but StatusCake still reports downtime, the issue is likely **DNS** (NewsBlur uses DNSimple nameservers which have had intermittent failures). Check with:

```bash
# Test DNS resolution across multiple resolvers
for resolver in 8.8.8.8 1.1.1.1 9.9.9.9; do echo "$resolver: $(dig +short @$resolver newsblur.com A)"; done

# Test authoritative nameservers directly
for ns in ns1.dnsimple.com ns2.dnsimple-edge.net ns3.dnsimple.com ns4.dnsimple-edge.org; do
    echo "$ns: $(dig +short @$ns newsblur.com A) ($(dig @$ns newsblur.com A +noall +stats 2>&1 | grep 'Query time'))"
done
```

Known DNS issues (diagnosed 2026-02-10):
- DNSimple edge nameservers (ns2, ns4) can go completely unresponsive
- Working nameservers (ns1, ns3) can degrade to ~1,500ms response times (should be <50ms)
- Cloudflare DNS (1.1.1.1) is particularly aggressive about timeouts, causing ~10% resolution failures when nameservers are slow
- StatusCake probes hitting dead/slow nameservers report false downtime

## All Web Servers Flap Together

When every `app_django` server in the HAProxy overview shows a short "since", or they all go DOWN and come back within a minute or two while the databases check healthy, one likely cause is that the gunicorn workers were all busy at once: `/_haproxychk` does no work of its own, so a free worker answers it at once. Check the reason HAProxy gives for the failed checks (`L7TOUT` is a timeout; a refused connection points at a restart or the network instead) and the load on the web servers before settling on traffic.

Every request is counted by address in one-minute windows (`RequestRateTracker` in `utils/ip_rate_tracker.py`), kept for an hour. The kinds are `page` (signed-out blurblog and shared-story pages), `anonymous` (every other signed-out request) and `user` (signed-in). To see who sent the most:

```bash
./utils/ssh_hz.sh -n happ-web-01 "docker exec newsblur_web python manage.py shell -c \"
from utils.ip_rate_tracker import RequestRateTracker
tracker = RequestRateTracker()
print(tracker.get_top_addresses('page', limit=10))                         # this minute
print(tracker.get_top_addresses('page', window='202611280009', limit=10))  # a past minute, UTC
print(tracker.get_counts('203.0.113.7'))                                   # one address, this minute
\""
```

Signed-out page loads past `IP_RATE_LIMIT_ANONYMOUS_PER_MINUTE` are refused with a 429 and logged as `BLOCKED ... Rate Limit`. Other signed-out requests past it are logged as `WOULD BLOCK` and served until `IP_RATE_LIMITING_ANONYMOUS_ENABLED` is turned on. Grafana graphs both under "Rate Limited Requests" and "Requests Counted by Kind". `IP_RATE_LIMITING_ENABLED` turns all refusing off.

## Continuous External Monitoring

To prove the site is up/down over an extended period:

```bash
docker exec -t newsblur_web python manage.py monitor_uptime --interval 10
```

This runs DNS, HTTP, TCP, and TLS checks every N seconds from inside Docker and logs anomalies with extra diagnostics.
