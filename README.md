# MarioKart_Deployment

Deployment configuration for [MarioKart_Tournament](https://github.com/einToast/MarioKart_Tournament).

This repo contains two folders:

| Directory | Purpose |
|-----------|---------|
| [`terraform/`](terraform/) | Creates the Hetzner Cloud VM, firewall and SSH key, and the Cloudflare DNS records. Then uploads `docker/` to the VM and deploys it. |
| [`docker/`](docker/) | Docker Compose files, env templates and the deploy script that run on the server. |

## Architecture

```
Internet ──> :80/:443 ──> nginx-proxy ──┬─> frontend  (React)         https://<mkt_url>
                                        ├─> backend   (Spring Boot)   https://<mkt_url>/api
                                        └─> portainer                 https://<portainer_url>

backend ──> db (Postgres)
        └─> schedule (match planning service)
```

[nginx-proxy](https://github.com/mesudip/nginx-proxy) watches the Docker socket and configures routing (and TLS certificates) from each container's `VIRTUAL_HOST` variable. No manual nginx configuration is needed.

### Compose files

The files in `docker/` are combined at deploy time:

| File | Services |
|------|----------|
| `docker-compose.mariokart.yml` | `frontend`, `backend`, `schedule`, `db`. Images are pulled from Docker Hub (`eintoast/mariokart_*:latest`, `postgres:latest`). |
| `docker-compose.nginx.yml` | `nginx` reverse proxy. Owns ports 80 and 443. |
| `docker-compose.management.yml` | `portainer` for container management. |

Startup order is enforced by health checks. `backend` waits for `db` and `schedule`, and `frontend` waits for `backend`.

## Configuration

All settings come from an `.env` file in `docker/`. Copy the template and fill in real values:

```bash
cd docker
cp .env.example .env
```

| Group | Variables | Notes |
|-------|-----------|-------|
| Frontend | `FRONTEND_PROTOCOL`, `FRONTEND_HOST`, `FRONTEND_PORT` | `FRONTEND_PROTOCOL` and `FRONTEND_HOST` form the backend's allowed CORS origin (`DOMAIN`). |
| Backend | `SPRING_PROFILES_ACTIVE`, `USER_NAME`, `USER_PASSWORD`, `SECRET_KEY`, `BACKEND_PORT`, `TZ` | Use `prod` as the profile (Postgres). Use a `SECRET_KEY` of at least 32 characters. |
| Push notifications | `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_CONTACT_EMAIL` | Generate your own VAPID key pair. The keys in `.env.example` are examples only. |
| API URLs (used by the frontend) | `BACKEND_API_*`, `BACKEND_WS_*` | Protocol, host, port and path of the REST API and the WebSocket, as seen from the user's browser. |
| Schedule | `SCHEDULE_PROTOCOL`, `SCHEDULE_HOST`, `SCHEDULE_PORT` | Internal address used by the backend. Keep `SCHEDULE_HOST=schedule`. |
| Database | `POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `POSTGRES_PORT` | Keep `POSTGRES_HOST=db`. |
| Reverse proxy | `FRONTEND_VIRTUAL_HOST`, `BACKEND_VIRTUAL_HOST`, `PORTAINER_VIRTUAL_HOST` | Public URLs that nginx-proxy routes. Portainer uses the `-> :9000` suffix to select its container port. |

env files :

- `.env.example` is the production template. Do not use its values in production.
- `.env.test` has local test values.

## Deployment

### Option 1: Terraform (server and application)

Requirements:

- [Terraform](https://developer.hashicorp.com/terraform/install)
- A [Hetzner Cloud](https://www.hetzner.com/cloud) API token
- A [Cloudflare](https://www.cloudflare.com/) API token with DNS edit permission for the zone
- An SSH key pair
- A completed `docker/.env`, because Terraform uploads the whole `docker/` directory, including `.env`

Create `terraform/terraform.tfvars`. It is gitignored, so never commit it:

```hcl
hcloud_token         = "..."
cloudflare_api_token = "..."
ssh_public_key_path  = "~/.ssh/id_ed25519.pub"
ssh_private_key_path = "~/.ssh/id_ed25519"
mkt_url              = "mariokart.example.com"
portainer_url        = "portainer.mariokart.example.com"
```

Then run:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

This does the following:

1. Creates the SSH key, a firewall (ICMP and TCP 22/80/443 open) and a `cx23` Ubuntu 24.04 server in `nbg1`.
2. Installs Docker CE on first boot via `cloud-init.yml`.
3. Creates `A` records in Cloudflare for `mkt_url` and `portainer_url` that point at the server. The zone is derived from `mkt_url` by dropping its first label, so `mariokart.example.com` uses the zone `example.com`.
4. Uploads `docker/` to `/opt/app` over SSH and runs `deploy_docker.sh`.

If you change anything in `docker/`, run `terraform apply` again to re-upload and redeploy.

The server's IP address is available as the `ip` output.

### Option 2: Manually on a server

On any host with Docker and the Compose plugin:

```bash
cd docker
cp .env.example .env   # fill in real values
./deploy_docker.sh
```

`deploy_docker.sh` runs:

```bash
docker compose -f docker-compose.management.yml -f docker-compose.mariokart.yml -f docker-compose.nginx.yml up -d --pull always
```

The domain names in your `*_VIRTUAL_HOST` variables must resolve to the host, and ports 80 and 443 must be reachable.

### Local test run

To run only the application stack locally with the test values:

```bash
cd docker
docker compose --env-file .env.test -f docker-compose.mariokart.yml up -d --wait
```

The frontend is then at http://localhost:8080 and the backend at http://localhost:3000. To stop it and remove the volumes:

```bash
docker compose --env-file .env.test -f docker-compose.mariokart.yml down -v
```
