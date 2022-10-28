# doctl compute size list

variable "droplet_region" {
  type = string
  default = "nyc1"
}

variable "droplet_size" {
  type = string
  default = "s-1vcpu-1gb"
}
variable "droplet_size_10" {
  type = string
  default = "s-1vcpu-2gb"
}
variable "droplet_size_15" {
  type = string
  default = "s-2vcpu-2gb"
}

variable "droplet_size_20" {
  type = string
  default = "s-2vcpu-4gb"
}

variable "droplet_size_120" {
  type = string
  default = "g-8vcpu-32gb"
}

variable "droplet_size_160" {
  type = string
  default = "m-4vcpu-32gb"
}

variable "droplet_size_240" {
  type = string
  default = "g-8vcpu-32gb"
}
variable "droplet_size_320" {
  type = string
  default = "c-16"
}

variable "droplet_size_40" {
  type = string
  default = "s-4vcpu-8gb"
}

variable "droplet_os" {
  type = string
  default = "ubuntu-20-04-x64"
}

variable "sentry_droplet_size" {
  type = string
  default = "s-8vcpu-16gb"
}

variable "metrics_droplet_size" {
  type = string
  default = "s-1vcpu-2gb"
}

variable "mongo_droplet_size" {
  type = string
  default = "m-4vcpu-32gb"
}

variable "mongo_primary_droplet_size" {
  type = string
  default = "so-4vcpu-32gb"
}

variable "mongo_secondary_droplet_size" {
  type = string
  default = "m-2vcpu-16gb"
}

variable "mongo_analytics_droplet_size" {
  type = string
  default = "s-2vcpu-4gb"
}

variable "elasticsearch_droplet_size" {
  type = string
  default = "m3-2vcpu-16gb"
}

variable "redis_story_droplet_size" {
  type = string
  default = "m-4vcpu-32gb"
}
