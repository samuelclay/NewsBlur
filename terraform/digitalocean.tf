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
  public_key = file("/srv/secrets-newsblur/keys/docker.key.pub")
}


resource "digitalocean_droplet" "www" {
  image    = var.droplet_os
  name     = "www"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "cd ../ansible; python3 generate.py"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l www ansible/setup_root.yml"
  }
}

resource "digitalocean_droplet" "app-django" {
  image    = var.droplet_os
  name     = "app-django"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "cd ../ansible; python3 generate.py"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l app-django ansible/setup_root.yml"
  }
}

resource "digitalocean_droplet" "app-counts" {
  image    = var.droplet_os
  name     = "app-counts"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "cd ../ansible; python3 generate.py"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l app-counts ansible/setup_root.yml"
  }
}

resource "digitalocean_droplet" "app-push" {
  image    = var.droplet_os
  name     = "app-push"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "cd ../ansible; python3 generate.py"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l app-push ansible/setup_root.yml"
  }
}

resource "digitalocean_droplet" "app-refresh" {
  image    = var.droplet_os
  name     = "app-refresh"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "cd ../ansible; python3 generate.py"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l app-refresh ansible/setup_root.yml"
  }
}

resource "digitalocean_droplet" "node-text" {
  image    = var.droplet_os
  name     = "node-text"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "cd ../ansible; python3 generate.py"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l node-text ansible/setup_root.yml"
  }
}

resource "digitalocean_droplet" "node-socket" {
  image    = var.droplet_os
  name     = "node-socket"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "cd ../ansible; python3 generate.py"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l node-socket ansible/setup_root.yml"
  }
}

resource "digitalocean_droplet" "node-favicons" {
  image    = var.droplet_os
  name     = "node-favicons"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "cd ../ansible; python3 generate.py"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l node-favicons ansible/setup_root.yml"
  }
}

resource "digitalocean_droplet" "node-page" {
  image    = var.droplet_os
  name     = "node-page"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "cd ../ansible; python3 generate.py"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l node-page ansible/setup_root.yml"
  }
}

resource "digitalocean_droplet" "elasticsearch" {
  image    = var.droplet_os
  name     = "elasticsearch"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "cd ../ansible; python3 generate.py"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l elasticsearch ansible/setup_root.yml"
  }
}

resource "digitalocean_droplet" "db-redis-user" {
  image    = var.droplet_os
  name     = "db-redis-user"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "cd ../ansible; python3 generate.py"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l db-redis-user ansible/setup_root.yml"
  }
}

resource "digitalocean_droplet" "db-redis-sessions" {
  image    = var.droplet_os
  name     = "db-redis-sessions"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "cd ../ansible; python3 generate.py"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l db-redis-session ansible/setup_root.yml"
  }
}

resource "digitalocean_droplet" "db-redis-story" {
  image    = var.droplet_os
  name     = "db-redis-story"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "cd ../ansible; python3 generate.py"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l db-redis-story ansible/setup_root.yml"
  }
}

resource "digitalocean_droplet" "db-redis-pubsub" {
  image    = var.droplet_os
  name     = "db-redis-pubsub"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "cd ../ansible; python3 generate.py"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l db-redis-pubsub ansible/setup_root.yml"
  }
}

resource "digitalocean_droplet" "db-postgres" {
  image    = var.droplet_os
  name     = "db-postgres"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "cd ../ansible; python3 generate.py"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l db-postgres ansible/setup_root.yml"
  }
}

resource "digitalocean_droplet" "db-mongo" {
  image    = var.droplet_os
  name     = "db-mongo"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "cd ../ansible; python3 generate.py"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l db-mongo ansible/setup_root.yml"
  }
}

resource "digitalocean_droplet" "task" {
  image    = var.droplet_os
  name     = "task"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "cd ../ansible; python3 generate.py"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l task ansible/setup_root.yml"
  }

resource "digitalocean_droplet" "consul-manager" {
  image    = var.droplet_os
  name     = "consul-manager"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
  provisioner "local-exec" {
    command = "cd ../ansible; python3 generate.py"
  }
  provisioner "local-exec" {
    command = "cd ..; ansible-playbook -l consul-manager ansible/setup_root.yml"
  }
}
