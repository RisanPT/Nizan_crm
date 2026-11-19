#!/bin/bash
# crm-deploy: the one thing the CRM developer account may run as root.
#
#   crm-deploy deploy          download the image GitHub built from main, swap
#                              it in, check it serves, roll back if it does not
#   crm-deploy rollback        back to the image before the last deploy
#   crm-deploy status          the container, the live commit, last deploys
#   crm-deploy logs [lines]    nginx's log (default 50 lines)
#
# INSTALLED BY ROOT as /usr/local/bin/crm-deploy (root:root, 0755) and never
# run from the repo: the repo is what the developer can change, so a script
# run from it would hand them root. Re-install by hand after reviewing a
# change to this file.
#
# Nothing is built on this server. GitHub builds the web app and the image
# (.github/workflows/web-image.yml), so a deploy is a small download and an
# nginx restart, safe at any hour on a server shared with TeamN Chat.
set -Eeuo pipefail
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

ROOT=/root/nizan-crm
IMAGE=ghcr.io/risanpt/nizan_crm-web
CONTAINER=nizancrm-nizan-crm-web-1
LOG=/var/log/crm-deploy.log

log() { echo "$(date -u '+%F %T') $*" | tee -a "$LOG"; }
dc() { (cd "$ROOT" && docker compose -p nizancrm "$@"); }
trap 'log "FAILED at line $LINENO: the live site is unchanged unless a step above says otherwise"' ERR

usage() {
  sed -n '4,8p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

exec 9>/run/crm-deploy.lock
flock -n 9 || { echo "Another deploy is running. Try again in a minute." >&2; exit 1; }

# The commit an image was built from, from the label the workflow sets.
revision() {
  local r
  r=$(docker image inspect -f '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$1" 2>/dev/null || true)
  echo "${r:0:7}"
}

serving() {
  sleep 2
  docker exec "$CONTAINER" wget -q -O /dev/null http://127.0.0.1:80/
}

deploy() {
  local running new oldprev
  log "deploy requested by ${SUDO_USER:-root}"
  running=$(docker inspect -f '{{.Image}}' "$CONTAINER" 2>/dev/null || echo none)
  docker pull --quiet "$IMAGE:latest" >/dev/null
  new=$(docker image inspect -f '{{.Id}}' "$IMAGE:latest")
  if [ "$new" = "$running" ]; then
    log "already live: $(revision "$IMAGE:latest"). Nothing to do (is the GitHub build for your commit finished?)"
    return 0
  fi
  if [ "$running" != none ]; then
    oldprev=$(docker image inspect -f '{{.Id}}' "$IMAGE:prev" 2>/dev/null || true)
    docker tag "$running" "$IMAGE:prev"
    # The image two deploys back, now untagged. Removed by ID only: never a
    # prune on this shared server. Fails harmlessly if something still uses it.
    [ -n "$oldprev" ] && [ "$oldprev" != "$running" ] && [ "$oldprev" != "$new" ] && docker rmi "$oldprev" >/dev/null 2>&1 || true
  fi
  dc up -d
  if serving; then
    log "deployed and serving: $(revision "$IMAGE:latest")"
  else
    log "NOT serving. Rolling back."
    [ "$running" != none ] || { log "no previous image to roll back to"; exit 1; }
    docker tag "$IMAGE:prev" "$IMAGE:latest"
    dc up -d
    log "rolled back to $(revision "$IMAGE:prev")"
    exit 1
  fi
}

rollback() {
  docker image inspect "$IMAGE:prev" >/dev/null 2>&1 || { echo "No previous image to roll back to." >&2; exit 1; }
  docker tag "$IMAGE:prev" "$IMAGE:latest"
  dc up -d
  log "rolled back to $(revision "$IMAGE:prev") (by ${SUDO_USER:-root})"
}

status() {
  dc ps
  echo "live commit: $(revision "$(docker inspect -f '{{.Image}}' "$CONTAINER" 2>/dev/null || echo none)")"
  echo "last deploys:"; tail -5 "$LOG" 2>/dev/null || true
}

case "${1:-}" in
  deploy)   deploy ;;
  rollback) rollback ;;
  status)   status ;;
  logs)
    n="${2:-50}"
    [[ "$n" =~ ^[0-9]{1,4}$ ]] || usage
    dc logs --tail "$n" nizan-crm-web
    ;;
  *) usage ;;
esac
