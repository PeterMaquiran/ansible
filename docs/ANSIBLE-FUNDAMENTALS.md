# Ansible fundamentals (plain language)

This guide explains **Ansible** using **this lab**. Read [FUNDAMENTALS.md](FUNDAMENTALS.md) first if `make` and file layout are still new.

**The big idea:** You describe the **desired state** of your servers in YAML files (“install nginx,” “create this file”). Ansible compares that to what is already on each server and only changes what is needed—on **every** server in your list, from **one** place.

---

## 1. What is Ansible?

Ansible is a tool that:

1. Connects to remote machines over **SSH** (or runs locally).
2. Runs small programs called **modules** (install a package, copy a file, start a service).
3. Does this for **many hosts** in one command.

You do **not** manually log into web01, then web02, and repeat the same clicks. You run **one playbook**; Ansible visits each host in the **inventory**.

### Control node vs managed nodes

| Role | In this lab | In the inventory? |
|------|-------------|-------------------|
| **Control node** | Your Mac or the `control` Docker container | **No** — it runs Ansible, it is not configured by these playbooks |
| **Managed node** | `web01`, `web02` (Ubuntu in Docker) | **Yes** — listed under `webservers` |

That pattern is how it works in real companies: a small number of controllers, many servers.

---

## 2. The main building blocks

Think of Ansible like a **school trip**:

| Piece | Real-world picture | In this project |
|-------|--------------------|-----------------|
| **Inventory** | Class roster (who is going) | `ansible/inventory/hosts.yml` |
| **Playbook** | Day plan for the trip | `ansible/playbooks/site.yml`, `smoke.yml` |
| **Play** | One part of the day (“visit museum”) | Each `- name: ...` block with `hosts:` inside a playbook |
| **Task** | One instruction (“line up”) | One `- name:` under `tasks:` or inside a role |
| **Module** | The actual tool Ansible uses | e.g. `ansible.builtin.apt`, `ansible.builtin.template` |
| **Role** | Reusable chapter of tasks | `ansible/roles/common`, `ansible/roles/webserver` |
| **Variable** | Settings that can change | `group_vars/`, `host_vars/`, `.env` |
| **Handler** | “Do this only if something changed” | e.g. reload nginx after config change |
| **Fact** | Info Ansible learns about a host | OS version, IP, disk (often auto-gathered) |

---

## 3. How your inventory is shaped

Open `ansible/inventory/hosts.yml`. It is a **tree** of groups:

```text
all
 └── managed          ← every server Ansible may touch in this lab
      └── webservers   ← servers that run the web role
           ├── web01
           └── web02
```

- `hosts:` under a group = real machines (or containers).
- `children:` = other groups nested inside a group.
- `ansible_host` **/** `ansible_port` = where SSH should connect (from `.env` via `lookup('env', ...)`).

**Groups matter** because playbooks can target them:

- `hosts: managed` → both web01 and web02.
- `hosts: webservers` → same two, but only servers in the web group (here, identical).

In a bigger company you might have `databases`, `cache`, `monitoring`—same idea.

---

## 4. What is YAML?

Ansible files are mostly **YAML** (`.yml`). Rules that matter at your level:

- **Indentation with spaces** (usually 2 spaces)—not tabs.
- **Lists** use a dash:
  ```yaml
  common_packages:
    - curl
    - htop
  ```
- **Key: value** pairs:
  ```yaml
  timezone: UTC
  ```
- `---` at the top = start of a YAML document (optional but common).

If Ansible says “YAML syntax error,” check indentation first.

---

## 5. Walking through one playbook: `smoke.yml`

File: `ansible/playbooks/smoke.yml`

| Line / idea | Meaning |
|-------------|---------|
| `hosts: managed` | Run on every host in the `managed` group |
| `gather_facts: false` | Skip collecting system info (faster test) |
| `ansible.builtin.ping` | Not ICMP ping—means “can Ansible run Python/SSH on this host?” |
| `ansible.builtin.debug` | Print a message (for learning) |

When you run `make smoke`, Ansible:

1. Reads inventory → finds web01, web02.
2. SSH to web01 → run ping module → run debug.
3. SSH to web02 → same steps.

**One run, many targets.** That is the core skill you are practicing.

---

## 6. Walking through `site.yml` (closer to production)

File: `ansible/playbooks/site.yml`

### Play 1 — baseline on everyone

```yaml
hosts: managed
become: true
roles:
  - role: common
```

| Keyword | Meaning |
|---------|---------|
| `become: true` | Use `sudo` on the remote server (user `ansible` has NOPASSWD in Docker) |
| `roles` | Run the task lists inside `roles/common/` |

The **common** role installs packages, sets timezone, writes `/etc/motd`.

### Play 2 — web stack on webservers

```yaml
hosts: webservers
become: true
serial: 1
roles:
  - role: webserver
```

| Keyword | Meaning |
|---------|---------|
| `serial: 1` | Update **one server at a time** (safer in production—web02 waits until web01 finishes) |
| `tags: [webserver, app]` | Lets you run only part of a playbook later (see below) |

The **webserver** role installs nginx, drops config files from templates, starts the service.

---

## 7. Variables: who wins when values overlap?

Ansible merges settings from many places. **More specific wins** over more general (simplified):

```text
1. Extra vars on the command line          (highest priority — rare in this lab)
2. host_vars/web01.yml                     (one host only)
3. group_vars/webservers.yml               (one group)
4. group_vars/all.yml                      (everyone)
5. Role defaults (roles/*/defaults/)       (lowest — easy defaults)
```

**In this lab:**

- `group_vars/all.yml` — packages for every host, `controller_name`.
- `group_vars/webservers.yml` — nginx settings for the web tier.
- `host_vars/web01.yml` — `server_name: playground-web01.local`.
- `.env` — read through `lookup('env', 'VAR_NAME')` in inventory and some group_vars.

You change behavior by editing the **right layer**, not by copying the whole playbook.

---

## 8. Roles: why not one giant file?

A **role** is a folder with a standard layout:

```text
roles/webserver/
  defaults/main.yml    ← default variable values
  tasks/main.yml       ← steps to run
  handlers/main.yml    ← actions triggered by notify
  templates/           ← Jinja2 files (.j2) that become real files on the server
```

**Why use roles?**

- Same role on many playbooks or projects.
- Easier to read than a 500-line playbook.
- Matches how teams organize real Ansible code.

**Templates (**`.j2`**):** Text files with placeholders like `{{ inventory_hostname }}`. Ansible fills them in and copies the result to the server (e.g. nginx config, `index.html`).

---

## 9. Handlers (change → then restart)

In `roles/webserver/tasks/main.yml`, copying nginx config includes:

```yaml
notify: Reload nginx
```

In `handlers/main.yml`:

```yaml
- name: Reload nginx
  ansible.builtin.service:
    name: nginx
    state: reloaded
```

**Rule:** Handlers run **only if** a task actually **changed** something, and they run **at the end** of the play (once per handler name). That avoids restarting nginx ten times for no reason.

---

## 10. Modules and idempotency

A **module** is Ansible’s way of doing one job on the server.

Examples in this lab:

| Module | Job |
|--------|-----|
| `ansible.builtin.apt` | Install Debian/Ubuntu packages |
| `ansible.builtin.template` | Render `.j2` → file on disk |
| `ansible.builtin.service` | Start/stop/reload systemd services |
| `community.general.timezone` | Set timezone (from an extra collection) |

**Idempotent** means: run the same task twice; the second time often shows **ok** (no change) instead of breaking things. Ansible checks “is nginx already installed?” before installing again.

That is different from a plain shell script that blindly runs `apt install` every time.

---

## 11. `ansible.cfg` — defaults for every command

File: `ansible/ansible.cfg` (pointed to by `ANSIBLE_CONFIG` in the Makefile)

| Setting | Plain English |
|---------|----------------|
| `inventory = ...` | Default host list |
| `roles_path = roles` | Where roles live |
| `private_key_file = ...` | SSH key for login |
| `host_key_checking = False` | Do not ask “trust this SSH fingerprint?” (OK for local lab only) |
| `pipelining = True` | Faster SSH (production-style tweak) |
| `gathering = smart` | Reuse cached facts when possible |

You rarely edit this daily; inventory and playbooks change more often.

---

## 12. Collections (`make galaxy`)

Some modules live in **collections** (extra packages), not in core Ansible.

This lab lists them in `ansible/collections/requirements.yml` (e.g. `community.general` for timezone).

`make galaxy` downloads them into `ansible/collections/`. Without that step, a playbook that uses `community.general.timezone` can fail.

---

## 13. Useful commands (besides `make`)

Run from the `ansible/` folder after `source`ing `.env` (or use `make` targets).

| Command | What it does |
|---------|----------------|
| `ansible managed -m ping` | Quick SSH/Python check on all managed hosts |
| `ansible-playbook playbooks/site.yml` | Full configure |
| `ansible-playbook playbooks/site.yml --check` | **Dry run** — show what *would* change (not perfect for every module) |
| `ansible-playbook playbooks/site.yml --limit web01` | Only touch web01 |
| `ansible-playbook playbooks/site.yml --tags webserver` | Only tasks/roles tagged `webserver` |
| `ansible-inventory --list` | Dump inventory as JSON (debugging) |

---

## 14. What happens when you run `make site` (full story)

```text
make site
    │
    ├─ load .env (ports, user, key path)
    ├─ make galaxy  → install collections if needed
    │
    └─ ansible-playbook playbooks/site.yml
            │
            ├─ read ansible.cfg
            ├─ read inventory → web01, web02
            ├─ merge group_vars + host_vars
            │
            ├─ PLAY 1: common role on each host (become/sudo)
            │         web01 → apt, motd, ...
            │         web02 → same
            │
            └─ PLAY 2: webserver role, serial: 1
                      web01 → nginx, site, index.html
                      then web02 → same
```

After that, `curl http://127.0.0.1:8081` and `:8082` should show each host’s name—proof that **one playbook** configured **two nodes**.

---

## 15. Production habits you are already touching

| Habit | Where you see it |
|-------|------------------|
| One controller, many targets | Inventory + single playbook run |
| Group-based targeting | `managed` vs `webservers` |
| Shared + per-host config | `group_vars` / `host_vars` |
| Reusable automation | `roles/` |
| Safer rollouts | `serial: 1` |
| Pin extra dependencies | `collections/requirements.yml` |
| Central SSH/settings | `ansible.cfg` + `.env` |

---

## 16. Practice ideas (try in order)

1. Run `make smoke` and read the green `ok` lines for each host.
2. Run `make site` twice. Second run should be mostly `ok` / few `changed` (idempotency).
3. Change `server_name` in `host_vars/web01.yml`, run `make site`, compare nginx or page output.
4. Add a package to `common_packages` in `group_vars/all.yml`, run `make site`, SSH in and run `which htop` (or your package).
5. Run only web02:

   `cd ansible && ansible-playbook playbooks/site.yml --limit web02` (with `.env` loaded).

---

## 17. Glossary

| Term | Simple definition |
|------|-------------------|
| **Ad hoc command** | One module, one shot, no playbook file (`ansible ... -m ping`) |
| **Become** | Run tasks with elevated privileges (sudo) |
| **Control node** | Machine where you install and run Ansible |
| **Inventory** | List of hosts and groups |
| **Managed node** | Server Ansible configures |
| **Module** | Unit of work Ansible runs on a host |
| **Play** | Section of a playbook aimed at one group of hosts |
| **Playbook** | Ordered list of plays |
| **Role** | Packaged tasks, files, templates, handlers |
| **Task** | One named step in a play or role |
| **Idempotent** | Safe to run repeatedly; converges toward desired state |

---

## 18. Where to read next

- [FUNDAMENTALS.md](FUNDAMENTALS.md) — `make`, `.env`, and how files connect.
- [NEXT-STEPS.md](NEXT-STEPS.md) — leveled roadmap (Vault, lint, Molecule, CI, scale).
- [README.md](../README.md) — quick start and architecture diagram.
- Ansible official docs (deeper): [https://docs.ansible.com/](https://docs.ansible.com/) — use after you are comfortable with this lab.

When something fails, note **which host** and **which task** Ansible printed last—that usually tells you what to fix (SSH, sudo, missing package, typo in YAML).