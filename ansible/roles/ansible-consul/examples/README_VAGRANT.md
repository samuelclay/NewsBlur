# Consul with Ansible

This project provides documentation and a collection of scripts to help you automate the deployment of Consul using [Ansible](https://www.ansible.com/). These are the instructions for deploying a development cluster on Vagrant and VirtualBox.

The documentation and scripts are merely a starting point designed to both help familiarize you with the processes and quickly bootstrap an environment for development. You may wish to expand on them and customize them with additional features specific to your needs later.

If you are looking for the main role documentation, it is in the [README.md](https://github.com/brianshumate/ansible-consul/blob/master/README.md).

## Vagrant Development Cluster

In some situations deploying a small cluster on your local development machine can be handy. This document describes such a scenario using the following technologies:

* [Consul](https://consul.io)
* [VirtualBox](https://www.virtualbox.org/)
* [Vagrant](http://www.vagrantup.com/) with Ansible provisioner and
  supporting plugin
* [Ansible](https://www.ansible.com/)

Each of the virtual machines for this guide are configured with 1GB RAM, 2 CPU cores, and 2 network interfaces. The first interface uses NAT and has connection via the host to the outside world. The second interface is a private network and is used for Consul intra-cluster communication in addition to access from the host machine.

The Vagrant configuration file (`Vagrantfile`) is responsible for configuring the virtual machines and a baseline OS installation.

The Ansible playbooks then further refine OS configuration, perform Consul software download, installation, configuration, and the joining of server nodes into a ready to use cluster.

## Designed for Ansible Galaxy

This role is designed to be installed via the `ansible-galaxy` command instead of being directly run from the git repository.

You should install it like this:

```
ansible-galaxy install brianshumate.consul
```

You'll want to make sure you have write access to `/etc/ansible/roles/` since that is where the role will be installed by default, or define your own Ansible role path by creating a `$HOME/.ansible.cfg` or even `./anisible.cfg`
file with these contents:

```
[defaults]
roles_path = PATH_TO_ROLES
```

Change `PATH_TO_ROLES` to a directory that you have write access to.

## Quick Start

Begin from the top level directory of this project and use the following steps to get up and running:

1. Install [VirtualBox](https://www.virtualbox.org/wiki/Downloads), [Vagrant](http://downloads.vagrantup.com/), [vagrant-hosts](https://github.com/adrienthebo/vagrant-hosts), and [Ansible](http://docs.ansible.com/ansible/intro_installation.html).
2. Edit `/etc/hosts` or use the included `bin/preinstall` script to add
   the following entries to your development system's `/etc/hosts` file:
 * 10.1.42.210 consul1.consul consul1
 * 10.1.42.220 consul2.consul consul2
 * 10.1.42.230 consul3.consul consul3
3. cd `$PATH_TO_ROLES/brianshumate.consul/examples`
4. `vagrant up`
5. Access the cluster web UI at http://consul1.consul:8500/ui/
6. You can also `ssh` into a node and verify the cluster members directly
   from the RAFT peers list:

    ```
    vagrant ssh consul1
    consul operator raft -list-peers
    Node     ID                Address           State     Voter
    consul1  10.1.42.210:8300  10.1.42.210:8300  follower  true
    consul2  10.1.42.220:8300  10.1.42.220:8300  follower  true
    consul3  10.1.42.230:8300  10.1.42.230:8300  leader    true
    ```

By default, this project will install Debian 8 based cluster nodes. If you
prefer, it can also install CentOS 7 based nodes by changing the command
in step 4 to the following:

```
BOX_NAME=centos/7 vagrant up
```

or on a modern Ubuntu with a differently named ethernet interface:

```
BOX_NAME=ubuntu/xenial64 CONSUL_IFACE=enp0s8 vagrant up
```

or on FreeBSD:

```
BOX_NAME=freebsd/FreeBSD-11.0-STABLE CONSUL_IFACE=em1 vagrant up
```

## Notes

1. This project functions with the following software versions:
  * Consul version 1.8.7
  * Ansible: 2.8.2
  * VirtualBox version 5.2.22
  * Vagrant version 2.2.1
  * Vagrant Hosts plugin version 2.8.1
2. This project uses Debian 9 (Stretch) by default, but you can choose another OS distribution with the *BOX_NAME* environment variable
3. The `bin/preinstall` shell script performs the following actions for you:
 * Adds each node's host information to the host machine's `/etc/hosts`
 * Optionally installs the Vagrant hosts plugin
4. If you notice an error like *vm: The '' provisioner could not be found.*
   make sure you have vagrant-hosts plugin installed

### Dnsmasq Forwarding

The role includes support for DNS forwarding with Dnsmasq.

Install like this:

```
CONSUL_DNSMASQ_ENABLE=true vagrant up
```

Then you can query any of the agents via DNS directly via port 53:

```
dig @consul1.consul consul3.node.consul

; <<>> DiG 9.8.3-P1 <<>> @consul1.consul consul3.node.consul
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 29196
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 0

;; QUESTION SECTION:
;consul3.node.consul.   IN  A

;; ANSWER SECTION:
consul3.node.consul.  0 IN  A 10.1.42.230

;; Query time: 42 msec
;; SERVER: 10.1.42.210#53(10.1.42.210)
;; WHEN: Sun Aug  7 18:06:32 2016
;; MSG SIZE  rcvd: 72
```

## References

1. https://www.consul.io/
2. https://www.consul.io/intro/getting-started/install.html
3. https://www.consul.io/docs/guides/bootstrapping.html
4. https://www.consul.io/docs/guides/forwarding.html
5. http://www.ansible.com/
6. http://www.vagrantup.com/
7. https://www.virtualbox.org/
8. https://github.com/adrienthebo/vagrant-hosts
