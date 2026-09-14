variable "hcloud_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "ssh_private_key_path" {
  type      = string
  sensitive = true
}

variable "ssh_public_key_path" {
  type = string
}

variable "mkt_url" {
  type = string
}

variable "portainer_url" {
  type = string
}