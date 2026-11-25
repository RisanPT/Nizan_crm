#!/bin/bash
# crm-access: who may deploy the CRM. Run as root on the server.
#
#   crm-access list                      everyone with access, and their key
#   crm-access add <name> '<public key>' give a person access (one key each;
#                                        a second computer is a second name)
#   crm-access remove <name>             take it away, at once
#
# INSTALLED BY ROOT as /usr/local/bin/crm-access (root:root, 0755). NOT in
# sudoers: the developers cannot run it, only root can.
#
# Everyone shares the account crm-dev, which can run nothing but crm-deploy.
# Each key's line makes it run `crm-deploy --as <name>`, so the deploy log
# shows who did what. The key file is owned by root, so crm-dev cannot change
# it even if it ever had a shell.
set -euo pipefail
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

ACCOUNT=crm-dev
DIR=/home/$ACCOUNT/.ssh
KEYS=$DIR/authorized_keys
OPTS='no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty,no-user-rc'

usage() { sed -n '4,8p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
[ "$(id -u)" = 0 ] || { echo "Run as root." >&2; exit 1; }
id "$ACCOUNT" >/dev/null 2>&1 || { echo "The account $ACCOUNT does not exist yet (see deploy/README.md)." >&2; exit 1; }

valid_name() {
  [[ "${1:-}" =~ ^[a-z0-9][a-z0-9._-]{0,31}$ ]] || {
    echo "Name: lower-case letters, digits, . _ - only, up to 32 (e.g. risan or risan-mac)." >&2
    exit 1
  }
}

# Root owns the folder and the file; sshd accepts that and crm-dev cannot write.
fix_perms() {
  install -d -m 755 -o root -g root "$DIR"
  touch "$KEYS"
  chown root:root "$KEYS"
  chmod 644 "$KEYS"
}

# Fixed-string match on the --as part of a line, so "a.b" never matches "axb".
marker() { printf -- '--as %s $SSH_ORIGINAL_COMMAND' "$1"; }
has_name() { grep -qF -- "$(marker "$1")" "$KEYS"; }

list() {
  fix_perms
  if [ ! -s "$KEYS" ]; then echo "Nobody has access."; return; fi
  echo "name                              key fingerprint"
  # Each key's comment is the person's name (add sets it).
  ssh-keygen -l -f "$KEYS" | awk '{printf "%-33s %s\n", $3, $2}'
}

add() {
  local name=${1:-} key=${2:-} type data fp
  valid_name "$name"
  [ -n "$key" ] || usage
  if grep -q 'PRIVATE KEY' <<<"$key"; then
    echo "That is a PRIVATE key. Do not use it: ask for the .pub file instead, and have that person make a new key, since this one has been shared." >&2
    exit 1
  fi
  read -r type data _ <<<"$key"
  case "$type" in
    ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|ssh-rsa) ;;
    *) echo "That does not look like a public key: it should start with ssh-ed25519." >&2; exit 1 ;;
  esac
  fp=$(ssh-keygen -l -f <(echo "$type $data") 2>/dev/null | awk '{print $2}') || true
  [ -n "$fp" ] || { echo "That public key is damaged (copied only part of it?)." >&2; exit 1; }
  fix_perms
  has_name "$name" && { echo "$name already has access. Remove it first to change the key." >&2; exit 1; }
  grep -qF " $type $data " "$KEYS" && { echo "That key is already added under another name." >&2; exit 1; }
  printf 'command="sudo /usr/local/bin/crm-deploy --as %s $SSH_ORIGINAL_COMMAND",%s %s %s %s\n' \
    "$name" "$OPTS" "$type" "$data" "$name" >>"$KEYS"
  echo "Added $name ($fp). They can now run: ssh crm status"
}

remove() {
  local name=${1:-} tmp
  valid_name "$name"
  fix_perms
  has_name "$name" || { echo "$name does not have access."; exit 1; }
  tmp=$(mktemp "$DIR/.keys.XXXXXX")
  grep -vF -- "$(marker "$name")" "$KEYS" >"$tmp" || true
  chown root:root "$tmp"; chmod 644 "$tmp"
  mv "$tmp" "$KEYS"
  echo "Removed $name. New connections with their key are refused from now on."
}

case "${1:-}" in
  list)   list ;;
  add)    add "${2:-}" "${3:-}" ;;
  remove) remove "${2:-}" ;;
  *) usage ;;
esac
