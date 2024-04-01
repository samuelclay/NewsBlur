Migration from Digital Ocean to Hetzner, covering about 120 servers (20 db, 80 task, 20 app)

## Tweet

> "Time for a big server transition. I’m moving the servers from Digital Ocean to Hetzner. Every database server (postgresql, mongo, redis x 4, elasticsearch, prometheus, consul, and sentry) is making the move. I’m going to do it all at once, which means about an hour of downtime."

> "Afterwards, you shouldn't notice anything different, although these are bare metal servers, so theoretically they should be faster and more reliable."

```
make maintenance_on
make celery_stop
```

## Postgres

> Edit postgres/consul_service.json: db-postgres2 -> hdb-postgres-1

```
aps -l db-postgres2,hdb-postgres-1,hdb-postgres-2 -t consul
aps -l hdb-postgres-1 -t pg_promote
```

## Mongo

```
sshdo db-mongo-primary1
sudo docker exec -it mongo mongo
rs.config()
rs.reconfig()
```

## Mongo analytics

> Edit mongo/tasks/main.yml: mongo_analytics_secondary

```
aps -l db-mongo-analytics2,hdb-mongo-analytics-1 -t consul
```

## Redis

> Edit redis/tasks/main.yml: redis_secondary

```
aps -l hdb-redis-user-1,hdb-redis-user-2,db-redis-user -t consul
aps -l hdb-redis-session-1,hdb-redis-session-2,db-redis-sessions -t consul
aps -l hdb-redis-story-1,hdb-redis-story-2,db-redis-story1 -t consul
aps -l hdb-redis-pubsub,db-redis-pubsub -t consul
apd -l hdb-redis-user-1,hdb-redis-session-1,hdb-redis-story-1,hdb-redis-pubsub -t replicaofnoone
```

## Elasticsearch

> Edit elasticsearch/tasks/main.yml: elasticsearch_secondary
```
aps -l db-elasticsearch1,hdb-elasticsearch-1 -t consul
```
> Eventually `MUserSearch.remove_all()`

## Test hwww.newsblur.com
```
ansible-playbook ansible/deploy.yml -l happ-web-01 --tags maintenance_off
```

## Looks good? Launch

> Haproxy on DO to redirect to Hetzner
```
aps -l www -t haproxy
```
> Change DNS to point to Hetzner
```
make maintenance_off
```

