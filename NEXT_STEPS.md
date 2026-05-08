# HomeLab — Prochaines étapes

Étapes ordonnées par dépendances. Les blocs peuvent être travaillés en parallèle entre eux.

---

## Bloc 1 — Infrastructure Proxmox

- [ ] **Interfaces réseau Proxmox**
  Compléter `roles/proxmox_provision/tasks/network.yml` — vérifier que la config vmbr0/vmbr1 est correctement appliquée sur wasp (une seule interface physique vs deux sur flash)

- [ ] **GPU passthrough Flash**
  Décommenter et adapter les directives `lxc_raw` GPU dans `host_vars/proxmox_flash.yml` pour Ollama (vmid 1104) et Jellyfin (vmid 1202) selon les devices réels (`ls /dev/dri/`)

- [ ] **Cloud-init pour K3S master/worker** *(optionnel — élimine la pause OS install)*
  Créer un template Debian cloud image sur Flash, modifier les VMs K3S dans host_vars pour cloner depuis template au lieu de booter sur ISO

---

## Bloc 2 — PBS + Backups

- [ ] **Import iSCSI dans PBS**
  Playbook ou tâche manuelle : connecter PBS au target iSCSI `pbs` (TrueNAS Hermes `10.100.0.10:3260`), créer le datastore PBS sur ce volume

- [ ] **Jobs de backup Proxmox**
  Créer `playbooks/proxmox_backup.yml` — ajouter les schedules de backup PBS dans Flash et Wasp via API Proxmox (`/nodes/{node}/vzdump`) pour les LXC et VMs critiques

---

## Bloc 3 — TrueNAS Hades

- [ ] **Pool + datasets Hades**
  Compléter `host_vars/truenas_hades.yml` avec `truenas_pool_name` et `truenas_datasets` (même pattern que Hermes), lancer `truenas_pool.yml --limit truenas_hades`

- [ ] **Réplication Hermes → Hades**
  Créer `playbooks/truenas_replication.yml` — configurer les tâches de réplication ZFS via API TrueNAS (`/replication`) pour les datasets critiques (K3S, K3S-Secure, Data)

- [ ] **Apps TrueNAS Hades**
  Définir les apps à déployer sur Hades dans `host_vars/truenas_hades.yml`, lancer `truenas.yml --limit truenas_hades --tags upgrade_all`

---

## Bloc 4 — Traefik LXC + migration CI/CD vers Gitea

- [ ] **Playbook Traefik LXC**
  Créer `playbooks/traefik.yml` — installer Traefik, déployer `traefik.service`, `traefik.toml` et les configs dynamiques depuis `Traefik/`.
  Toute modification de config passe ensuite par ce playbook (plus de webhook).

- [ ] **Migration pipelines GitHub Actions → Gitea**
  Remplacer `.github/workflows/traefik.yml` et `webhook.yml` par des pipelines Gitea Actions.
  Déclencheur : push sur la branche main → job Ansible via Semaphore (API) → `playbooks/traefik.yml`.

- [ ] **Dépréciation du LXC Webhook**
  Une fois les pipelines Gitea en place, le LXC webhook (vmid 1103) devient inutile.
  Le retirer de `host_vars/proxmox_flash.yml` et supprimer `playbooks/webhook.yml` si créé entre-temps.

---

## Bloc 5 — Services LXC (dans l'ordre de dépendances)

- [ ] **AdGuard + Unbound** *(DNS — requis par la plupart des autres services)*
  Créer `playbooks/adguard.yml` et `playbooks/unbound.yml` — installation, config des zones locales, pointage Proxmox + hosts vers AdGuard

- [ ] **Traefik** *(reverse proxy — requis pour accès HTTPS aux services)*
  Créer `playbooks/traefik.yml` — installation, config des middlewares, certificats Let's Encrypt, routes vers les autres services

- [ ] **Gitea**
  Créer `playbooks/gitea.yml` — installation, config SMTP, migration des repos si nécessaire

- [ ] **Semaphore** *(UI Ansible)*
  Créer `playbooks/semaphore.yml` — installation, connexion à l'inventaire Git, définition des templates de playbooks

- [ ] **Tailscale** *(accès distant + proxy vers réseau Hades 192.168.1.x)*
  Créer `playbooks/tailscale.yml` — installation dans le LXC tailscale (vmid 1220), config subnet routing vers 192.168.1.0/24

- [ ] **Jellyfin**
  Créer `playbooks/jellyfin.yml` — installation, config NFS media mount, activation GPU transcoding si GPU passthrough actif

- [ ] **qBittorrent + Seedbox**
  Créer `playbooks/qbittorrent.yml` et `playbooks/seedbox.yml`

- [ ] **Webhook**
  Créer `playbooks/webhook.yml` — installation, définition des hooks (déclencheurs CI/CD, Renovate, etc.)

- [ ] **Ollama**
  Créer `playbooks/ollama.yml` — installation, config GPU, exposition API

---

## Bloc 5 — Home Assistant

- [ ] **Import backup / création**
  Créer `playbooks/home_assistant.yml` — procédure d'import d'un backup HAOS existant via API HA (`/api/backup`) ou restauration depuis snapshot PBS, config des intégrations de base (réseau, Z-Wave via USB passthrough déjà défini)

---

## Bloc 6 — VPS

- [ ] **Mise en place VPS**
  Remplacer `x.x.x.x` dans `inventory/hosts.yml` par l'IP réelle, créer `playbooks/vps.yml` — config SSH hardening, fail2ban, services exposés (Traefik edge si nécessaire)

---

## Bloc 7 — Raspberry Pi + UPS

- [ ] **Ajout Raspberry Pi dans l'inventaire**
  Ajouter un groupe `raspberry_pi` dans `inventory/hosts.yml`, créer `host_vars/raspberry_pi.yml`

- [ ] **Serveur NUT (UPS)**
  Créer `playbooks/nut.yml` — installation NUT server sur le Pi (connecté à l'UPS en USB), configuration des clients NUT sur Flash, Wasp et Hades pour shutdown propre en cas de coupure

---

## Bloc 8 — Sécurité Ansible

Contexte : Traefik LXC est exposé via DMZ (futur VPS) et a accès aux réseaux 10.0.0.x et 10.100.0.x.
Semaphore sera sur réseau local uniquement (ansible.wiserisk.home), mais la clé ansible privée reste un vecteur de compromission si Semaphore ou un LXC adjacent est atteint.

- [ ] **Clé SSH dédiée Ansible**
  Générer une clé séparée de la clé personnelle, stockée uniquement dans Semaphore :
  ```bash
  ssh-keygen -t ed25519 -C "ansible@semaphore" -f ~/.ssh/id_ed25519_ansible
  ```
  Mettre la clé publique dans `group_vars/all/vars.yml` → `ansible_operator_ssh_public_key`.
  Mettre la clé privée dans Semaphore Key Store uniquement. Ne jamais la copier ailleurs.

- [ ] **User `ansible` dédié sur les LXC (remplacer root)**
  Ajouter dans le Play 4 de `proxmox.yml` : création du user `ansible` avec sudo sans mot de passe,
  injection de la clé SSH ansible uniquement (pas la clé personnelle).
  Changer `ansible_user: root` → `ansible_user: ansible` dans `group_vars/all/vars.yml`.
  Désactiver le login SSH root sur les LXC (`PermitRootLogin no`).
  *Réduction du blast radius : une compromission Semaphore donne sudo limité, pas root direct.*

- [ ] **Mot de passe root LXC pour accès console d'urgence**
  Ajouter `vault_lxc_root_password` dans le vault, le définir via `pct exec -- chpasswd` dans Play 4.
  Permet l'accès console Proxmox UI sans SSH si la clé est perdue ou le service SSH down.

---

## Bloc 9 — Améliorations transverses

- [ ] **Automatisation token TrueNAS**
  Ajouter dans `proxmox_bootstrap.yml` ou un playbook dédié la création du token API TrueNAS via API admin (POST `/api/v2.0/api_key`), pour éviter l'étape manuelle pendant la pause OS install

- [ ] **iLO firmware update**
  Renseigner `ilo_firmware_url` dans host_vars et planifier une mise à jour via `ilo.yml --tags firmware_update` (déjà implémenté, juste à orchestrer)

- [ ] **Automatisation mises à jour**
  Planifier `update.yml` via Semaphore ou cron sur une fenêtre de maintenance (nuit du dimanche), avec notification en cas d'échec

- [ ] **Monitoring stack K3S**
  Vérifier que les exporters (node_exporter sur LXC/VMs, iLO exporter, TrueNAS exporter) remontent correctement dans la stack monitoring ArgoCD

- [ ] **Open WebUI ↔ Ollama LXC**
  Open WebUI tourne dans K3S (10.100.0.151/152), Ollama dans un LXC (10.100.0.104).
  Vérifier que l'URL Ollama configurée dans Open WebUI est accessible depuis les pods K3S.

- [ ] **Centralisation des logs avec Graylog**
  Graylog stack (Graylog + Elasticsearch + MongoDB) est déployé via ArgoCD.
  Configurer les sources : syslog des LXC/VMs, logs K3S, logs Proxmox → Graylog inputs.

- [ ] **Vérification des apps ArgoCD après fresh bootstrap**
  Après un reinstall complet, valider que toutes les ArgoCD apps passent Healthy dans l'ordre des waves :
  argocd → kube-system → traefik → vault → registry → system-upgrade-controller → renovate → monitoring → tools (nextcloud, portainer, prowlarr, sonarqube, open-webui, flaresolverr, librespeed, graylog-stack)

- [ ] **Pipelines Gitea pour les apps K3S**
  Même logique que Traefik : modifications des manifests K3S → push Gitea → pipeline → ArgoCD sync.
  À définir selon la maturité de ArgoCD auto-sync (peut-être déjà géré par ArgoCD webhook Gitea).