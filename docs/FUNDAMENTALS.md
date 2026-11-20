# Fundamentals (start here)

This guide explains **this project** in plain language. If you are new to `make`, folders, or `.env`, read this before [README.md](../README.md).

**The big idea:** You run short commands like `make up` on your computer. Those commands start fake servers in Docker, then Ansible (from one “control” machine) logs into each server and sets them up the same way—like a teacher handing the same worksheet to every student in a class.

**Learning Ansible itself?** Continue with [ANSIBLE-FUNDAMENTALS.md](ANSIBLE-FUNDAMENTALS.md).

---

## 1. What is `make`?

`make` is a small program that reads a file named **`Makefile`** in your project folder.

The Makefile is a **recipe book**. Each recipe has a **name** and **steps**.

| You type | Recipe name | What it does (simple) |
|----------|-------------|------------------------|
| `make` or `make help` | `help` | Prints the list of recipes |
| `make up` | `up` | Starts the two Ubuntu servers in Docker |
| `make down` | `down` | Stops those servers |
| `make ps` | `ps` | Shows which containers are running |
| `make logs` | `logs` | Shows log output from the servers |
| `make galaxy` | `galaxy` | Downloads extra Ansible tools (one-time setup) |
| `make smoke` | `smoke` | Tests: can Ansible talk to every server? |
| `make ping` | `ping` | Same idea as smoke, even shorter |
| `make site` | `site` | Full setup: packages, nginx, web pages on all servers |
| `make ssh-web01` | `ssh-web01` | Opens SSH to the first server |
| `make ssh-web02` | `ssh-web02` | Opens SSH to the second server |
| `make control-shell` | `control-shell` | Opens a shell inside the optional Ansible control container |
| `make clean` | `clean` | Stops servers and removes extra Docker data |

**Why use `make` instead of typing long commands?**

- You do not have to remember paths like `ansible/playbooks/site.yml`.
- Everyone on the project runs the **same** steps.
- Some recipes depend on others (see below).

### What does `make smoke` really mean?

`make` looks for a section in the Makefile that starts with:

```makefile
smoke: galaxy
```

That means:

1. Run the `galaxy` recipe first (if needed).
2. Then run the commands under `smoke:`.

So **`make smoke`** = “install collections if this recipe says so, load settings from `.env`, then run the smoke test playbook.”

### Words you will see in the Makefile

| Word | Meaning |
|------|---------|
| **Target** | The name after `make`, like `up` or `site` |
| **Recipe** | The indented commands under a target |
| **Variable** | A shortcut, like `ANSIBLE_DIR := $(ROOT)/ansible` |
| **`.PHONY`** | Targets that are not real files—just command names |

---

## 2. How this project’s files are organized

Think of the project as **four layers**:

```text
your-project/
├── Makefile              ← shortcuts you run (make up, make site, …)
├── .env                  ← settings (ports, usernames, key paths)
├── docker-compose.yml    ← defines web01 + web02 + optional control container
├── docker/               ← how Docker images are built
├── ssh/                  ← SSH key pair (control machine → servers)
└── ansible/              ← all Ansible config and playbooks
```

### Layer 1 — Settings you can change without digging into code

| File | Job |
|------|-----|
| **`.env`** | One list of settings: SSH ports, user `ansible`, password (practice only), path to SSH key |
| **`docker-compose.yml`** | Says “run two Ubuntu boxes, wire ports, attach network” |

### Layer 2 — Docker (the fake servers)

| Path | Job |
|------|-----|
| **`docker/ubuntu-sshd/`** | Builds Ubuntu + SSH so Ansible can log in |
| **`docker/ansible-control/`** | Optional image that has Ansible installed |

Each running container is a **node** (server). We name them **web01** and **web02**.

### Layer 3 — SSH keys (who is allowed to log in)

| Path | Job |
|------|-----|
| **`ssh/ansible_control_ed25519`** | Private key — stays on the **control** side (your Mac or control container) |
| **`ssh/ansible_control_ed25519.pub`** | Public key — copied onto web01 and web02 |

Same idea as a house key: you keep one copy; the lock (server) only needs the matching public part.

### Layer 4 — Ansible (automation)

| Path | Job |
|------|-----|
| **`ansible/ansible.cfg`** | Default options for every Ansible command |
| **`ansible/inventory/hosts.yml`** | **Who** exists (web01, web02) and how to reach them |
| **`ansible/group_vars/`** | Settings for **groups** of servers (all servers vs web servers only) |
| **`ansible/host_vars/`** | Settings for **one** server (e.g. web01’s display name) |
| **`ansible/playbooks/`** | **What to do** — lists of tasks (`smoke.yml`, `site.yml`) |
| **`ansible/roles/`** | Reusable bundles of tasks (`common`, `webserver`) |
| **`ansible/collections/requirements.yml`** | List of extra Ansible modules to download |

**One control node, many targets:** Your Mac (or the `control` container) runs Ansible **once**. The playbook loops over **every host** in the inventory. You do not log into web02 by hand to copy settings—Ansible does it for you.

```text
        [ Control: your Mac or "control" container ]
                         |
                         |  SSH (same key, same user)
                 +-------+-------+
                 |               |
              web01            web02
           (Docker)           (Docker)
```

---

## 3. How `make` “reads” other files

`make` **does not** automatically know about Ansible or Docker. The **Makefile tells the shell** to open other files and programs. Here is the chain for `make site`:

```text
You: make site
        |
        v
Makefile runs "with_env"
        |
        v
Shell loads .env (source)  -------->  variables like WEB01_SSH_PORT exist
        |
        v
Makefile runs "galaxy" (dependency) -->  reads ansible/collections/requirements.yml
        |
        v
Shell exports ANSIBLE_PRIVATE_KEY_FILE -->  points at ssh/ansible_control_ed25519
        |
        v
ansible-playbook playbooks/site.yml
        |
        +--> reads ansible/ansible.cfg
        +--> reads ansible/inventory/hosts.yml  (also reads .env via lookup('env', ...))
        +--> reads group_vars, host_vars, roles
        |
        v
Ansible SSH to web01 and web02 and changes them
```

### 3.1 Loading `.env` (`with_env`)

At the top of the Makefile:

```makefile
define with_env
	set -a && source "$(ENV_FILE)" && set +a
endef
```

In English:

1. **`source .env`** — the shell reads each line like `WEB01_SSH_PORT=2221` and stores it.
2. **`set -a`** — “export everything that gets set,” so child programs (docker, ansible) can see those names.

So when you run `make up`, Docker Compose also gets `--env-file .env`, so **the same numbers** are used to map ports like `2221:22`.

### 3.2 Pointing Ansible at the right folders

The Makefile sets:

```makefile
export ANSIBLE_CONFIG ?= $(ANSIBLE_DIR)/ansible.cfg
```

So when Ansible starts, it opens **`ansible/ansible.cfg`**, which says “inventory is `inventory/hosts.yml`” and “roles live in `roles/`.”

### 3.3 Inventory reading `.env` again

In `ansible/inventory/hosts.yml` you will see things like:

```yaml
ansible_host: "{{ lookup('env', 'WEB01_SSH_HOST') | default('127.0.0.1', true) }}"
```

That means: “When Ansible runs, look up the environment variable `WEB01_SSH_HOST`.” Those variables were set when `make` sourced `.env`. So **Makefile → `.env` → Ansible inventory** all stay in sync.

### 3.4 Docker Compose reading `.env`

`docker-compose.yml` uses `${WEB01_SSH_PORT}` style placeholders. Compose replaces them with values from `.env` when you run `docker compose`.

**Summary table — who reads what**

| File | Read by | Why |
|------|---------|-----|
| `.env` | `make` (shell), Docker Compose, Ansible inventory | One place for ports and usernames |
| `Makefile` | `make` command | Shortcuts and order of steps |
| `docker-compose.yml` | Docker Compose | Which containers to run |
| `ansible/ansible.cfg` | Ansible | Defaults for every playbook |
| `ansible/inventory/hosts.yml` | Ansible | List of servers |
| `ansible/playbooks/*.yml` | `ansible-playbook` | Steps to execute |
| `ansible/roles/**` | Playbooks | Organized tasks and templates |

---

## 4. Simple workflow (what to run and when)

1. **`make up`** — Start lab servers (do this first).
2. **`make galaxy`** — Install Ansible collections (first time, or after you change `requirements.yml`).
3. **`make smoke`** or **`make ping`** — Check connectivity only.
4. **`make site`** — Apply real configuration to **all** hosts.
5. **`make down`** — Stop the lab when you are done.

---

## 5. Tiny glossary

| Term | Simple definition |
|------|-------------------|
| **Container** | A small virtual server running inside Docker on your Mac |
| **Control node** | The machine that runs Ansible (not configured by the playbooks) |
| **Managed node / target** | A server Ansible configures (web01, web02) |
| **Playbook** | A YAML file that lists tasks Ansible should run |
| **Role** | A folder of reusable tasks (like a chapter in the recipe book) |
| **Inventory** | The official list of servers Ansible may touch |
| **SSH** | Secure way to open a remote shell and run commands |

---

## 6. Where to go next

- [ANSIBLE-FUNDAMENTALS.md](ANSIBLE-FUNDAMENTALS.md) — inventory, playbooks, roles, variables, idempotency.
- [NEXT-STEPS.md](NEXT-STEPS.md) — what to learn after this lab (checklist).
- [README.md](../README.md) — quick commands and production-style patterns.
- Open `Makefile` and match each target name to a section in this doc.
- Change something small in `.env` (e.g. `WEB01_SSH_PORT`), run `make down` then `make up`, and run `make smoke` to see inventory pick up the new value.

If a command fails, read the error from **bottom to top**: usually the last line says which file or host was the problem.