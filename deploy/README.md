# Hosting: erp.teamnmakeovers.com

(The old address, crm.teamnmakeovers.com, redirects here.)

The web app runs on the Hostinger VPS (187.127.179.74), which it shares with
TeamN Chat (production) and Weddesy. Nothing is built on that server.

```
merge to main ─▶ GitHub Actions builds the web app ─▶ image ghcr.io/risanpt/nizan_crm-web:latest
                       (Actions tab, ~5–8 min)                          │
the server checks every 2 minutes ─▶ downloads it, swaps it in, checks it serves, rolls back if not
```

## Deploying (developer)

Merge to `main`. That is all: about 10 minutes later it is live. Check with
`ssh crm status` (it shows the live commit), and test in a private window or
after Ctrl/Cmd+Shift+R.

| Command | What it does |
|---|---|
| `ssh crm deploy` | Put the newest build live now instead of within 2 minutes |
| `ssh crm rollback` | Back to the build before. Automatic deploys then leave that bad build alone and resume with your next merge |
| `ssh crm status` | The container, the live commit, the last deploys |
| `ssh crm logs 100` | nginx's last 100 log lines |

If the build on GitHub fails (a red ✗ in Actions, and GitHub emails you),
nothing changes on the site. If a build passes on GitHub but the server's
check fails, the server rolls back by itself and does not try that build
again; `ssh crm status` shows it.

Everyone who deploys shares the account `crm-dev`, each with their own key.
It can run only these commands: no shell, no file access, no other app's
commands. The deploy log names the person (`ssh crm status`).

## Who has access (server owner, as root)

| Command | |
|---|---|
| `crm-access list` | Everyone with access and their key fingerprint |
| `crm-access add <name> '<their .pub line>'` | Give someone access. One key per computer: `risan`, `risan-mac` |
| `crm-access remove <name>` | Take it away, at once |

A new person makes a key (`ssh-keygen -t ed25519 -f ~/.ssh/crm_deploy -C <name>`),
sends only the `.pub` line, and adds the `Host crm` block to `~/.ssh/config`.
Someone leaving: `crm-access remove` here, and remove them from the GitHub
repo too, since merging to `main` is itself a deploy.

The API address is `.env.production` (`API_BASE_URL`), baked in at build time.
The build stops if it is not an `https://` address.

## Files

| File | Where it is used |
|---|---|
| `.github/workflows/web-image.yml` | GitHub: builds and publishes the image |
| `deploy/web.Dockerfile`, `deploy/nginx.conf` | Inside the image |
| `deploy/server/docker-compose.yml` | Server: `/root/nizan-crm/docker-compose.yml` |
| `deploy/server/crm-deploy.sh` | Server: `/usr/local/bin/crm-deploy`, installed by root |
| `deploy/server/crm-access.sh` | Server: `/usr/local/bin/crm-access`, root only (who may deploy) |
| `deploy/server/crm-deploy.cron` | Server: `/etc/cron.d/crm-deploy` (the automatic deploys) |
| `deploy/server/Caddyfile.snippet` | TeamN's Caddyfile |

Changes to anything under `deploy/server/` take effect only when the server
owner reviews them and copies them to the server by hand. That is deliberate:
those files decide what runs as root on a shared server.

Rules of the shared server: no published ports, no container named `app`,
`caddy` or `web`, memory and CPU limits on everything, no `docker ... prune`.
