terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket                  = "newsblur.terraform"
    key                     = "newsblur.terraform.tfstate"
    region                  = "us-east-1"
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

# resource "digitalocean_project" "NewsBlur_Docker" {
#   name        = "NewsBlur Docker"
#   environment = "Production"
#   description = "Infrastructure glued together with consul"
# }

# resource "digitalocean_project_resources" "NewsBlur_Docker" {
#   project = digitalocean_project.NewsBlur_Docker.id
#   resources = flatten([
#     digitalocean_droplet.db-consul.*.urn, 
#     digitalocean_droplet.www.*.urn,
#     digitalocean_droplet.app-django.*.urn, 
#     digitalocean_droplet.app-counts.*.urn, 
#     digitalocean_droplet.app-push.*.urn, 
#     digitalocean_droplet.app-refresh.*.urn, 
#     digitalocean_droplet.blog.*.urn, 
#     digitalocean_droplet.staging-web.*.urn, 
#     digitalocean_droplet.discovery.*.urn, 
#     digitalocean_droplet.node-text.*.urn, 
#     digitalocean_droplet.node-socket.*.urn, 
#     digitalocean_droplet.node-favicons.*.urn, 
#     digitalocean_droplet.node-images.*.urn, 
#     digitalocean_droplet.node-page.*.urn, 
#     digitalocean_droplet.db-elasticsearch.*.urn, 
#     digitalocean_droplet.db-redis-user.*.urn, 
#     digitalocean_droplet.db-redis-sessions.*.urn, 
#     digitalocean_droplet.db-redis-story.*.urn, 
#     digitalocean_droplet.db-redis-pubsub.*.urn, 
#     digitalocean_droplet.db-postgres.*.urn, 
#     digitalocean_droplet.db-mongo-primary.*.urn, 
#     digitalocean_droplet.db-mongo-secondary.*.urn, 
#     digitalocean_droplet.db-mongo-analytics.*.urn, 
#     digitalocean_droplet.db-metrics.*.urn, 
#     digitalocean_droplet.db-sentry.*.urn, 
#     digitalocean_droplet.task-celery.*.urn, 
#     digitalocean_droplet.task-work.*.urn
#   ])
# }

# #################
# #   Resources   #
# #################

resource "digitalocean_droplet" "db-consul" {
  count    = 3
  image    = var.droplet_os
  name     = "db-consul${count.index + 1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "www" {
  count    = 1
  image    = var.droplet_os
  name     = "www${count.index + 2}"
  region   = var.droplet_region
  size     = var.droplet_size_15
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "app-django" {
  count    = 9
  image    = var.droplet_os
  name     = "app-django${count.index + 1}"
  region   = var.droplet_region
  size     = var.droplet_size_15
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "app-counts" {
  count    = 2
  image    = var.droplet_os
  name     = "app-counts${count.index + 1}"
  region   = var.droplet_region
  size     = var.droplet_size_15
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "app-push" {
  count    = 2
  image    = var.droplet_os
  name     = "app-push${count.index + 1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "app-refresh" {
  count    = 8
  image    = var.droplet_os
  name     = "app-refresh${count.index + 1}"
  region   = var.droplet_region
  size     = var.droplet_size_15
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
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
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "staging-web" {
  count    = 3
  image    = var.droplet_os
  name     = count.index == 0 ? "staging-web" : "staging-web${count.index + 1}"
  region   = var.droplet_region
  size     = var.droplet_size_20
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "discovery" {
  count    = 0
  image    = var.droplet_os
  name     = "discovery"
  region   = var.droplet_region
  size     = var.droplet_size_120
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "node-text" {
  count    = 2
  image    = var.droplet_os
  name     = contains([0], count.index) ? "node-text" : "node-text${count.index + 1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "node-socket" {
  count    = 2
  image    = var.droplet_os
  name     = "node-socket${count.index + 1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "node-favicons" {
  count    = 2
  image    = var.droplet_os
  name     = "node-favicons${count.index + 1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "node-images" {
  count    = 2
  image    = var.droplet_os
  name     = "node-images${count.index + 1}"
  region   = var.droplet_region
  size     = var.droplet_size_15
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}


resource "digitalocean_volume" "node_page_volume" {
  count                   = 0
  region                  = "nyc1"
  name                    = "nodepage"
  size                    = 100
  initial_filesystem_type = "ext4"
  description             = "Original Pages for NewsBlur"
}

resource "digitalocean_droplet" "node-page" {
  image    = var.droplet_os
  name     = "node-page"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  # volume_ids = [digitalocean_volume.node_page_volume.0.id] 
  volume_ids = ["70b5a115-eb5c-11eb-81b7-0a58ac144312"] # 100GB volume created outside TF. Remove when upgrading to 200GB
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "db-elasticsearch" {
  count    = 1
  image    = var.droplet_os
  # name     = "db-elasticsearch"
  name     = "db-elasticsearch${count.index+1}"
  region   = var.droplet_region
  size     = var.elasticsearch_droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "db-redis-user" {
  image    = var.droplet_os
  name     = "db-redis-user"
  region   = var.droplet_region
  size     = var.droplet_size_40
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "db-redis-sessions" {
  image    = var.droplet_os
  name     = "db-redis-sessions"
  region   = var.droplet_region
  size     = var.droplet_size_20
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "db-redis-story" {
  count  = 2
  image  = var.droplet_os
  name   = "db-redis-story${count.index + 1}"
  region = var.droplet_region
  size   = contains([1], count.index) ? "m-8vcpu-64gb" : var.redis_story_droplet_size
  # size     = var.redis_story_droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "db-redis-pubsub" {
  count    = 1
  image    = var.droplet_os
  name     = contains([0], count.index) ? "db-redis-pubsub" : "db-redis-pubsub{count.index+1}"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "db-postgres" {
  count  = 2
  image  = var.droplet_os
  name   = contains([0], count.index) ? "db-postgres${count.index + 1}" : "db-postgres${count.index + 2}"
  region = var.droplet_region
  size   = contains([0], count.index) ? var.droplet_size_160 : var.droplet_size_320
  # size     = var.droplet_size_240
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

# resource "digitalocean_volume" "mongo_volume" {
#   count                   = 1
#   region                  = "nyc1"
#   name                    = "mongo${count.index+2}"
#   size                    = 400
#   initial_filesystem_type = "xfs"
#   description             = "Storage for NewsBlur MongoDB"
# }

# resource "digitalocean_droplet" "db-mongo-primary" {
#   count    = 1
#   image    = var.droplet_os
#   name     = "db-mongo-primary${count.index+1}"
#   region   = var.droplet_region
#   size     = var.mongo_droplet_size
#   ssh_keys = [digitalocean_ssh_key.default.fingerprint]
#   volume_ids = [element(digitalocean_volume.mongo_volume.*.id, count.index)]
#   provisioner "local-exec" {
#     command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
#   }
#   provisioner "local-exec" {
#     command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
#   }
#   provisioner "local-exec" {
#     command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
#   }
# }


# When creating and benchmarking new mongo servers, target only the new servers
# servers=$(for i in {1..9}; do echo -n "-target=\"digitalocean_droplet.db-mongo-primary[$i]\" " ; done); tf plan -refresh=false `eval echo $servers`
# 
resource "digitalocean_droplet" "db-mongo-primary" {
  count   = 2
  backups = true
  image   = var.droplet_os
  name    = "db-mongo-primary${count.index + 1}"
  region  = var.droplet_region
  # size     = contains([1], count.index) ? "m3-8vcpu-64gb" : var.mongo_primary_droplet_size
  size     = var.mongo_primary_droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
    # command = "sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_volume" "mongo_secondary_volume" {
  count                   = 3
  region                  = "nyc1"
  name                    = "mongosecondary${count.index + 1}"
  size                    = 400
  initial_filesystem_type = "xfs"
  description             = "Storage for NewsBlur MongoDB"
}

resource "digitalocean_droplet" "db-mongo-secondary" {
  count = 3
  # backups  = contains([0], count.index) ? true : false
  image      = var.droplet_os
  name       = "db-mongo-secondary${count.index + 1}"
  region     = var.droplet_region
  size       = var.mongo_secondary_droplet_size
  ssh_keys   = [digitalocean_ssh_key.default.fingerprint]
  volume_ids = [element(digitalocean_volume.mongo_secondary_volume.*.id, count.index)]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_volume" "mongo_analytics_volume" {
  count                   = 1
  region                  = "nyc1"
  name                    = "mongoanalytics${count.index + 2}"
  size                    = 100
  initial_filesystem_type = "xfs"
  description             = "Storage for NewsBlur MongoDB Analytics"
}

resource "digitalocean_droplet" "db-mongo-analytics" {
  count      = 1
  image      = var.droplet_os
  name       = "db-mongo-analytics${count.index + 2}"
  region     = var.droplet_region
  size       = var.mongo_analytics_droplet_size
  volume_ids = [element(digitalocean_volume.mongo_analytics_volume.*.id, count.index)]
  ssh_keys   = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_volume" "metrics_volume" {
  count                   = 0
  region                  = "nyc1"
  name                    = "metrics"
  size                    = 100
  initial_filesystem_type = "xfs"
  description             = "Storage for NewsBlur Prometheus metrics"
}

resource "digitalocean_droplet" "db-metrics" {
  image  = var.droplet_os
  name   = "db-metrics"
  region = var.droplet_region
  size   = var.metrics_droplet_size
  # volume_ids = [digitalocean_volume.metrics_volume.0.id] 
  volume_ids = ["f815908f-e1b7-11eb-a10f-0a58ac145428"] # 100GB volume created outside TF. Remove when upgrading to 200GB
  ssh_keys   = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "db-sentry" {
  image    = var.droplet_os
  name     = "db-sentry"
  region   = var.droplet_region
  size     = var.sentry_droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}


# apd -l "task-celery4*" --tags stop; servers=$(for i in {39..48}; do echo -n "-target=\"digitalocean_droplet.task-celery[$i]\" " ; done); tf apply -refresh=false `eval echo $servers`
resource "digitalocean_droplet" "task-celery" {
  count    = 79
  image    = var.droplet_os
  name     = format("task-celery%02v", count.index + 1)
  region   = var.droplet_region
  size     = var.droplet_size_10
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    # command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
    command = "sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}

resource "digitalocean_droplet" "task-work" {
  count    = 3
  image    = var.droplet_os
  name     = "task-work${count.index + 1}"
  region   = var.droplet_region
  size     = var.droplet_size_10
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "/srv/newsblur/ansible/utils/generate_inventory.py; sleep 120"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/playbooks/setup_root.yml"
  }
  provisioner "local-exec" {
    command = "cd ..; ANSIBLE_FORCE_COLOR=1 ansible-playbook -l ${self.name} ansible/setup.yml"
  }
}
