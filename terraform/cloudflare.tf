locals {
  zone_name = replace(
    var.mkt_url,
    "/^[^.]+\\.(.+\\..+)$/",
    "$1"
  )
}

data "cloudflare_zone" "cloudflare_mkt_zone" {
  filter = {
    name = local.zone_name
  }
}
resource "cloudflare_dns_record" "cloudflare_mkt_dns_record" {
  zone_id = data.cloudflare_zone.cloudflare_mkt_zone.id
  name = var.mkt_url
  ttl = 1
  type = "A"
  content = hcloud_server.hetzner_mkt_server.ipv4_address
  proxied = false
}

resource "cloudflare_dns_record" "cloudflare_portainer_dns_record" {
  zone_id = data.cloudflare_zone.cloudflare_mkt_zone.id
  name = var.portainer_url
  ttl = 1
  type = "A"
  content = hcloud_server.hetzner_mkt_server.ipv4_address
  proxied = false
}