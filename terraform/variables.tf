variable "droplet_region" {
  type = string
  default = "nyc1"
}

variable "droplet_size" {
  type = string
  default = "s-1vcpu-1gb"
}

variable "droplet_size_20" {
  type = string
  default = "s-2vcpu-4gb"
}

variable "droplet_size_120" {
  type = string
  default = "g-8vcpu-32gb"
}

variable "droplet_os" {
  type = string
  default = "ubuntu-20-04-x64"
}


variable "mongo_droplet_size" {
  type = string
  default = "m-4vcpu-32gb"
}

variable "metrics_droplet_size" {
  type = string
  default = "s-1vcpu-2gb"
}

variable "mongo_secondary_droplet_size" {
  type = string
  default = "m-2vcpu-16gb"
}
