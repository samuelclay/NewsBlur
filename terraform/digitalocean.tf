terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "1.22.2"
    }
  }
}

provider "digitalocean" {
  token = file("/srv/secrets-newsblur/keys/digital_ocean.token")
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

resource "digitalocean_droplet" "app" {
  image    = var.droplet_os
  name     = "app"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = []
}


resource "digitalocean_droplet" "app-counts" {
  image    = var.droplet_os
  name     = "app-counts"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = []
}

resource "digitalocean_droplet" "app-push" {
  image    = var.droplet_os
  name     = "app-push"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = []
}

resource "digitalocean_droplet" "app-refresh" {
  image    = var.droplet_os
  name     = "app-refresh"
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

resource "digitalocean_droplet" "db-redis" {
  image    = var.droplet_os
  name     = "db-redis"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

resource "digitalocean_droplet" "db-redis-sessions" {
  image    = var.droplet_os
  name     = "db-redis-sessions"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

resource "digitalocean_droplet" "db-redis-story" {
  image    = var.droplet_os
  name     = "db-redis-story"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

resource "digitalocean_droplet" "db-redis-pubsub" {
  image    = var.droplet_os
  name     = "db-redis-pubsub"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

resource "digitalocean_droplet" "db-postgres" {
  image    = var.droplet_os
  name     = "db-postgres"
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
