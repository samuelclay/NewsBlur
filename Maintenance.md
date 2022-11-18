
### Bootstrapping Search **** is this still applicable?

Once you have an elasticsearch server running, you'll want to bootstrap it with feed and story indexes.

    ./manage.py index_feeds
    
Stories will be indexed automatically.

If you need to move search servers and want to just delete everything in the search database, you need to reset the MUserSearch table. Run 
    `make shell`

    >>> from apps.search.models import MUserSearch
    >>> MUserSearch.remove_all()
    
### If feeds aren't fetching:
  check that the `tasked_feeds` queue is empty. You can drain it by running:
    `make shell`
    
    ```
    Feed.drain_task_feeds()
    ```
    
    This happens when a deploy on the task servers hits faults and the task servers lose their 
    connection without giving the tasked feeds back to the queue. Feeds that fall through this 
    crack are automatically fixed after 24 hours, but if many feeds fall through due to a bad 
    deploy or electrical failure, you'll want to accelerate that check by just draining the 
    tasked feeds pool, adding those feeds back into the queue. This command is idempotent.
      

## In Case of Downtime

You got the downtime message either through email or SMS. This is the order of operations for determining what's wrong.

 0a. If downtime goes over 5 minutes, go to Twitter and say you're handling it. Be transparent about what it is,
    NewsBlur's followers are largely technical. Also the 502 page points users to Twitter for status updates.
 
 0b. Ensure you have `secrets-newsblur/configs/hosts` installed in your `/etc/hosts` so server hostnames 
    work.

 1. Check www.newsblur.com to confirm it's down.
    
    If you don't get a 502 page, then NewsBlur isn't even reachable and you just need to contact [the
    hosting provider](https://cloudsupport.digitalocean.com/s/createticket) and yell at them. 

 2. Check which servers can't be reached on HAProxy stats page. Basic auth can be found in secrets/configs/haproxy.conf. Search the secrets repo for "gimmiestats".
 
    Typically it'll be mongo, but any of the redis or postgres servers can be unreachable due to
    acts of god. Otherwise, a frequent cause is lack of disk space. There are monitors on every DB
    server watching for disk space, emailing me when they're running low, but it still happens.
    
 3. Check [Sentry](https://app.getsentry.com/newsblur/app/) and see if the answer is at the top of the 
    list.
 
    This will show if a database (redis, mongo, postgres) can't be found.
 
 4. Check the various databases:

     a. If Redis server (db_redis, db_redis_story, db_redis_pubsub) can't connect, redis is probably down.
        
        SSH into the offending server (or just check both the `db_redis` and `db_redis_story` servers) and
        check if `redis` is running. You can often `tail -f -n 100 /var/log/redis.log` to find out if
        background saving was being SIG(TERM|INT)'ed. When redis goes down, it's always because it's
        consuming too much memory. That shouldn't happen, so check the [munin
        graphs](http://db_redis/munin/).
        
        Boot it with `sudo /etc/init.d/redis start`.
     
     b. If mongo (db_mongo) can't connect, mongo is probably down.
        
        This is rare and usually signifies hardware failure. SSH into `db_mongo` and check logs with `tail
        -f -n 100 /var/log/mongodb/mongodb.log`. Start mongo with `sudo /etc/init.d/mongodb start` then
        promote the next largest mongodb server. You want to then promote one of the secondaries to
        primary, kill the offending primary machine, and rebuild it (preferably at a higher size). I
        recommend waiting a day to rebuild it so that you get a different machine. Don't forget to lodge a
        support ticket with the hosting provider so they know to check the machine.
        
        If it's the db_mongo_analytics machine, there is no backup nor secondaries of the data (because
        it's ephemeral and used for, you guessed it, analytics). You can easily provision a new mongodb
        server and point to that machine.
        
        If mongo is out of space, which happens, the servers need to be re-synced every 2-3 months to 
        compress the data bloat. Simply `rm -fr /var/lib/mongodb/*` and re-start Mongo. It will re-sync.
        
        If both secondaries are down, then the primary Mongo will go down. You'll need a secondary mongo
        in the sync state at the very least before the primary will accept reads. It shouldn't take long to
        get into that state, but you'll need a mongodb machine setup. You can immediately reuse the 
        non-working secondary if disk space is the only issue.
        
     c. If postgresql (db_pgsql) can't connect, postgres is probably down.
        
        This is the rarest of the rare and has in fact never happened. Machine failure. If you can salvage
        the db data, move it to another machine. Worst case you have nightly backups in S3. The fabfile.py
        has commands to assist in restoring from backup (the backup file just needs to be local).
    
 4. Point to a new/different machine
    
    a. Confirm the IP address of the new machine with `fab list_do`.
    
    b. Change `secrets-newsbur/config/hosts` to reflect the new machine.
    
    c. Copy the new `hosts` file to all machines with:
    
       ```
       fab all setup_hosts
       ```
    
    d. Changes should be instant, but you can also bounce every machine with:
    
       ```
       fab web deploy
       fab task celery
       ```
      
    e. Monitor `utils/tlnb.py` and `utils/tlnbt.py` for lots of reading and feed fetching.

  5. If feeds aren't fetching, check that the `tasked_feeds` queue is empty. You can drain it by running:
  
    ```
    Feed.drain_task_feeds()
    ```
    
    This happens when a deploy on the task servers hits faults and the task servers lose their 
    connection without giving the tasked feeds back to the queue. Feeds that fall through this 
    crack are automatically fixed after 24 hours, but if many feeds fall through due to a bad 
    deploy or electrical failure, you'll want to accelerate that check by just draining the 
    tasked feeds pool, adding those feeds back into the queue. This command is idempotent.

## Python 3

### Switching to a new mongo server

Provision a new mongo server, replicate the data, take newsblur down for maintenance, and then switch to new server.

   # db-mongo-primary2 = new server
   # db-mongo-primary1 = old and busted server
   make plan
   make apply
   make firewall
   # Wait for mongo to synbc, takes 4-5 hours
   make celery_stop
   make maintenance_on
   ./utils/ssh.sh db-mongo-primary1
      docker exec -it mongo mongo
      mongo> rs.config()
      # Edit configuration from above rs.config(), adding in new server with higher priority, 
      # lowering priority on old server
         [
            {server: 'db-mongo-primary1': priority: 1},
            {server: 'db-mongo-primary2': priority: 10},
            {server: 'db-mongo-secondary1': priority: 1},
            ...
         ]
      mongo> rs.reconfig({ ... })
   make maintenance_off
   make task

### Switching to a new redis server

Provision a new redis server, replicate the data, take newsblur down for maintenance, and then switch to new server.

   # db-redis-story2 = moving to new server
   # db-redis-story1 = old server about to be shutdown
   # Edit digitalocean.tf to change db-redis-story count to 2
   make plan
   make apply
   make firewall
   # Wait for redis to sync, takes 5-10 minutes
   # Edit redis/consul_service.json to switch primary to db-redis-story2
   make celery_stop
   make maintenance_on
   apd -l db-redis-story2 -t replicaofnoone
   aps -l db-redis-story1,db-redis-story2 -t consul
   make maintenance_off
   make task
