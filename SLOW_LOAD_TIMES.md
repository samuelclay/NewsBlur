# Slow Load Times Investigation

When load times are elevated but the site isn't down. The key metric is `feed_loadtimes_1min` which measures average web request time for loading stories (via `load_single_feed` and `load_river_stories`). Individual feed requests should stay between 100-150ms at all times. Anything over 150ms is suspect and worth investigating.

## Grafana (Source of Truth)

The "NewsBlur Load Times" dashboard at `https://metrics.newsblur.com` shows `feed_loadtimes_1min` (green line) and the hourly mean (yellow line). This is the graph to watch.

- **Grafana URL**: `https://metrics.newsblur.com` (requires auth, proxied through HAProxy `db_metrics` backend)
- **Prometheus scrape interval**: 30 seconds (configured in `docker/prometheus/prometheus.docker.yml`)
- **Data source**: Prometheus scrapes `https://haproxy/monitor/load-times` which reads from Redis statistics keys (`PLT:{unix_timestamp}:s` for count, `PLT:{unix_timestamp}:a` for accumulated time)
- **What it measures**: Wall clock time of `load_single_feed` and `load_river_stories` web requests, recorded via `RStats.add("page_load")` in `apps/reader/views.py`

Since Grafana requires authentication and can't be fetched via CLI, use the shell commands below to get the same data directly from Redis.

## Quick Assessment

```bash
# Per-minute load times for the last 30 minutes (run on any web server)
./utils/ssh_hz.sh -n happ-web-01 'docker exec -t newsblur_web python manage.py shell -c "
import redis, datetime
from django.conf import settings
from apps.statistics.rstats import RStats, round_time
r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
now = datetime.datetime.now()
prefix = RStats.stats_type(\"page_load\")
print(\"Min ago | Count | AvgTime\")
for m in range(30):
    dt = now - datetime.timedelta(minutes=m)
    minute = round_time(dt=dt, round_to=60)
    key = \"%s:%s\" % (prefix, minute.strftime(\"%s\"))
    count = r.get(\"%s:s\" % key)
    avg = r.get(\"%s:a\" % key)
    if count is not None and avg is not None:
        c = int(count)
        a = float(avg)
        per_req = round(a / max(1, c), 3)
        marker = \"  <<<\" if per_req > 0.16 else \"\"
        print(f\"{m:>3}m ago | {c:>5} | {per_req}{marker}\")
"'

# Hourly load times for the last 24 hours
./utils/ssh_hz.sh -n happ-web-01 'docker exec -t newsblur_web python manage.py shell -c "
from apps.statistics.models import MStatistics
import json
sites = MStatistics.get(\"sites_loaded\")
times = MStatistics.get(\"avg_time_taken\")
if sites: sites = json.loads(sites)
if times: times = json.loads(times)
if sites and times:
    print(\"Hour | Sites | AvgTime\")
    for i, (s, t) in enumerate(zip(sites, times)):
        label = str(23-i) + \"h ago\" if i < 23 else \"now\"
        print(f\"{label:>8} | {s:>6} | {t}\")
"'

# Compare spike rates between two time periods
# Change the hour ranges to compare pre/post deploy, day vs night, etc.
./utils/ssh_hz.sh -n happ-web-01 'docker exec -t newsblur_web python manage.py shell -c "
import redis, datetime
from django.conf import settings
from apps.statistics.rstats import RStats, round_time
r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
now = datetime.datetime.now()
prefix = RStats.stats_type(\"page_load\")
for label, start_h, end_h in [(\"Period A\", 12, 24), (\"Period B\", 0, 12)]:
    spike = normal = 0
    for m in range(start_h*60, end_h*60):
        dt = now - datetime.timedelta(minutes=m)
        minute = round_time(dt=dt, round_to=60)
        key = \"%s:%s\" % (prefix, minute.strftime(\"%s\"))
        count = r.get(\"%s:s\" % key)
        avg = r.get(\"%s:a\" % key)
        if count is not None and avg is not None:
            c = int(count); a = float(avg)
            if round(a / max(1, c), 3) > 0.16: spike += 1
            else: normal += 1
    total = spike + normal
    print(f\"{label} ({start_h}-{end_h}h ago): {spike}/{total} minutes > 0.16s = {100*spike//max(1,total)}%\")
"'
```

## Prometheus Endpoints

All Prometheus endpoints are served from happ-web-01 only (HAProxy `metrics` backend). Time them to find slow scrapers:

```bash
# Time ALL Prometheus endpoints at once
./utils/ssh_hz.sh -n happ-web-01 'docker exec -t newsblur_web bash -c "for ep in app-servers app-times classifiers clustering db-times feeds load-times stories task-codes task-pipeline task-servers task-times trending-feeds trending-subscriptions updates users; do t1=\$(date +%s%N); curl -s http://127.0.0.1:8000/monitor/\$ep > /dev/null; t2=\$(date +%s%N); echo \"\$ep: \$(( (\$t2 - \$t1) / 1000000 ))ms\"; done"'

# Fetch a specific endpoint's data
./utils/ssh_hz.sh -n happ-web-01 'docker exec -t newsblur_web bash -c "curl -s http://127.0.0.1:8000/monitor/load-times"'

# Key endpoints and what they show:
#   load-times:              feed_loadtimes_1min, feed_loadtimes_avg_hour, feeds_loaded_hour
#   task-times:              per-celery-server average task duration
#   task-pipeline:           feed_fetch / feed_process / page / icon / total breakdown
#   db-times:                per-database accumulated seconds (sql, mongo, redis_*, task_*)
#   app-times:               per-web-server average page load
#   trending-feeds:          cached 1hr, top stories/feeds/long reads
#   trending-subscriptions:  cached 1hr, subscription velocity
```

## Server Load

```bash
# Web servers (should be < 1.0)
for i in 01 02 03 04 05 06; do echo -n "happ-web-$i: " && ./utils/ssh_hz.sh -n happ-web-$i 'uptime'; done

# Task/celery servers (normal range 5-10)
for i in 01 02 03 04 05 06 07 08 09 10 11 12 13 14; do echo -n "celery-$i: " && ./utils/ssh_hz.sh -n htask-celery-$i 'uptime'; done

# Work servers (should be < 1.0)
for i in 1 2 3; do echo -n "work-$i: " && ./utils/ssh_hz.sh -n htask-work-$i 'uptime'; done
```

## MongoDB

The stories collection (467GB, 134M docs) is the primary bottleneck. WiredTiger cache is 125GB, so the full working set doesn't fit in cache. Disk I/O from cache misses is the normal source of load time variability.

```bash
# Server load and memory
./utils/ssh_hz.sh -n hdb-mongo-primary-2 'uptime && free -h'

# Swap check (swappiness should be 1, swap usage should be near 0)
./utils/ssh_hz.sh -n hdb-mongo-primary-2 'cat /proc/sys/vm/swappiness && swapon --show'

# MongoDB process swap (VmSwap should be near 0)
./utils/ssh_hz.sh -n hdb-mongo-primary-2 'cat /proc/$(pgrep -f mongod | head -1)/status 2>/dev/null | grep -E "VmRSS|VmSwap"'

# Ops/sec and WiredTiger cache health (5-second sample)
./utils/ssh_hz.sh -n hdb-mongo-primary-2 'docker exec -t mongo mongo --quiet --eval "
var ss1 = db.serverStatus();
sleep(5000);
var ss2 = db.serverStatus();
print(\"ops/sec:\");
print(\"  inserts: \" + Math.round((ss2.opcounters.insert-ss1.opcounters.insert)/5));
print(\"  queries: \" + Math.round((ss2.opcounters.query-ss1.opcounters.query)/5));
print(\"  updates: \" + Math.round((ss2.opcounters.update-ss1.opcounters.update)/5));
print(\"  deletes: \" + Math.round((ss2.opcounters.delete-ss1.opcounters.delete)/5));
var wt1 = ss1.wiredTiger.cache;
var wt2 = ss2.wiredTiger.cache;
print(\"WiredTiger:\");
print(\"  pages read/s: \" + Math.round((wt2[\"pages read into cache\"]-wt1[\"pages read into cache\"])/5));
print(\"  dirty: \" + Math.round(wt2[\"tracked dirty bytes in the cache\"]/1024/1024) + \"MB\");
print(\"  cache: \" + Math.round(wt2[\"bytes currently in the cache\"]/1024/1024/1024) + \"GB / \" + Math.round(wt2[\"maximum bytes configured\"]/1024/1024/1024) + \"GB\");
" newsblur'

# Slow operations (>1 second)
./utils/ssh_hz.sh -n hdb-mongo-primary-2 'docker exec -t mongo mongo --quiet --eval "
var ops = db.currentOp({\"active\":true,\"secs_running\":{\"\$gt\":1}}).inprog;
print(\"Slow ops: \" + ops.length);
ops.forEach(function(o){
  print(o.secs_running + \"s | \" + o.ns + \" | \" + o.op + \" | \" + (o.command?JSON.stringify(o.command).substring(0,200):\"\"));
});
" newsblur'

# Active operations snapshot (all)
./utils/ssh_hz.sh -n hdb-mongo-primary-2 'docker exec -t mongo mongo --quiet --eval "
var ops = db.currentOp({\"active\":true}).inprog;
var summary = {};
ops.forEach(function(op) {
  var key = op.op + \":\" + (op.ns || \"none\");
  if (!summary[key]) summary[key] = {count:0};
  summary[key].count++;
});
Object.keys(summary).sort(function(a,b){return summary[b].count-summary[a].count;}).forEach(function(k){
  print(\"  \" + k + \": \" + summary[k].count);
});
" newsblur'

# Write breakdown by collection (from oplog, 5-second sample)
./utils/ssh_hz.sh -n hdb-mongo-primary-2 'docker exec -t mongo mongo --quiet --eval "
var fiveSecsAgo = Timestamp(Math.floor(Date.now()/1000) - 5, 0);
var ops = db.getSiblingDB(\"local\").oplog.rs.aggregate([
  {\"\$match\":{\"ts\":{\"\$gt\":fiveSecsAgo}}},
  {\"\$group\":{\"_id\":{\"\$concat\":[\"\$op\",\":\",\"\$ns\"]},\"count\":{\"\$sum\":1}}}
]).toArray();
ops.sort(function(a,b){return b.count-a.count;});
print(\"Writes in last 5s:\");
ops.forEach(function(o){print(\"  \"+o._id+\": \"+o.count);});
" newsblur'

# Disk I/O (look at bi/bo columns and wa% for I/O wait)
./utils/ssh_hz.sh -n hdb-mongo-primary-2 'vmstat 1 3'
```

### MongoDB Red Flags
- **VmSwap > 100MB**: MongoDB pages swapped out. Fix: `sysctl vm.swappiness=1` then `swapoff -a && swapon -a`
- **pages read/s > 10,000**: WiredTiger cache thrashing. Normal for spikes; sustained means working set exceeds cache.
- **bi > 200,000** in vmstat: Heavy disk reads, likely from cache misses or swap
- **dirty > 1GB**: Write pressure building up, checkpoint may stall reads

## Redis

```bash
# Redis story server slow log (threshold: 1,000,000µs = 1s)
./utils/ssh_hz.sh -n hdb-redis-story-1 'docker exec -t redis-story redis-cli slowlog get 10'

# Redis story server stats
./utils/ssh_hz.sh -n hdb-redis-story-1 'docker exec -t redis-story redis-cli info stats 2>&1 | grep -E "ops_per_sec|evicted"'

# Redis story server memory
./utils/ssh_hz.sh -n hdb-redis-story-1 'docker exec -t redis-story redis-cli info memory 2>&1 | grep -E "used_memory_human|maxmemory_human|mem_fragmentation"'

# Celery queue depth (update_feeds is the main queue)
./utils/ssh_hz.sh -n hdb-redis-user-1 'docker exec -t redis-user redis-cli llen update_feeds'
```

### Redis Red Flags
- **SUNIONSTORE in slowlog**: User with 1000+ feeds blocking Redis for 1+ seconds. Check `RS:{user_id}` key.
- **Queue depth growing**: update_feeds > 200 means tasks are backing up (check celery server load)
- **evicted_keys > 0**: Redis running out of memory

## Celery/Task Servers

```bash
# Clustering task durations (last 5 min on one server)
./utils/ssh_hz.sh -n htask-celery-01 'docker logs --since=5m task-celery 2>&1 | grep "compute-story-clusters.*succeeded" | grep -oP "succeeded in \K[0-9.]+" | awk "{sum+=\$1; count++; if(\$1>5) slow++} END {if(count) print \"avg=\"sum/count\"s count=\"count\" slow(>5s)=\"slow; else print \"none\"}"'

# Feed update task durations
./utils/ssh_hz.sh -n htask-celery-01 'docker logs --since=5m task-celery 2>&1 | grep "update-feeds.*succeeded" | grep -oP "succeeded in \K[0-9.]+" | awk "{sum+=\$1; count++} END {if(count) print \"avg=\"sum/count\"s count=\"count; else print \"none\"}"'

# Recent clustering activity
./utils/ssh_hz.sh -n htask-celery-01 'docker logs --since=5m task-celery 2>&1 | grep -i "Clustering:" | tail -10'
```

## Common Causes

### Swap thrashing (FIXED March 2026)
MongoDB primary had swappiness=60 causing 1.1GB of process memory to be swapped out. Every access to swapped pages caused ~10ms disk I/O stalls. Fixed by setting swappiness=1 and clearing swap. Persisted in `/etc/sysctl.d/99-swappiness.conf`. Ansible swap role default is also 1 (`ansible/roles/swap/defaults/main.yml`).

### Prometheus endpoint too slow
Prometheus scrapes every 15 seconds from happ-web-01. Slow endpoints cause periodic load spikes. The trending-feeds and trending-subscriptions endpoints are cached for 1 hour in Redis (`monitor:trending_feeds:cache`, `monitor:trending_subs:cache`). If a new endpoint is slow (>100ms), consider caching it similarly.

### WiredTiger cache pressure
The stories collection (467GB) far exceeds the WiredTiger cache (125GB). Normal page reads are ~5,000/s; during spikes it can hit 10,000+/s. Brief spikes (1-2 minutes) are normal. Sustained high page reads with elevated load times indicate either a working set shift or a new access pattern hitting cold pages.

### Large clustering tasks
Clustering tasks run on the `update_feeds` queue alongside feed updates. Large feeds (10K+ candidates) can take 10-23 seconds for title matching. If many large feeds cluster simultaneously, they tie up celery workers. Check with the clustering task duration commands above.

### SUNIONSTORE blocking Redis
Users with 1000+ feeds trigger `SUNIONSTORE` on `RS:{user_id}` which unions all per-feed read-story sets. This blocks the Redis story server for 1+ seconds. Appears in the Redis slow log. This is triggered by the `cleanup-user` task when a user visits after being away for >1 hour.
