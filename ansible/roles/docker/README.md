[![Build Status](https://travis-ci.org/zaxos/docker-ce-ansible-role.svg?branch=master)](https://travis-ci.org/zaxos/docker-ce-ansible-role)
[![Ansible Galaxy](https://img.shields.io/badge/galaxy-_zaxos.docker--ce--ansible--role-blue.svg)](https://galaxy.ansible.com/zaxos/docker-ce-ansible-role/)

docker-ce-ansible-role
======================

Ansible role to install Docker CE (Community Edition).

Requirements
------------
* OS support list:  
  * Centos 7
  * Ubuntu Xenial 16.04 (LTS)
  * Ubuntu Yakkety 16.10
  * Ubuntu Trusty 14.04 (LTS)
* ansible >= 1.9

Installation
------------
```
$ ansible-galaxy install zaxos.docker-ce-ansible-role
```

Example Playbook
----------------
```yaml
    - hosts: servers
      roles:
        - role: zaxos.docker-ce-ansible-role
```
