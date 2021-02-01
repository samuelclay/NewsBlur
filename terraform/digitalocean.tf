terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "1.22.2"
    }
  }
}

variable "do_token" {}

provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_ssh_key" "default" {
  name       = "NB_SSH_Key"
  public_key = file("~/.ssh/id_rsa.pub")
}


resource "digitalocean_droplet" "www" {
  image    = var.droplet_os
  name     = "www"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = []
}

resource "digitalocean_droplet" "node-text" {
  image    = var.droplet_os
  name     = "node-text"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

resource "digitalocean_droplet" "node-socket" {
  image    = var.droplet_os
  name     = "node-socket"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

resource "digitalocean_droplet" "node-favicons" {
  image    = var.droplet_os
  name     = "node-favicons"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

resource "digitalocean_droplet" "elasticsearch" {
  image    = var.droplet_os
  name     = "elasticsearch"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

resource "digitalocean_droplet" "redis" {
  image    = var.droplet_os
  name     = "redis"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

resource "digitalocean_droplet" "redis-sessions" {
  image    = var.droplet_os
  name     = "redis-sessions"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

resource "digitalocean_droplet" "redis-story" {
  image    = var.droplet_os
  name     = "redis-story"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

resource "digitalocean_droplet" "redis-pubsub" {
  image    = var.droplet_os
  name     = "redis-pubsub"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

resource "digitalocean_droplet" "postgres" {
  image    = var.droplet_os
  name     = "postgres"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

resource "digitalocean_droplet" "db-mongo" {
  image    = var.droplet_os
  name     = "db-mongo"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

resource "digitalocean_droplet" "task" {
  image    = var.droplet_os
  name     = "task"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}
