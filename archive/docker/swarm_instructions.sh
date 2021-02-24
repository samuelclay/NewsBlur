# create a digital ocean token and export is as DOTOKEN
MACHINES=(manager node app app-counts app-push app-refresh celery postgres db-mongo monitor db-redis db-redis-pubsub db-redis-sessions db-redis-story elasticsearch haproxy monitor)
for mach in $MACHINES; do
    echo "Creating docker machine for ${mach}"
    docker-machine create --driver digitalocean --digitalocean-access-token $DOTOKEN --digitalocean-image ubuntu-20-04-x64 --digitalocean-size s-1vcpu-1gb --digitalocean-monitoring true --digitalocean-private-networking true $mach
done


#swarmify machines
leader_ip=$(docker-machine ip manager)
echo "Initializing Swarm mode"
eval $(docker-machine env manager)
docker swarm init --advertise-addr $leader_ip

manager_token=$(docker swarm join-token manager -q)
worker_token=$(docker swarm join-token worker -q)


for mach in $MACHINES; do

    if [[ $mach == *"manager"* ]]; then
        docker-machine ssh $mach docker swarm join --token $manager_token $leader_ip:2377
    else
        echo "Switching environment to $mach"
        eval $(docker-machine env $mach)
        docker-machine ssh $mach docker swarm join --token $worker_token $leader_ip:2377
    fi

done

# if you are getting the error: Unable to query docker version: Cannot connect to the docker engine endpoint
# ssh into the docker machine with `docker-machine ssh <machine>` and add `DOCKER_OPTS="-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock"`
# to the /etc/default/docker file. Restart the docker service in the machine with 'service docker restart'


#add labels to nodes
echo "Adding labels to nodes"
eval $(docker-machine env manager)
echo "Run the following commands"

docker node update --label-add service=app app
docker node update --label-add service=app app-counts
docker node update --label-add service=app app-push
docker node update --label-add service=app app-refresh
docker node update --label-add service=celery celery

#create volumes
echo "Installing DO volume driver plugin"

VOLUMES=(app-files nginx elasticsearch-data db-mongo-data haproxy-conf)
# TODO functionality for creating shared volumes


#deploy stack
echo "Deploying docker stack stack-compose.yml"
docker stack deploy --with-registry-auth -c stack-compose.yml dev-stack