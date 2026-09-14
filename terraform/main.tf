terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.24"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.4"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.14.2"
    }

  }
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "null" {

}

provider "time" {

}