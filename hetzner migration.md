# Tweet
"Time for a big server transition. I’m moving the servers from Digital Ocean to Hetzner. Every database server (postgresql, mongo, redis x 4, elasticsearch, prometheus, consul, and sentry) is making the move. I’m going to do it all at once, which means about an hour of downtime."

"Afterwards, you shouldn't notice anything different, although these are bare metal servers, so theoretically they should be faster and more reliable."

# Postgres

# Edit postgres/consul_service.json: db-postgres2 -> hdb-postgres-1
aps -l db-postgres2,hdb-postgres-1,hdb-postgres-2 -t consul
aps -l hdb-postgres-1 -t pg_promote

# Mongo

sshdo db-mongo-primary1
sudo exec -it mongo mongo
rs.config()
rs.reconfig()

# Move mongo analytics
# Edit mongo/tasks/main.yml: mongo_analytics_secondary
aps -l db-mongo-analytics,hdb-mongo-analytics -t consul

# Redis

# Edit redis/tasks/main.yml: redis_secondary
aps -l hdb-redis-user-1,hdb-redis-user-2 -t redis
aps -l hdb-redis-session-1,hdb-redis-session-2 -t redis
aps -l hdb-redis-story-1,hdb-redis-story-2 -t redis
aps -l hdb-redis-pubsub -t redis
apd -l hdb-redis-user-1,hdb-redis-session-1,hdb-redis-story-1,hdb-redis-pubsub -t replicaofnoone

# Elasticsearch

# Edit elasticsearch/tasks/main.yml: elasticsearch_secondary
aps -l hdb-elasticsearch-1 -t elasticsearch
# Eventually MUserSearch.remove_all()

# Haproxy on DO to redirect to Hetzner
aps -l www -t haproxy
# Change DNS to point to Hetzner
