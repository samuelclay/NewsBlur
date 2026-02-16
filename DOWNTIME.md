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

## Continuous External Monitoring

To prove the site is up/down over an extended period:

```bash
docker exec -t newsblur_web python manage.py monitor_uptime --interval 10
```

This runs DNS, HTTP, TCP, and TLS checks every N seconds from inside Docker and logs anomalies with extra diagnostics.
