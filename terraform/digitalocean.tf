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
  count    = 3
  image    = var.droplet_os
  name     = "db-consul${count.index+1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "www" {
  image    = var.droplet_os
  name     = "www"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "app-django" {
  count    = 9
  image    = var.droplet_os
  name     = "app-django${count.index+1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "app-counts" {
  count    = 2
  image    = var.droplet_os
  name     = "app-counts${count.index+1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "app-push" {
  count    = 2
  image    = var.droplet_os
  name     = "app-push${count.index+1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "app-refresh" {
  count    = 8
  image    = var.droplet_os
  name     = "app-refresh${count.index+1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "blog" {
  image    = var.droplet_os
  name     = "blog"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "staging-web" {
  image    = var.droplet_os
  name     = "staging-web"
  region   = var.droplet_region
  size     = var.droplet_size_20
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "discovery" {
  image    = var.droplet_os
  name     = "discovery"
  region   = var.droplet_region
  size     = var.droplet_size_120
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "node-text" {
  image    = var.droplet_os
  name     = "node-text"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "node-socket" {
  count    = 2
  image    = var.droplet_os
  name     = "node-socket${count.index+1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "node-favicons" {
  image    = var.droplet_os
  name     = "node-favicons"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "node-images" {
  image    = var.droplet_os
  name     = "node-images"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "node-page" {
  image    = var.droplet_os
  name     = "node-page"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "db-elasticsearch" {
  image    = var.droplet_os
  name     = "db-elasticsearch"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "db-redis-user" {
  image    = var.droplet_os
  name     = "db-redis-user"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "db-redis-sessions" {
  image    = var.droplet_os
  name     = "db-redis-sessions"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "db-redis-story" {
  image    = var.droplet_os
  name     = "db-redis-story"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "db-redis-pubsub" {
  image    = var.droplet_os
  name     = "db-redis-pubsub"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "db-postgres" {
  image    = var.droplet_os
  name     = "db-postgres"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_volume" "mongo_volume" {
  count                   = 1
  region                  = "nyc1"
  name                    = "mongo${count.index+1}"
  size                    = 400
  initial_filesystem_type = "xfs"
  description             = "Storage for NewsBlur MongoDB"
}

resource "digitalocean_droplet" "db-mongo-primary" {
  count    = 1
  image    = var.droplet_os
  name     = "db-mongo${count.index+1}"
  region   = var.droplet_region
  size     = var.mongo_droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  volume_ids = [element(digitalocean_volume.mongo_volume.*.id, count.index)]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_volume" "mongo_secondary_volume" {
  count                   = 2
  region                  = "nyc1"
  name                    = "mongosecondary${count.index+1}"
  size                    = 400
  initial_filesystem_type = "xfs"
  description             = "Storage for NewsBlur MongoDB"
}

resource "digitalocean_droplet" "db-mongo-secondary" {
  count    = 2
  image    = var.droplet_os
  name     = "db-mongo-secondary${count.index+1}"
  region   = var.droplet_region
  size     = var.mongo_secondary_droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  volume_ids = [element(digitalocean_volume.mongo_secondary_volume.*.id, count.index)]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

# resource "digitalocean_droplet" "db-mongo-analytics" {
#   image    = var.droplet_os
#   name     = "db-mongo-analytics"
#   region   = var.droplet_region
#   size     = var.droplet_size
#   ssh_keys = [digitalocean_ssh_key.default.fingerprint]
#   provisioner "local-exec" {
#     command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
#   }
#   provisioner "local-exec" {
#     command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
#   }
#   provisioner "local-exec" {
#     command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
#   }
# }

resource "digitalocean_volume" "metrics_volume" {
  count                   = 0
  region                  = "nyc1"
  name                    = "metrics"
  size                    = 100
  initial_filesystem_type = "xfs"
  description             = "Storage for NewsBlur Prometheus metrics"
}

resource "digitalocean_droplet" "db-metrics" {
  image    = var.droplet_os
  name     = "db-metrics"
  region   = var.droplet_region
  size     = var.metrics_droplet_size
  # volume_ids = [digitalocean_volume.metrics_volume.0.id] 
  volume_ids = ["f815908f-e1b7-11eb-a10f-0a58ac145428"] # 100GB volume created outside TF. Remove when upgrading to 200GB
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "task-celery" {
  count    = 79
  image    = var.droplet_os
  name     = format("task-celery%02v", count.index+1)
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    # command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
    command = "sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
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
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}
