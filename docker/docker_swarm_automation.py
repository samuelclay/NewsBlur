import docker
import machine
import subprocess
import threading
import os
import digitalocean

machine = machine.Machine()
client = docker.client.from_env()
swarm = client.swarm
containers = client.containers
nodes = client.nodes
images = client.images

dev_machines = {
    "app": {
        "managers": 1,
        "workers": 4
    },
    "haproxy": {
        "managers": 1,
    },
    "postgres": {
        "managers": 1,
    },
    "mongo": {
        "managers": 1,
        "workers": 2,
    },
    "redis": {
        "managers": 4,
    },
    "elastic_search": {
        "managers": 1,
    },
    "task_celeryd": {
        "managers": 1,
        "workers": 3 #(should be 50 in prod deployment),
    },
    "task_celeryd_work_queue": { # will need more machines for the other celery containers
        "managers": 1,
        "workers": 2,
    },
    "image_proxy": {
        "managers": 1,
    },
    "monitor": {
        "managers": 1,
    },

}
def remove_all_machines():
        try:
            for mach in machine.ls():
                name = mach['Name']
                print(f"Removing docker machine {name}")
                result = subprocess.run(["docker-machine", "rm", name, "--force"], capture_output=True)
            return True
        except:
            return False

def get_join_token(role):
    result = subprocess.run(["docker", "swarm", "join-token", role], capture_output=True)
    string = result.stdout
    return result.stdout.decode('utf-8').split("    ")[1][:-2]

def new_swarm():
    try:
        print("Initializing new swarm")
        manager = swarm.init()
    except:
        swarm.leave(force=True)
        manager = swarm.init()
    return manager


def build_machine(machine_name):

    xargs = [
        "--digitalocean-image ubuntu-18-04-x64",
        "--digitalocean-size s-1vcpu-1gb",
        f"--digitalocean-access-token {os.getenv('DOTOKEN')}",

    ]
    node = machine.create(machine_name, "digitalocean", xarg=xargs)
    return node


def build_machines(machines):
    for machine_name in machines:
        print(f"Building machine {machine_name}")
        build_machine(machine_name)

    return machine.ls()

def build_containers(name):
    print(f"Switching to machine environment for name {name}")
    os.system(f"eval $(docker-machine env {machine['Name']})")

    result = os.system(f"docker stack deploy --compose-file machine_compose/{name}.yml {name}")
    return result

def build_image(service, push=False):
    print(f"Building {service}")
    if service == "node_base":
        image = images.build(path=".", dockerfile="./docker/node/node_base.Dockerfile", tag="node_base")
    if service == "newsblur_base":
        image = images.build(path=".", dockerfile="./docker/newsblur_base_image.Dockerfile", tag="newsblur_base") 
    elif service == "haproxy":
        image =  images.build(path=".", dockerfile="./docker/haproxy/Dockerfile", tag="haproxy")
    else:
        print("Service not found")
    print(f"Built {image}")
    print("Pushing image")
    repository = f"jmath1/{service}"
    if push:
        print("Pushing image")
        image.push(repository, tag='')


def delete_all_user_machines():
    try:
        manager = digitalocean.Manager(token=os.getenv("DOTOKEN"))
        my_droplets = manager.get_all_droplets()
        jmath_droplets = [x for x in my_droplets if "jmath" in x.name]
        if not jmath_droplets:
            print("no jmath droplets found")
            return True, ""
        droplets_destroyed = []
        for droplet in jmath_droplets:
            print(
            f"""
                Attempting to destroy droplet
                ID: {droplet.id}
                name: {droplet.name}
            """
            )
            name = droplet.name
            droplet.destroy()
            droplets_destroyed.append(name)
        print(f"Destroyed droplets {droplets_destroyed}")

        return True, ""

    except Exception as e:
        return False, e

def parse_machine_dict(machine_dict):
    machine_list = []
    for k in machine_dict:
        if "manager" not in machine_dict[k].keys():
            raise Exception(f"No manager found in machine '{machine_dict[k]}'")
        manager_machines = machine_dict[k]["manager"]
        worker_machines = machine_dict[k].get("workers", 0)

        i = 0
        while i < manager_machines:
            i += 1
            machine_list.append(f"{k}_manager_{i}")
        i = 0
        while i < worker_machines:
            i +=1
            machine_list.append(f"{k}_worker_{i}")

    return machine_list
            
class DockerCluster():

    def __init__(self, name, environment="dev", restart_swarm=False):
        self.name = name
        
        if restart_swarm:
            swarm_manager = new_swarm()
            

        if environment == "dev":
            self.manager_join_token_command = get_join_token(role="manager")
            self.worker_join_token_command = get_join_token(role="worker")
            print(f"Join token for manager is {self.manager_join_token_command}")
            print(f"Join token for worker is {self.worker_join_token_command}")

            # create machines
            if restart_swarm:
                self.machines_list = parse_machine_dict(dev_machine_dict)
                self.machine_list = [f"{os.environ['DEV_USER']}_" + x for x in machines_list]
                self.machines = build_machines(self.machine_list)
            else:
                self.machines = machine.ls()

            for m in self.machines:

                print(f"machine {m['Name']} built")
                self.machine_ips = [(x['Name'], x.get("URL")) for x in machine.ls()]
                print(self.machine_ips)

                # create managers and workers for every manifest
                # get IPs of manager nodes, use for rendering haproxy
                # use join token to join docker swarm
                #docker.service.create()
    
    def add_labels_to_nodes(self):
        for machine in self.machine_list:
            import pdb; pdb.set_trace()

    def swarmify_machines(self):

        #machine_ips = [(name, url,),]

        for m in self.machine_ips:
            name, url = m

            #TODO add join tokens and IP addresses
            if "worker" in name:
                swarm.join()
            elif "manager" in name:
                swarm.join()

def deploy():
    try:
        name = "newsblur_dev"
        remove_all_machines()
        outcome, error = delete_all_user_machines()
        if error:
            print("There was a problem deleting the user-created (dev) machines")
            exit()
        docker_swarm = DockerCluster(name, restart_swarm=True)
        docker_swarm.swarmify_machines()
        docker_swarm.add_labels_to_nodes()
        docker_swarm.deploy()
        
        for machine in docker_swarm.machines:
            if f"{machine['Name']}.yml" not in os.listdir('machine_compose'):
                print(f"{machine['Name']}.yml not found")
            else:
                build_containers(machine['Name'])
    except Exception as e:
        print(e)

deploy()