#!/bin/bash
# crm-deploy: the one thing the CRM developer account may run as root.
#
#   crm-deploy deploy          put the newest build of main live now (cron
#                              does the same every 2 minutes on its own)
#   crm-deploy rollback        back to the build before; automatic deploys
#                              skip the rolled-back build until a newer one
#   crm-deploy status          the container, the live commit, last deploys
#   crm-deploy logs [lines]    nginx's log (default 50 lines)
#
# INSTALLED BY ROOT as /usr/local/bin/crm-deploy (root:root, 0755) and never
# run from the repo: the repo is what the developer can change, so a script
# run from it would hand them root. Re-install by hand after reviewing a
# change to this file.
#
# Nothing is built on this server. GitHub builds the web app and the image
# (.github/workflows/web-image.yml), so a deploy is a small download and a
# one-second container swap (Caddy holds requests through it), safe at any
# hour on a server shared with TeamN Chat. `crm-deploy auto` (from /etc/cron.d/crm-deploy) is the same as deploy
# but silent when there is nothing new, and it leaves alone a build that was
# rolled back or failed its check, so a bad build is never put back by itself.
set -Eeuo pipefail
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

ROOT=/root/nizan-crm
IMAGE=ghcr.io/risanpt/nizan_crm-web
CONTAINER=nizancrm-nizan-crm-web-1
LOG=/var/log/crm-deploy.log
STATE=/var/lib/crm-deploy
SKIP=$STATE/skip   # the image ID automatic deploys must not put live

log() { echo "$(date -u '+%F %T') $*" | tee -a "$LOG"; }
dc() { (cd "$ROOT" && docker compose -p nizancrm "$@"); }
trap 'log "FAILED at line $LINENO: the live site is unchanged unless a step above says otherwise"' ERR

usage() {
  sed -n '4,10p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

# Who is deploying. crm-dev is one account shared by several people; each
# person's key (added with crm-access) runs `crm-deploy --as <name> ...`, so
# the log names the person. Only the first --as counts: a second one typed by
# the developer is not a command, so it stops at usage.
WHO=${SUDO_USER:-root}
if [ "${1:-}" = --as ]; then
  [[ "${2:-}" =~ ^[a-z0-9][a-z0-9._-]{0,31}$ ]] || usage
  WHO=$2
  shift 2
fi

exec 9>/run/crm-deploy.lock
if ! flock -n 9; then
  [ "${1:-}" = auto ] && exit 0
  echo "Another deploy is running. Try again in a minute." >&2
  exit 1
fi
mkdir -p "$STATE"

# The commit an image was built from, from the label the workflow sets.
revision() {
  local r
  r=$(docker image inspect -f '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$1" 2>/dev/null || true)
  echo "${r:0:7}"
}

running_image() { docker inspect -f '{{.Image}}' "$CONTAINER" 2>/dev/null || echo none; }

serving() {
  sleep 2
  docker exec "$CONTAINER" wget -q -O /dev/null http://127.0.0.1:80/
}

deploy() {
  local mode=$1 running new oldprev
  running=$(running_image)
  if ! docker pull --quiet "$IMAGE:latest" >/dev/null 2>&1; then
    [ "$mode" = auto ] && return 0
    log "could not download $IMAGE:latest (has GitHub finished a build of main? is the package public?)"
    exit 1
  fi
  new=$(docker image inspect -f '{{.Id}}' "$IMAGE:latest")
  if [ "$new" = "$running" ]; then
    [ "$mode" = auto ] || log "already live: $(revision "$new"). Nothing to do (is the GitHub build for your commit finished?)"
    return 0
  fi
  if [ "$mode" = auto ] && [ "$new" = "$(cat "$SKIP" 2>/dev/null || true)" ]; then
    return 0
  fi
  log "deploy ($mode, $WHO): $(revision "$running") -> $(revision "$new")"
  if [ "$running" != none ]; then
    oldprev=$(docker image inspect -f '{{.Id}}' "$IMAGE:prev" 2>/dev/null || true)
    docker tag "$running" "$IMAGE:prev"
    # The image two deploys back, now untagged. Removed by ID only: never a
    # prune on this shared server. Fails harmlessly if something still uses it.
    [ -n "$oldprev" ] && [ "$oldprev" != "$running" ] && [ "$oldprev" != "$new" ] && docker rmi "$oldprev" >/dev/null 2>&1 || true
  fi
  dc up -d
  if serving; then
    rm -f "$SKIP"
    log "deployed and serving: $(revision "$new")"
  else
    echo "$new" > "$SKIP"
    log "NOT serving. Rolling back; automatic deploys will skip this build until a newer one."
    [ "$running" != none ] || { log "no previous image to roll back to"; exit 1; }
    docker tag "$IMAGE:prev" "$IMAGE:latest"
    dc up -d
    log "rolled back to $(revision "$IMAGE:prev")"
    exit 1
  fi
}

rollback() {
  local running
  docker image inspect "$IMAGE:prev" >/dev/null 2>&1 || { echo "No previous image to roll back to." >&2; exit 1; }
  running=$(running_image)
  if [ "$running" = "$(docker image inspect -f '{{.Id}}' "$IMAGE:prev")" ]; then
    echo "Already on the previous build ($(revision "$running")). Only one step back is kept." >&2
    exit 1
  fi
  [ "$running" = none ] || echo "$running" > "$SKIP"
  docker tag "$IMAGE:prev" "$IMAGE:latest"
  dc up -d
  log "rolled back to $(revision "$IMAGE:prev") (by $WHO). Automatic deploys resume with the next build of main."
}

status() {
  dc ps
  echo "live commit: $(revision "$(running_image)")"
  echo "last deploys:"; tail -5 "$LOG" 2>/dev/null || true
}

case "${1:-}" in
  deploy)   deploy manual ;;
  auto)     deploy auto ;;
  rollback) rollback ;;
  status)   status ;;
  logs)
    n="${2:-50}"
    [[ "$n" =~ ^[0-9]{1,4}$ ]] || usage
    dc logs --tail "$n" nizan-crm-web
    ;;
  *) usage ;;
esac
