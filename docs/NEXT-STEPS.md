# Next steps — from this lab toward production

You finished the basics in [FUNDAMENTALS.md](FUNDAMENTALS.md) and [ANSIBLE-FUNDAMENTALS.md](ANSIBLE-FUNDAMENTALS.md). This page is your **roadmap**: what to learn next, in order, still using this repo when possible.

**Remember:** “Pro” is less about memorizing modules and more about **safety, testing, secrets, and repeatable process**.

---

## Where you are now

| You can already… | You are not practicing yet (on purpose) |
|------------------|----------------------------------------|
| Run one playbook against many hosts | Real secret management (Vault) |
| Use inventory, groups, roles, vars | Separate dev/staging/prod inventories |
| Use `become`, handlers, `serial` | Automated lint/test in CI |
| Read production-style folder layout | Dynamic cloud inventory |
| Debug SSH and YAML errors | Hardened SSH / no password auth |

That gap is normal. Close it in layers below.

---

## Level 1 — Own this lab (do this first)

**Goal:** Confidence on the machine before adding tools.

- [x] `make up` → `make smoke` → `make site` without reading the README
- [x] Run `make site` **twice**; understand mostly `ok` vs `changed` (idempotency)
- [x] Change `host_vars/web01.yml` → `make site` → see the difference on :8081
- [x] Add a package in `group_vars/all.yml` → verify with `make ssh-web01`
- [x] Add **web03**: `docker-compose.yml`, `.env`, inventory, `host_vars` (README has steps)
- [x] Break something on purpose (wrong port in `.env`), read the error, fix it
- [x] Run from `ansible/` with `--limit web02` and `--tags webserver` (see ANSIBLE-FUNDAMENTALS §13)

**Done when:** You can add a node and explain control node vs managed node to someone else.

---

## Level 2 — Pro habits (same repo, small additions)

**Goal:** Behaviors teams expect before anyone trusts you with prod.

### 2.1 Secrets — Ansible Vault

- [x] Learn: [vault-encrypted variables](https://docs.ansible.com/ansible/latest/vault_guide/index.html)
- [ ] Move at least one sensitive value out of plain `.env` / YAML (e.g. practice password) into `group_vars/all/vault.yml` (encrypted)
- [ ] Run playbooks with `ansible-playbook --ask-vault-pass` or a vault password file **outside** git
- [ ] Rule for real life: **no private keys or prod passwords in git**, even in a “practice” repo you might push

### 2.2 Safety flags

- [x] `ansible-playbook playbooks/site.yml --check` (dry run)
- [x] Same command with `--diff` (show file changes)
- [x] `ansible-playbook ... --limit web01` before touching the whole group

### 2.3 Lint

- [ ] Install `ansible-lint` and `yamllint` locally
- [ ] Add a `make lint` target (future task for this repo)
- [ ] Fix findings on `ansible/playbooks` and `ansible/roles`

### 2.4 Environments

- [ ] Split inventory idea: `inventories/lab/hosts.yml` vs `inventories/staging/hosts.yml` (same roles, different hosts/vars)
- [ ] Point `ansible.cfg` or `ANSIBLE_INVENTORY` at the right tree per environment
- [ ] Never use one `.env` for both lab and anything you call “staging” or “prod”

**Done when:** You can run `--check --diff`, decrypt vault vars, and explain which inventory is “lab.”

---

## Level 3 — Test and automate (still small scope)

**Goal:** Prove roles work before you run them on important servers.

### 3.1 Molecule

- [ ] Pick the `common` role; add a minimal Molecule scenario (Docker driver fits this lab)
- [ ] `molecule test` before you change the role
- [ ] Document: “how to run tests” in README

### 3.2 CI (optional but high value)

- [ ] GitHub Actions (or GitLab CI): on push, run `ansible-lint` + `yamllint`
- [ ] Optional: Molecule in CI (slower; add after local Molecule works)

**Done when:** A PR cannot merge with broken YAML/lint (even if only you on the repo).

---

## Level 4 — Scale and operations (when you have real targets)

**Goal:** Patterns for many hosts and real orgs—not required to finish the Docker lab.

| Topic | Why |
|-------|-----|
| **Dynamic inventory** | AWS/Azure/GCP plugins; hosts come from the cloud API |
| **Execution platform** | AWX, Ansible Semaphore, or Controller — schedules, credentials, audit |
| **Rolling deploys** | Health checks after tasks; canary host in `serial` / `--limit` |
| **Hardening roles** | SSH, firewall, unattended upgrades; remove NOPASSWD / password SSH in real systems |
| **Observability** | Know when config drifted; logs for who ran which playbook |

Study these after Level 2–3; they build on the same inventory/playbook/role mental model.

---

## What “bigger / pro” expects (checklist mindset)

Use this when you interview or join a team—not as day-one homework.

- Secrets in Vault or a secrets manager, not `.env` in the repo
- Separate inventories per environment
- Lint + (ideally) Molecule in CI
- Documented rollback / “how to undo”
- Least privilege: sudo only where needed
- Someone else can run `make site` (or your CI job) from docs alone

---

## Suggested order (one line)

**Level 1 (lab mastery) → Vault + check/diff/limit → lint → env split → Molecule → CI → cloud inventory / AWX when you have real infra.**

---

## Optional upgrades for *this* repository

When you are ready, we can add to the playground (pick any):

1. `ansible/group_vars/all/vault.yml.example` + docs for Vault workflow
2. `make lint` (`ansible-lint`, `yamllint`)
3. `inventories/lab/` and `inventories/staging/` layout
4. Molecule scenario for `roles/common`

Track your progress by checking boxes in this file in git.

---

## Links

- [FUNDAMENTALS.md](FUNDAMENTALS.md) — Make, files, `.env`
- [ANSIBLE-FUNDAMENTALS.md](ANSIBLE-FUNDAMENTALS.md) — Ansible concepts in this lab
- [README.md](../README.md) — Quick start