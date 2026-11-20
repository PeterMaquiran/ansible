SHELL := /bin/bash
ROOT := $(CURDIR)
ANSIBLE_DIR := $(ROOT)/ansible
ENV_FILE := $(ROOT)/.env

define with_env
	set -a && source "$(ENV_FILE)" && set +a
endef

export ANSIBLE_CONFIG ?= $(ANSIBLE_DIR)/ansible.cfg

.PHONY: help up down ps logs ssh-web01 ssh-web02 galaxy smoke site ping control-shell clean

help:
	@echo "Targets:"
	@echo "  make up            Start web01 + web02 (SSH targets)"
	@echo "  make galaxy        Install Ansible collections"
	@echo "  make smoke         Ping all hosts from your Mac (one controller, many nodes)"
	@echo "  make site          Full baseline + nginx on every webserver"
	@echo "  make control-shell Open bash in ansible-control container (profile control)"
	@echo "  make ssh-web01     Manual SSH to first node"

up:
	$(with_env); docker compose --env-file "$(ENV_FILE)" up -d --build

down:
	$(with_env); docker compose --env-file "$(ENV_FILE)" down

ps:
	$(with_env); docker compose --env-file "$(ENV_FILE)" ps

logs:
	$(with_env); docker compose --env-file "$(ENV_FILE)" logs -f web01 web02

galaxy:
	$(with_env); export ANSIBLE_COLLECTIONS_PATH="$(ANSIBLE_DIR)/collections"; \
	cd "$(ANSIBLE_DIR)" && ansible-galaxy collection install -r collections/requirements.yml -p collections

smoke: galaxy
	$(with_env); export ANSIBLE_PRIVATE_KEY_HOST_PATH="$(ROOT)/$${ANSIBLE_PRIVATE_KEY_HOST_PATH#./}"; \
	export ANSIBLE_PRIVATE_KEY_FILE="$$ANSIBLE_PRIVATE_KEY_HOST_PATH"; \
	cd "$(ANSIBLE_DIR)" && ansible-playbook playbooks/smoke.yml

site: galaxy
	$(with_env); export ANSIBLE_PRIVATE_KEY_HOST_PATH="$(ROOT)/$${ANSIBLE_PRIVATE_KEY_HOST_PATH#./}"; \
	export ANSIBLE_PRIVATE_KEY_FILE="$$ANSIBLE_PRIVATE_KEY_HOST_PATH"; \
	cd "$(ANSIBLE_DIR)" && ansible-playbook playbooks/site.yml

ping: galaxy
	$(with_env); export ANSIBLE_PRIVATE_KEY_HOST_PATH="$(ROOT)/$${ANSIBLE_PRIVATE_KEY_HOST_PATH#./}"; \
	export ANSIBLE_PRIVATE_KEY_FILE="$$ANSIBLE_PRIVATE_KEY_HOST_PATH"; \
	cd "$(ANSIBLE_DIR)" && ansible managed -m ping

ssh-web01:
	$(with_env); ssh -i "$(ROOT)/$${ANSIBLE_PRIVATE_KEY_HOST_PATH#./}" -p "$$WEB01_SSH_PORT" "$$ANSIBLE_SSH_USER@$$WEB01_SSH_HOST"

ssh-web02:
	$(with_env); ssh -i "$(ROOT)/$${ANSIBLE_PRIVATE_KEY_HOST_PATH#./}" -p "$$WEB02_SSH_PORT" "$$ANSIBLE_SSH_USER@$$WEB02_SSH_HOST"

control-shell:
	$(with_env); docker compose --env-file "$(ENV_FILE)" --profile control run --rm control

clean:
	$(with_env); docker compose --env-file "$(ENV_FILE)" down -v --remove-orphans