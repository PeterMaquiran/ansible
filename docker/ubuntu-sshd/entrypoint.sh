#!/usr/bin/env bash
set -euo pipefail

ANSIBLE_USER="${ANSIBLE_USER:-ansible}"
AUTHORIZED_KEYS="${AUTHORIZED_KEYS:-}"

if [[ -n "${AUTHORIZED_KEYS}" ]]; then
  printf '%s\n' "${AUTHORIZED_KEYS}" > "/home/${ANSIBLE_USER}/.ssh/authorized_keys"
  chmod 600 "/home/${ANSIBLE_USER}/.ssh/authorized_keys"
  chown "${ANSIBLE_USER}:${ANSIBLE_USER}" "/home/${ANSIBLE_USER}/.ssh/authorized_keys"
fi

exec /usr/sbin/sshd -D -e