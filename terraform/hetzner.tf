locals {
  deploy_src = "${path.module}/../docker"
}

resource "hcloud_ssh_key" "hetzner_mkt_ssh_key" {
    name       = "hetzner_mkt_ssh_key"
    public_key = file(var.ssh_public_key_path)
}

resource "null_resource" "hetzner_mkt_upload_and_deploy" {
  depends_on = [hcloud_server.hetzner_mkt_server, cloudflare_dns_record.cloudflare_mkt_dns_record, cloudflare_dns_record.cloudflare_portainer_dns_record]

  triggers = {
    deploy_hash = sha1(join("", [
      for f in fileset(local.deploy_src, "**") :
      filesha1("${local.deploy_src}/${f}")
    ]))
  }

  connection {
    type        = "ssh"
    host        = hcloud_server.hetzner_mkt_server.ipv4_address
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    source      = local.deploy_src
    destination = "/opt/app"
  }

  provisioner "remote-exec" {
    inline = [
      # Make sure cloud-init finished installing docker
      "cloud-init status --wait || true",

      "chmod +x /opt/app/deploy_docker.sh",
      "cd /opt/app && ./deploy_docker.sh",
    ]
  }
}

resource "hcloud_firewall" "hetzner_mkt_fire" {
    name = "web-firewall"
    rule {
        direction = "in"
        protocol  = "icmp"
        source_ips = [
        "0.0.0.0/0",
        "::/0"
        ]
    }

    rule {
        direction = "in"
        protocol  = "tcp"
        port      = "22"
        source_ips = [
        "0.0.0.0/0",
        "::/0"
        ]
    }

    rule {
        direction = "in"
        protocol = "tcp"
        port = "80"
        source_ips = [
            "0.0.0.0/0",
            "::/0"
        ]
    }

    rule {
        direction = "in"
        protocol = "tcp"
        port = "443"
        source_ips = [
          "0.0.0.0/0",
          "::/0"
        ]
    }

}

resource "hcloud_server" "hetzner_mkt_server" {
    name        = "my-server"
    image       = "ubuntu-24.04"
    server_type = "cx23"
    location    = "nbg1"
    ssh_keys    = [hcloud_ssh_key.hetzner_mkt_ssh_key.id]
    keep_disk   = true 
    user_data = file("${path.module}/cloud-init.yml")
    firewall_ids = [hcloud_firewall.hetzner_mkt_fire.id]
}

output "ip" {
    value = hcloud_server.hetzner_mkt_server.ipv4_address
}