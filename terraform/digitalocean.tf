terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "1.22.2"
    }
  }

  backend "s3" {
    bucket = "newsblur.terraform"
    key    = "newsblur.terraform.tfstate"
    region = "us-east-1"
    shared_credentials_file = "/srv/secrets-newsblur/keys/aws.s3.token"
  }
}

provider "digitalocean" {
  token = trimspace(file("/srv/secrets-newsblur/keys/digital_ocean.token"))
}

resource "digitalocean_ssh_key" "default" {
  name       = "NB_SSH_Key"
  public_key = file("/srv/secrets-newsblur/keys/docker.key.pub")
}

# #################
# #   Resources   #
# #################

resource "digitalocean_droplet" "db-consul" {
  image    = var.droplet_os
  name     = "db-consul"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "www" {
  image    = var.droplet_os
  name     = "www"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "app-django" {
  count    = 2
  image    = var.droplet_os
  name     = "app-django${count.index+1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "app-counts" {
  count    = 1
  image    = var.droplet_os
  name     = "app-counts${count.index+1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "app-push" {
  count    = 1
  image    = var.droplet_os
  name     = "app-push${count.index+1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "app-refresh" {
  count    = 1
  image    = var.droplet_os
  name     = "app-refresh${count.index+1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "node-text" {
  image    = var.droplet_os
  name     = "node-text"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "node-socket" {
  image    = var.droplet_os
  name     = "node-socket"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "node-favicons" {
  image    = var.droplet_os
  name     = "node-favicons"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "node-images" {
  image    = var.droplet_os
  name     = "node-images"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "node-page" {
  image    = var.droplet_os
  name     = "node-page"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "db-elasticsearch" {
  image    = var.droplet_os
  name     = "db-elasticsearch"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "db-redis-user" {
  image    = var.droplet_os
  name     = "db-redis-user"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "db-redis-sessions" {
  image    = var.droplet_os
  name     = "db-redis-sessions"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "db-redis-story" {
  image    = var.droplet_os
  name     = "db-redis-story"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "db-redis-pubsub" {
  image    = var.droplet_os
  name     = "db-redis-pubsub"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "db-postgres" {
  image    = var.droplet_os
  name     = "db-postgres"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "db-mongo" {
  count    = 3
  image    = var.droplet_os
  name     = "db-mongo${count.index+1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "task-celery" {
  count    = 2
  image    = var.droplet_os
  name     = "task-celery${count.index+1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "task-work" {
  count    = 2
  image    = var.droplet_os
  name     = "task-work${count.index+1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "task-search" {
  image    = var.droplet_os
  name     = "task-search"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}

resource "digitalocean_droplet" "task-beat" {
  image    = var.droplet_os
  name     = "task-beat"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/provision.yml"
  }
}
