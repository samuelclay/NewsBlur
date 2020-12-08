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
do_manager = digitalocean.Manager(token=os.getenv("DOTOKEN"))

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
    "elastic-search": {
        "managers": 1,
    },
    "task-celeryd": {
        "managers": 1,
        "workers": 3 #(should be 50 in prod deployment),
    },
    "task-celeryd-work-queue": { # will need more machines for the other celery containers
        "managers": 1,
        "workers": 2,
    },
    "image-proxy": {
        "managers": 1,
    },
    "monitor": {
        "managers": 1,
    },

}

expected_volumes = {
    "app-files" : {
        "driver": "rexray/dobs"
    },
    "postgres-data" : {
        "driver": "rexray/dobs"
    },
    "redis-data" : {
        "driver": "rexray/dobs"
    },
    "elasticsearch-data" : {
        "driver": "rexray/dobs"
    },
    "db-mongo-data": {
        "driver": "rexray/dobs"
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
        "--digitalocean-image", "ubuntu-18-04-x64",
        "--digitalocean-size", "s-1vcpu-1gb",
        "--digitalocean-access-token", f"{os.getenv('DOTOKEN')}",

    ]
    try:
        node = machine.create(machine_name, "digitalocean", xarg=xargs)
    except:
        node = None
        print(f"Failed to build machine {machine_name}")
    return node


def build_machines(machines):
    droplets = do_manager.get_all_droplets()
    for machine_name in machines:
        if machine_name not in [d.name for d in droplets]:
            print(f"Building machine {machine_name}")
            build_machine(machine_name)
        else:
            print(f"Already built {machine_name}")

    return machine.ls()

def build_containers(name):
    print(f"Switching to machine environment for name {name}")
    os.system(f"eval $(docker-machine env {machine['Name']})")

    result = os.system(f"docker stack deploy --compose-file machine_compose/{name}.yml {name}")
    return result


def delete_all_user_machines():
    try:
        my_droplets = do_manager.get_all_droplets()
        user_droplets = [x for x in my_droplets if os.environ['DEV_USER'] in x.name]
        if not user_droplets:
            print(f"no {os.environ['DEV_USER']} droplets found")
            return True, ""
        droplets_destroyed = []
        for droplet in user_droplets:
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
        if "managers" not in machine_dict[k].keys():
            raise Exception(f"No manager found in machine '{machine_dict[k]}'")
        manager_machines = machine_dict[k]["managers"]
        worker_machines = machine_dict[k].get("workers", 0)

        i = 0
        while i < manager_machines:
            i += 1
            machine_list.append(f"{k}-manager-{i}")
        i = 0
        while i < worker_machines:
            i +=1
            machine_list.append(f"{k}-worker-{i}")

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
            self.machine_list = parse_machine_dict(dev_machines)
            self.machine_list = [f"{os.environ['DEV_USER']}-" + x for x in self.machine_list]
            self.machines = build_machines(self.machine_list)
    

            self.machine_ips = [(x['Name'], x.get("URL")) for x in machine.ls()]
    
    def add_labels_to_nodes(self):
        print("Adding labels")
        for mach in self.machine_list:
            cmd = f"docker node update --label-add name={mach} {mach}"
            print( f"running '{cmd}'")
            machine.ssh(mach, cmd)

    def swarmify_machines(self):
        for m in self.machine_ips:
            name, url = m
            if "worker" in name:
                role = "worker"
            elif "manager" in name:
                role = "manager"
            token = get_join_token(role)
            import pdb; pdb.set_trace()
            swarm.join(url, token)
    
    def deploy_stack(self):
        compose_file = "stack.docker-compose.yml"
        result = subprocess.run(["docker stack deploy --compose-file=", compose_file], capture_output=True)
        print(result)

    def create_volumes(self):
        """
        Checks if necessary docker plugin in installed, else installs it.
        Then adds docker volumes to swarm.
        """
        if "rexray/dobs" not in [p.name for p in client.plugins.list()]:
            print("Installing plugin rexray/dobs to create DO docker volumes")
            client.plugins.install("rexray/dobs")
        volumes = client.volumes.list()
        for vol in expected_volumes:
            if vol not in volumes:
                print(f"{vol} volume has not been created. Creating now")
                try:
                    client.volumes.create(
                        name=vol,
                        driver=expected_volumes[vol]['driver'],
                        driver_opts=expected_volumes[vol].get('opts', {})
                    )
                except KeyError as e:
                    print(e)
                    print(f"Failed to create volume {vol}. This volume must have a driver")
            else:
                print(f"{vol} has already been created")

def deploy(restart):
    name = "newsblur_dev"
    if restart:
        remove_all_machines()
        outcome, error = delete_all_user_machines()
        if error:
            print("There was a problem deleting the user-created (dev) machines")
            exit()
    docker_swarm = DockerCluster(name, restart_swarm=restart)
    docker_swarm.swarmify_machines()
    docker_swarm.add_labels_to_nodes()
    docker_swarm.create_volumes()
    docker_swarm.deploy_stack()
    
    for machine in docker_swarm.machines:
        if f"{machine['Name']}.yml" not in os.listdir('machine_compose'):
            print(f"{machine['Name']}.yml not found")
        else:
            build_containers(machine['Name'])

deploy(restart=False)