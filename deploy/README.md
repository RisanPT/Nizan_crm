# Hosting: crm.teamnmakeovers.com

The web app runs on the Hostinger VPS (187.127.179.74), which it shares with
TeamN Chat (production) and Weddesy. Nothing is built on that server.

```
push to main ─▶ GitHub Actions builds the web app ─▶ image ghcr.io/risanpt/nizan_crm-web:latest
                        (Actions tab, ~5–8 min)                         │
ssh crm deploy ─▶ the server downloads that image, swaps it in, checks it serves, rolls back if not
```

## Deploying (developer)

1. Merge to `main`. Only `main` is published.
2. Wait for the green ✅ on **Web image** in the repo's **Actions** tab.
3. `ssh crm deploy`. Any hour; it takes seconds.
4. Test in a private window or after Ctrl/Cmd+Shift+R.

| Command | What it does |
|---|---|
| `ssh crm deploy` | Puts the latest `main` build live |
| `ssh crm rollback` | Back to the build before the last deploy |
| `ssh crm status` | The container, the live commit, the last deploys |
| `ssh crm logs 100` | nginx's last 100 log lines |

The `crm-dev` account can run only those four. It has no shell, no file
access and no other app's commands.

The API address is `.env.production` (`API_BASE_URL`), baked in at build time.
The build stops if it is not an `https://` address.

## Files

| File | Where it is used |
|---|---|
| `.github/workflows/web-image.yml` | GitHub: builds and publishes the image |
| `deploy/web.Dockerfile`, `deploy/nginx.conf` | Inside the image |
| `deploy/server/docker-compose.yml` | Server: `/root/nizan-crm/docker-compose.yml` |
| `deploy/server/crm-deploy.sh` | Server: `/usr/local/bin/crm-deploy`, installed by root |
| `deploy/server/Caddyfile.snippet` | TeamN's Caddyfile |

Changes to anything under `deploy/server/` take effect only when the server
owner reviews them and copies them to the server by hand. That is deliberate:
those files decide what runs as root on a shared server.

Rules of the shared server: no published ports, no container named `app`,
`caddy` or `web`, memory and CPU limits on everything, no `docker ... prune`.
