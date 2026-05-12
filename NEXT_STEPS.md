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

- [x] **Unbound** *(DNS récursif upstream d'AdGuard)*
  `playbooks/unbound.yml` — Unbound récursif (root hints + DNSSEC) sur LXC 9087 (10.0.0.87, Wasp).
  Config dans `playbooks/files/unbound/unbound.conf`.
  **À faire** : créer le LXC (via `proxmox_wasp.yml`), lancer le playbook, pointer AdGuard vers 10.0.0.87.

- [x] **AdGuard** *(DNS filtrage pub)*
  `playbooks/adguard.yml` — configure via API AdGuard : upstream = Unbound (10.0.0.87), rewrite `*.wiserisk.home → 10.0.0.85`.
  Config dans `host_vars/adguard.yml`. Secrets : `vault_adguard_user`, `vault_adguard_password`.
  **À faire** : remplir le vault, lancer le playbook sur le LXC existant (9086, 10.0.0.86).

- [x] **Traefik** *(reverse proxy)*
  `playbooks/traefik.yml` — déploie binaire (optionnel), `Traefik/` → `/etc/Homelab/Traefik/`, overrides systemd avec secrets vault.
  Configs dynamiques Gitea et Semaphore ajoutées dans `Traefik/traefik_dynamic/`.
  Tag `--tags config` pour ne pousser que les configs sans toucher au binaire.
  Secrets : `vault_traefik_my_auth`, `vault_traefik_basic_auth`, `vault_traefik_vault_token`, `vault_traefik_vault_addr`.
  **À faire** : remplir le vault, lancer sur le LXC existant (1001, 10.0.0.85).

- [x] **Gitea**
  `playbooks/gitea.yml` — binaire v1.26.1, user `git`, toutes les données sur NFS `/opt/gitea`.
  Config `app.ini` dans `playbooks/templates/gitea/app.ini.j2`, service dans `playbooks/files/gitea/gitea.service`.
  Secrets : `vault_gitea_smtp_password`, `vault_gitea_secret_key`, `vault_gitea_internal_token`.
  **À faire** : créer le LXC (via `proxmox_wasp.yml`), remplir le vault, lancer le playbook.
  Migration des repos existants à faire manuellement après premier démarrage.

- [x] **Semaphore** *(UI Ansible)*
  `playbooks/semaphore.yml` — binaire v2.18.2, DB bolt, config JSON dans `playbooks/templates/semaphore/config.json.j2`.
  Secrets : `vault_semaphore_cookie_hash/encryption/access_key_encryption`, `vault_semaphore_admin_password`.
  **À faire** : créer le LXC (via `proxmox_wasp.yml`), remplir le vault, lancer le playbook.
  Connexion à l'inventaire Git et définition des templates de playbooks à faire dans l'UI après démarrage.

- [x] **Tailscale** *(accès distant + subnet router)*
  `playbooks/tailscale.yml` — exit node + subnet router (`10.0.0.0/24`, `10.100.0.0/24`) + port forwarding socat vers Hades.
  Config dans `host_vars/tailscale.yml`. Routes 192.168.1.x exposées via `tailscale_hades` (app TrueNAS, non géré).
  Secrets : `vault_tailscale_auth_key`.
  **À faire** : remplir le vault, lancer sur le LXC existant (1220, 10.100.0.220).
  Après déploiement : approuver subnet routes + exit node dans l'admin Tailscale.

- [x] **Jellyfin**
  `playbooks/jellyfin.yml` — apt repo officiel, user `jellyfin` ajouté aux groupes `video`+`render` pour GPU NVENC.
  GPU passthrough déjà configuré dans `proxmox_flash.yml`. Médias sur NFS `/mnt/media/seedbox`.
  **À faire** : lancer sur le LXC existant (1202, 10.100.0.202).
  Config initiale (librairies, users, NVENC) via web UI au premier lancement : http://10.100.0.202:8096.

- [x] **qBittorrent**
  `playbooks/qbittorrent.yml` — qbittorrent-nox, user dédié, service sur port 8090.
  **À faire** : lancer sur le LXC existant (1105, 10.100.0.105).

- [x] **Seedbox** *(suite \*arr)*
  `playbooks/seedbox.yml` — installe les services listés dans `host_vars/seedbox.yml` (`seedbox_services`).
  Actuellement : Radarr v6.1.1 + Sonarr v4.0.17. Extensible sans modifier le playbook.
  **À faire** : supprimer Swizzin du LXC existant (1201, 10.100.0.201), puis lancer le playbook.
  Prowlarr et Flaresolverr restent dans K3S.

- [x] **Ollama**
  `playbooks/ollama.yml` — install script officiel, override systemd (`OLLAMA_HOST=0.0.0.0`, `OLLAMA_MODELS=/mnt/ollama`).
  Modèles dans `host_vars/ollama.yml` (`ollama_models`) — le playbook pull les manquants à chaque run.
  GPU passthrough déjà configuré dans `proxmox_flash.yml`.
  **À faire** : lancer sur le LXC existant (1104, 10.100.0.104).

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

- [x] **Playbooks VPS**
  `playbooks/wireguard.yml` — serveur ou client selon `wireguard_role: server|client`.
  Template `wg.conf.j2` : PostUp/PostDown NAT côté serveur, Endpoint + PersistentKeepalive côté client.
  `playbooks/gatus.yml` — monitoring uptime (binaire GitHub, config YAML via template).
  `playbooks/vps.yml` — orchestrateur : wireguard → unbound → adguard → traefik → gatus, chaque service taggable séparément.
  Unbound sur VPS écoute uniquement sur `127.0.0.1:5335` (config `files/unbound/unbound_loopback.conf`).
  AdGuard sur VPS : port admin `3000` (port 80 occupé par Traefik), upstream = `127.0.0.1:5335`.
  Clés WireGuard dans vault : `vault_wireguard_<host>_private_key` + `vault_wg_<host>_pubkey`.
  Exemple client dans `host_vars/wireguard_client_example.yml`.

- [ ] **Mise en place VPS**
  Remplacer `x.x.x.x` dans `inventory/hosts.yml` par l'IP réelle du VPS.
  Renseigner `ansible_host` dans `host_vars/debian_vps.yml`.
  Générer clés WireGuard (`wg genkey | tee priv | wg pubkey`) pour VPS et chaque client, remplir le vault.
  Déployer : `hardening.yml --limit vps` puis `vps.yml`.
  Après déploiement : configurer les clients WireGuard (Proxmox, LXC, laptop) avec leur host_vars.

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