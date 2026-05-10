# HomeLab — Prochaines étapes

Étapes ordonnées par dépendances. Les blocs peuvent être travaillés en parallèle entre eux.

---

## Bloc 1 — Infrastructure Proxmox

- [x] **Interfaces réseau Proxmox**
  Template `interfaces.j2` nettoyé (doublons supprimés). Interface Wasp corrigée : `enp1s0f0` (était `eno1`). Flash : bond0 sur eno1+eno2, vmbr1 VLAN 100 sur bond0.100.

- [x] **GPU passthrough Flash**
  Directives `lxc_raw` décommentées et corrigées dans `host_vars/proxmox_flash.yml` :
  - Ollama (1104) : cgroup2 + nvidia (195) + nvidia-uvm (509) + nvidia-caps (234) + dri (226) + mounts
  - Jellyfin (1202) : idem + mount `/dev/dri`
  - card0 = Matrox iLO (ne pas passer), card1 = Quadro P2200 (le vrai GPU)
  Driver Nvidia automatisé dans `playbooks/proxmox_gpu.yml` (jouable seul) + importé par le bootstrap.
  `proxmox_gpus` dans host_vars : dict keyed par vendor (nvidia/amd/intel), extensible sans modifier les playbooks.

- [ ] **Cloud-init pour K3S master/worker** *(optionnel — élimine la pause OS install)*
  Créer un template Debian cloud image sur Flash, modifier les VMs K3S dans host_vars pour cloner depuis template au lieu de booter sur ISO

---

## Bloc 2 — PBS + Backups

- [x] **Import iSCSI dans PBS**
  Connecter PBS au target iSCSI `pbs` (TrueNAS Hermes `10.100.0.10:3260`), créer le datastore PBS sur ce volume

- [x] **Jobs de backup Proxmox**
  `playbooks/proxmox_backup.yml` — schedules de backup PBS via API Proxmox, 4 types (local/critical/non_critical/archive), idempotent

---

## Bloc 3 — Sécurité Ansible

- [x] **Clé SSH dédiée Ansible**
  Clé publique dans `group_vars/all/vars.yml` → `ansible_operator_ssh_public_key`.
  Clé privée dans Semaphore Key Store uniquement.

- [x] **User `ansible` + user `wiserisk` sur toutes les machines Linux**
  `roles/hardening/` — 3 niveaux (1=baseline, 2=+ufw, 3=+fail2ban strict).
  Crée `wiserisk` (clé perso, sudo avec MDP) et `ansible` (clé Semaphore, NOPASSWD sudo).
  Root SSH désactivé partout. Applicable sur proxmox, PBS, LXC, VMs, VPS, Raspberry.

- [x] **Hardening intégré dans site.yml dès le départ**
  `[1]` hardening proxmox hypervisors (avant bootstrap), `[3b]` hardening PBS + linux_managed
  (avant toute config). Root n'est utilisé qu'au premier hardening — jamais ailleurs.

- [x] **Mot de passe root LXC pour accès console d'urgence**
  `vault_lxc_root_password` défini dans le vault, injecté via paramètre `password` du module
  `community.general.proxmox` à la création. Accès console Proxmox UI garanti même sans SSH.

---

## Bloc 4 — Services LXC (dans l'ordre de dépendances)

- [ ] **AdGuard + Unbound** *(DNS — requis par la plupart des autres services)*
  Créer `playbooks/adguard.yml` et `playbooks/unbound.yml` — installation, config des zones locales, pointage Proxmox + hosts vers AdGuard

- [ ] **Traefik** *(reverse proxy — requis pour accès HTTPS aux services)*
  Créer `playbooks/traefik.yml` — installer Traefik, déployer `traefik.service`, `traefik.toml` et les configs dynamiques depuis `Traefik/`.
  Toute modification de config passe ensuite par ce playbook.

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

- [ ] **Ollama**
  Créer `playbooks/ollama.yml` — installation, config GPU, exposition API

---

## Bloc 5 — Migration CI/CD vers Gitea + dépréciation Webhook

- [ ] **Migration pipelines GitHub Actions → Gitea**
  Remplacer `.github/workflows/traefik.yml` et `webhook.yml` par des pipelines Gitea Actions.
  Déclencheur : push sur la branche main → job Ansible via Semaphore (API) → `playbooks/traefik.yml`.

- [ ] **Dépréciation du LXC Webhook**
  Une fois les pipelines Gitea en place, le LXC webhook (vmid 1103) devient inutile.
  Le retirer de `host_vars/proxmox_flash.yml`.

---

## Bloc 6 — Raspberry Pi + UPS

- [ ] **Ajout Raspberry Pi dans l'inventaire**
  Ajouter un groupe `raspberry_pi` dans `inventory/hosts.yml`, créer `host_vars/raspberry_pi.yml`

- [ ] **Serveur NUT (UPS)**
  Créer `playbooks/nut.yml` — installation NUT server sur le Pi (connecté à l'UPS en USB), configuration des clients NUT sur Flash et Wasp pour shutdown propre en cas de coupure

---

## Bloc 7 — Home Assistant

- [ ] **Import backup / création**
  Créer `playbooks/home_assistant.yml` — procédure d'import d'un backup HAOS existant via API HA (`/api/backup`) ou restauration depuis snapshot PBS, config des intégrations de base (réseau, Z-Wave via USB passthrough déjà défini)

---

## Bloc 8 — VPS

- [ ] **Mise en place VPS**
  Remplacer `x.x.x.x` dans `inventory/hosts.yml` par l'IP réelle.
  Le hardening (niveau 3) sera appliqué automatiquement par `hardening.yml` — fail2ban strict, SSH AllowUsers, ufw.
  Créer `playbooks/vps.yml` si des services spécifiques doivent y tourner (Traefik edge, etc.)

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
  À définir selon la maturité de ArgoCD auto-sync (peut-être déjà géré par ArgoCD webhook Gitea)

---

## Bloc 10 — TrueNAS Hades *(distant — à faire quand accès facile)*

- [ ] **Pool + datasets Hades**
  Compléter `host_vars/truenas_hades.yml` avec `truenas_pool_name` et `truenas_datasets` (même pattern que Hermes), lancer `truenas_pool.yml --limit truenas_hades`

- [ ] **Réplication Hermes → Hades**
  Créer `playbooks/truenas_replication.yml` — configurer les tâches de réplication ZFS via API TrueNAS (`/replication`) pour les datasets critiques (K3S, K3S-Secure, Data)

- [ ] **Apps TrueNAS Hades**
  Définir les apps à déployer sur Hades dans `host_vars/truenas_hades.yml`, lancer `truenas.yml --limit truenas_hades --tags upgrade_all`