# HomeLab — Infrastructure as Code

> Quand un changement impacte la structure du projet (nouveau nœud, réseau, rôle Ansible, dossier K3S, instance Traefik…), proposer proactivement une mise à jour de ce fichier.


Projet IaC pour gérer l'ensemble du Homelab (Proxmox, K3S, VPS, TrueNAS) via Ansible/GitOps.

## Nœuds

| Nœud | Type |
|---|---|
| Flash | Proxmox |
| Wasp | Proxmox |
| VPS | Cloud (edge) |

IPs et détails de connexion → `Ansible/inventory/hosts.yml` et `Ansible/host_vars/`

## Réseau

- `vmbr0` : réseau de gestion + LXC
- `vmbr1` : réseau services (VLAN 100)
- WireGuard : tunnel VPS ↔ nœuds Proxmox
- DNS wildcard : `*.wiserisk.be` (public) et `*.wiserisk.home` (interne)

## VMID scheme

- vmbr1 → 1XXX (XXX = dernier octet IP zéro-padded)
- vmbr0 → 9XXX

## SSH

- Clés dans `~/.ssh/`
- Utilisateurs disponibles : `wiserisk` (accès personnel, sudo) et `ansible` (automation, NOPASSWD sudo) — définis dans `Ansible/roles/hardening/`

## Ansible (`Ansible/`)

- `inventory/hosts.yml` — tous les hosts (proxmox, proxmox_pbs, truenas, k3s, lxc, haos, vps, network, ilo)
- `host_vars/` — config par host (services, réseau, WireGuard, niveaux hardening)
- `roles/hardening/` — 3 niveaux : 1=baseline (users+SSH), 2=+UFW, 3=+fail2ban strict + AllowUsers
- `roles/proxmox_provision/` — création LXC/VM/réseau/storage via API Proxmox
- `playbooks/` — un playbook par composant + `site.yml` (orchestration from-scratch)
- Vault : mot de passe dans `~/.vault_pass`
- Collections requises : `community.general`, `community.proxmox`
- **Toujours lancer les commandes Ansible depuis le dossier `Ansible/`** — `ansible.cfg` y configure l'inventaire, le vault password et les chemins automatiquement
- **Préférer les variables d'inventaire pour les URLs internes** (`ansible_host`, `*_port`…) plutôt que les URLs publiques passant par reverse proxy, VPN ou chaîne TLS — évite les timeouts et dépendances inutiles

## K3S (`K3S/`)

- `infrastructure/` — composants système : ArgoCD (app-of-apps), Traefik, Vault, Registry, Renovate
- `monitoring/` — Prometheus, Grafana, AlertManager, Blackbox, exporters
- `tools/` — applications (Nextcloud, Open-WebUI, Portainer, Graylog, Sonarqube…)
- `utils/` — workloads transverses : gitea-runner (act runner Gitea Actions, labels `ubuntu-latest`, `ubuntu-22.04`, `k3s` — mode DIND)
- `config/` — kubeconfig K3S (`k3s.yaml`, exporté dans `$KUBECONFIG`)
- Secrets : Vault + argocd-vault-plugin
- Stockage : NFS (Hermes) via StorageClass `nfs`

## Vault

- Accessible à `vault.k3s.wiserisk.home` (réseau home uniquement — couplé à l'accès K3S)
- `VAULT_ADDR` configuré dans `.claude/settings.local.json`
- Token read-only dans `~/.vault_token_homelab` (policy `claude-readonly`)
- Usage : `VAULT_TOKEN=$(cat ~/.vault_token_homelab) vault kv get <path>`

## Traefik (`Traefik/`)

Reverse proxy interne sur les nœuds Proxmox — config file-based.
- `traefik.yaml` — entrypoints (web, websecure, k3s TCP, graylog UDP), provider fichier
- `traefik_dynamic/` — routers/middlewares par service (un fichier par service)
- Dual-stack : `.wiserisk.be` (depuis Edge) et `.wiserisk.home` (TLS terminé ici)
- K3S : wildcard `*.k3s.wiserisk.*` → nœud master

## Traefik-Edge (`Traefik-Edge/`)

Reverse proxy sur le VPS — TLS via ACME DNS challenge (wildcard `*.wiserisk.be`).
- `traefik.yaml` — entrypoints (web, websecure, DNS 53, graylog UDP, LDAP 389)
- `traefik_dynamic/` — middlewares Authelia (forward-auth), redirect HTTPS, security headers, routers
- Authelia SSO protège les services exposés publiquement
- Bypass Authelia : voir bypass-auth dans Traefik-Edge/traefik_dynamic/catchall.yaml

## Git & CI/CD

**Gitea** (`git.wiserisk.be`) — plateforme Git primaire
- GitHub (`github.com/amaurydetremerie/`) : miroir automatique (push mirror Gitea → GitHub à chaque commit)
- Setup : `Ansible/playbooks/gitea.yml` (création de repos, LLDAP auth + SSO, push mirrors via API)

**Semaphore** (`semaphore.wiserisk.be`) — CI Ansible, LXC 1101 sur Wasp
- Exécute les playbooks Ansible déclenchés par les pipelines Gitea Actions
- Projet HomeLab configuré via `Ansible/playbooks/semaphore_setup.yml` (idempotent, crée aussi les Gitea Actions secrets)
- Setup : `Ansible/playbooks/semaphore.yml` (création de config, LLDAP auth + SSO)

**Gitea Actions** (`.gitea/workflows/`)
- `ansible.yml` — détecte les chemins modifiés → déclenche le template Semaphore correspondant
- `monitoring-check.yml` — Claude Haiku analyse le diff + fichiers monitoring → Issue Gitea si gap détecté
- `changelog.yml` — Claude Haiku génère un changelog → PR create/update sur README.md
- Act runner : pod K3S `gitea-runner` (namespace `gitea-runner`), labels `ubuntu-latest`/`ubuntu-22.04`/`k3s` → mode DIND (Docker-in-Docker), réseau overlay K3S standard

**ArgoCD** pointe vers Gitea (plus GitHub) : `https://git.wiserisk.be/wiserisk/HomeLab.git`
- Secret repo (`gitea-homelab-repo`) appliqué manuellement via kubectl (hors GitOps — dépendance circulaire)