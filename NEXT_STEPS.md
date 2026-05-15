# HomeLab — Prochaines étapes

Étapes ordonnées par dépendances. Les blocs peuvent être travaillés en parallèle entre eux.

---

## ⚠️ Bugs et incohérences à corriger (priorité haute)

Ces problèmes empêchent ou faussent l'exécution des playbooks. À corriger avant de lancer site.yml.

### ~~B1 — Syntax error `hosts.yml` : groupe lxc~~ ✅ corrigé
`children:` était imbriqué sous `hosts:` pour le groupe `lxc`. Restructuré avec la syntaxe correcte.

### ~~B2 — host_vars adguard/unbound ne correspondent à aucun host~~ ✅ corrigé (Wasp) / ⚠️ Flash en attente
`adguard.yml` et `unbound.yml` supprimés. Remplacés par des fichiers avec les bonnes IPs :
- `adguard_wasp.yml` ✅ — upstream `10.0.0.180` (unbound_wasp), rewrite → `10.0.0.182` (traefik_wasp)
- `unbound_wasp.yml` ✅ — UFW port 53
- `adguard_flash.yml` ❌ manquant — upstream `10.0.0.89` (unbound_flash), rewrite → `10.0.0.85` (traefik_flash)
- `unbound_flash.yml` ✅ créé — UFW port 53 (déploiement Flash en attente)

Les LXC Flash (vmid 9088/9089) sont à ajouter dans `host_vars/proxmox_flash.yml` avant déploiement.
Les playbooks ciblent le groupe (`adguard` / `unbound`) qui contient les deux instances grâce au fix B1.

### ~~B3 — Fichiers stagés mais supprimés du disque~~ ✅ corrigé
Index nettoyé (`git restore --staged`). Les playbooks par nœud (`proxmox_flash.yml`, `proxmox_wasp.yml`) et les group_vars redondants (`lxc`, `vms`, `k3s_masters`, `k3s_workers`) ont été fusionnés dans `proxmox.yml` (avec `-e target=`) et dans `linux_managed/vars.yml`.

### ~~B4 — Groupe `vms` absent de hosts.yml~~ ✅ corrigé
Fichier group_vars supprimé de l'index (plus de raison d'exister).

### ~~B5 — Artefact legacy `Ansible/group_vars/all.yml`~~ ✅ corrigé
Fichier supprimé.

### ~~B6 — Gatus absent de l'inventaire Wasp~~ ✅ corrigé
LXC `gatus` ajouté dans `hosts.yml` (10.100.0.102), `host_vars/proxmox_wasp.yml` (vmid 1102) et `host_vars/gatus.yml` créé. Rôle : monitoring de secours (K3S down), pas monitoring interne.

### B8 — Repos Proxmox enterprise désactivés trop tard dans `hardening.yml`
`roles/hardening/tasks/main.yml` importe `users.yml` en premier. `users.yml` fait `apt install sudo` (ligne 47) avant que `packages.yml` désactive les repos enterprise. Sur un Proxmox fresh install, ces repos bloquent apt (pas d'abonnement) → échec au premier `apt`. Uniquement sur les hosts proxmox.

**Fix à implémenter :** extraire les deux tâches de désactivation des repos de `packages.yml` dans un nouveau fichier `roles/hardening/tasks/proxmox_repos.yml`, et l'importer en tête de `main.yml` (avant `users.yml`).

**Workaround actuel :** désactiver manuellement les repos enterprise avant le premier run hardening sur chaque Proxmox.

### B9 — `host_vars/traefik.yml` fichier orphelin
Le groupe `traefik` dans `hosts.yml` ne contient plus de host nommé `traefik` (remplacé par `traefik_wasp` et `traefik_flash`). Le fichier `host_vars/traefik.yml` n'est donc chargé par aucun host et peut être supprimé sans impact.

### B10 — `host_vars/traefik_flash.yml` incomplet
Manque les variables requises par `playbooks/traefik.yml` pour Flash :
`traefik_internal_ip`, `hardening_level`, `traefik_acme_email`, `traefik_download_url`, `hardening_ufw_forward_policy`, `hardening_ufw_rules`.
À compléter (en miroir de `traefik_wasp.yml`) avant le premier déploiement sur Flash.

### ~~B7 — `hardening.yml` : première exécution impossible depuis `site.yml`~~ ✅ corrigé

`ansible_user: ansible` est défini dans les group_vars des trois groupes concernés (`proxmox`, `proxmox_pbs`, `linux_managed`). Cette variable d'inventaire a une priorité supérieure à `remote_user` dans le play — le `hardening_connect_as` documenté dans le header de `hardening.yml` est donc sans effet.

**Impact :**
- `site.yml` step [1] (`proxmox_hypervisors`) → tente `ansible@<host>`, user inexistant → ÉCHEC
- `site.yml` step [3b] (`proxmox_pbs:linux_managed`) → idem → ÉCHEC
- Le commentaire dans `group_vars/proxmox/vars.yml` ("ansible user existe avant tout autre playbook") est contradictoire — c'est le hardening qui le crée
- Passer `-e ansible_user=root` sur la CLI pour site.yml s'appliquerait à **tous** les plays, y compris ceux post-hardening qui ont besoin de `ansible`

**Workaround immédiat** (lancer le hardening séparément avant site.yml) :
```bash
ansible-playbook playbooks/hardening.yml -e target=proxmox_hypervisors -e ansible_user=root
ansible-playbook playbooks/hardening.yml -e target="proxmox_pbs:linux_managed" -e ansible_user=root
# Ensuite site.yml à partir du step [2] (commenter les deux include_playbook hardening)
```

**Fix à implémenter :** Remplacer `remote_user` dans `hardening.yml` par un mécanisme d'inventaire dédié :
créer un groupe `hardening_bootstrap` (hosts à hardeniser pour la première fois) avec `ansible_user: root`, distinct du groupe `linux_managed`. Une fois hardenisé, déplacer le host dans `linux_managed`. Alternativement, split `site.yml` en deux phases avec des instructions de connexion différentes.

---

## Bloc 1 — Infrastructure Proxmox

- [x] **Interfaces réseau Proxmox**
  Template `interfaces.j2` nettoyé (doublons supprimés). Interface Wasp corrigée : `enp1s0f0` (était `eno1`). Flash : bond0 sur eno1+eno2, vmbr1 VLAN 100 sur bond0.100.
  ⚠️ **Divergence à vérifier** : `host_vars/proxmox_wasp.yml` a `enp1s0` mais la mémoire et ce doc disent `enp1s0f0`. Confirmer avec `ip link show` sur Wasp avant le prochain run.

- [x] **GPU passthrough Flash**
  Directives `lxc_raw` décommentées et corrigées dans `host_vars/proxmox_flash.yml` :
  - Ollama (1104) : cgroup2 + nvidia (195) + nvidia-uvm (509) + nvidia-caps (234) + dri (226) + mounts
  - Jellyfin (1202) : idem + mount `/dev/dri`
  - card0 = Matrox iLO (ne pas passer), card1 = Quadro P2200 (le vrai GPU)
  Driver Nvidia automatisé dans `playbooks/proxmox_gpu.yml` (jouable seul) + importé par le bootstrap.
  `proxmox_gpus` dans host_vars : dict keyed par vendor (nvidia/amd/intel), extensible sans modifier les playbooks.

- [x] **Ciblage par nœud**
  `playbooks/proxmox.yml` supporte `-e target=proxmox_flash` ou `-e target=proxmox_wasp` pour cibler un seul nœud.

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
  `vault_root_password` défini dans le vault, injecté via paramètre `password` du module
  `community.general.proxmox` à la création. Accès console Proxmox UI garanti même sans SSH.

- [x] **Pré-requis clés SSH** — remplies dans `inventory/group_vars/all/vars.yml`.
  `assert` ajouté en tête de `roles/hardening/tasks/main.yml` — message explicite si vide.

- [x] **Mot de passe user wiserisk** — `vault_linux_user_password` renseigné dans le vault.

- [x] **Endpoint WireGuard VPS** — `vps_wg_endpoint: "vpn.wiserisk.be:51820"` défini dans `group_vars/all/vars.yml`.
  `traefik_wasp.yml` et `traefik_flash.yml` référencent `{{ vps_wg_endpoint }}` — aucune valeur en dur à maintenir par host.

- [x] **Remplir le vault** — Variables restantes à renseigner :
  - ❌ `vault_proxmox_flash_api_token_secret`, `vault_proxmox_wasp_api_token_secret` (généré par bootstrap)
  - ❌ `vault_truenas_hermes_api_key` (généré manuellement dans UI TrueNAS)
  - ❌ `vault_tailscale_auth_key` (généré manuellement au besoin -> validité 90 jours)
  - ✅ `vault_gitea_smtp_password`
  - ✅ `vault_lxc_root_password`, `vault_pbs_fingerprint`, `vault_adguard_*`, `vault_traefik_*`
  - ✅ `vault_gitea_secret_key`, `vault_gitea_internal_token`, `vault_semaphore_*`
  - ✅ `vault_wireguard_*` + `vault_wg_*` (clés WireGuard générées)
  - ✅ `vault_ilo_flash_password`, `vault_ilo_hades_password`

---

## Bloc 4 — Services LXC (dans l'ordre de dépendances)

> **Pré-requis Bloc 4** : vault rempli (Bloc 3).
> `site.yml` step `[10]` → `install_services.yml` (tous les services dans l'ordre). Ciblage : `--tags <service>` ou `--limit <host>`.

- [x] **Unbound** *(DNS récursif upstream d'AdGuard)*
  `playbooks/unbound.yml` — Unbound récursif (root hints + DNSSEC).
  Config dans `playbooks/files/unbound/unbound.conf`.
  Deux instances : `unbound_wasp` (10.0.0.87) sur Wasp + `unbound_flash` (10.0.0.89) sur Flash.
  VPS : config `unbound_loopback.conf` (127.0.0.1:5335 uniquement — AdGuard est sur le même hôte).

- [x] **AdGuard** *(DNS filtrage pub)*
  `playbooks/adguard.yml` — configure via API AdGuard : upstream = Unbound, rewrite `*.wiserisk.home → traefik`.
  - Wasp : upstream `10.0.0.180` (unbound_wasp), rewrite vers `10.0.0.182` (traefik_wasp) ✅ déployé
  - Flash : upstream `10.0.0.89` (unbound_flash), rewrite vers `10.0.0.85` (traefik_flash) ❌ en attente
  Secrets : `vault_adguard_user`, `vault_adguard_password`.

- [x] **Traefik** *(reverse proxy — interne)*
  `playbooks/traefik.yml` — déploie binaire (optionnel), `Traefik/` → `/etc/Homelab/Traefik/`, overrides systemd avec secrets vault.
  Tag `--tags config` pour ne pousser que les configs sans toucher au binaire.
  Secrets : `vault_traefik_my_auth`, `vault_traefik_basic_auth`, `vault_traefik_vault_token`, `vault_traefik_vault_addr`.
  Deux instances : `traefik_wasp` (10.0.0.84) + `traefik_flash` (10.0.0.85).

- [ ] **Traefik — architecture cible : certs OVH sur VPS + LB interne** ⚠️ non implémenté

  **Architecture voulue :**
  - VPS Traefik : terminaison TLS wildcard `*.wiserisk.be` via OVH DNS-01, load balance vers `10.8.0.2:80` + `10.8.0.3:80` (WireGuard → traefik_wasp/flash)
  - Internal Traefik : reçoit HTTP depuis VPS, route vers les services, **sans** gérer de certs
  - K3S Traefik : idem, plus de gestion de certs

  **État actuel :**
  - `traefik.toml` utilise `httpChallenge` / `tlsChallenge` — pas OVH, pas wildcard
  - `Traefik/` contient uniquement les configs internes — aucune config VPS (LB, route wildcard, resolver OVH)
  - Les dynamic configs (`gitea.yml`, `semaphore.yml`, etc.) ont `certResolver: letsencrypt-ecdsa` → le Traefik interne gère les certs lui-même
  - `k3s.yml` : `passthrough: true` → K3S Traefik gère ses propres certs

  **Ce qu'il faut faire :**
  1. Créer `Traefik/traefik_vps.toml` — resolver OVH DNS-01 + credentials OVH dans le vault
  2. Créer `Traefik/traefik_dynamic_vps/` — wildcard cert + router `*.wiserisk.be` + LB vers WG IPs
  3. Modifier `traefik.toml` (interne) — supprimer les `certificatesResolvers`
  4. Modifier les dynamic configs — supprimer `tls: certResolver:` sur les routers publics (TLS terminé au VPS), garder `tls: {}` uniquement pour les routes `.wiserisk.home`
  5. `k3s.yml` — supprimer `passthrough: true`, passer K3S sur HTTP interne
  6. Adapter `playbooks/traefik.yml` — déployer la bonne config selon le host (VPS vs interne)

- [x] **Gatus sur Wasp** *(monitoring de secours K3S)*
  LXC 1102 (10.100.0.102) ajouté dans `hosts.yml`, `host_vars/proxmox_wasp.yml` et `host_vars/gatus.yml`.
  Checks : K3S API (401 expected), Traefik Flash (tcp://10.100.0.2:80), VPS (public).
  Indépendant du monitoring K3S principal — actif même si K3S est down.

- [x] **Gitea**
  `playbooks/gitea.yml` — binaire v1.26.1, user `git`, toutes les données sur NFS `/opt/gitea`.
  Config `app.ini` dans `playbooks/templates/gitea/app.ini.j2`, service dans `playbooks/files/gitea/gitea.service`.
  Secrets : `vault_gitea_smtp_password`, `vault_gitea_secret_key`, `vault_gitea_internal_token`.
  LXC 1100 (10.100.0.100). Migration des repos existants à faire manuellement après premier démarrage.

- [x] **Semaphore** *(UI Ansible)*
  `playbooks/semaphore.yml` — binaire v2.18.2, DB bolt, config JSON dans `playbooks/templates/semaphore/config.json.j2`.
  Secrets : `vault_semaphore_cookie_hash/encryption/access_key_encryption`, `vault_semaphore_admin_password`.
  LXC 1101 (10.100.0.101). Connexion à l'inventaire Git et templates de playbooks à configurer dans l'UI après démarrage.

- [x] **Tailscale** *(accès distant + subnet router)*
  `playbooks/tailscale.yml` — exit node + subnet router (`10.0.0.0/24`, `10.100.0.0/24`) + port forwarding socat vers Hades.
  Config dans `host_vars/tailscale.yml`. Routes 192.168.1.x exposées via `tailscale_hades` (app TrueNAS, non géré).
  Secrets : `vault_tailscale_auth_key` ❌ (à remplir — validité 90j).
  LXC 1220 (10.100.0.220). Après déploiement : approuver subnet routes + exit node dans l'admin Tailscale.

- [x] **Jellyfin**
  `playbooks/jellyfin.yml` — apt repo officiel, user `jellyfin` ajouté aux groupes `video`+`render` pour GPU NVENC.
  GPU passthrough déjà configuré dans `proxmox_flash.yml`. Médias sur NFS `/mnt/media/seedbox`.
  LXC 1202 (10.100.0.202). Config initiale (librairies, users, NVENC) via web UI : http://10.100.0.202:8096.

- [x] **qBittorrent**
  `playbooks/qbittorrent.yml` — qbittorrent-nox, user dédié, service sur port 8090.
  LXC 1105 (10.100.0.105).

- [x] **Seedbox** *(suite \*arr)*
  `playbooks/seedbox.yml` — installe les services listés dans `host_vars/seedbox.yml` (`seedbox_services`).
  Actuellement : Radarr v6.1.1 + Sonarr v4.0.17. Extensible sans modifier le playbook.
  LXC 1201 (10.100.0.201) — supprimer Swizzin avant de lancer le playbook.
  Prowlarr et Flaresolverr restent dans K3S.

- [x] **Ollama**
  `playbooks/ollama.yml` — install script officiel, override systemd (`OLLAMA_HOST=0.0.0.0`, `OLLAMA_MODELS=/mnt/ollama`).
  Modèles dans `host_vars/ollama.yml` (`ollama_models`) — le playbook pull les manquants à chaque run.
  GPU passthrough déjà configuré dans `proxmox_flash.yml`. LXC 1104 (10.100.0.104).

- [x] **site.yml step [10]**
  Délègue à `install_services.yml` — tous les services dans l'ordre de dépendances.
  Ciblage : `--tags <service>` (ex: `--tags gitea`) ou `--limit <host>`.

---

## Bloc 5 — VPS

- [x] **Playbooks VPS**
  `playbooks/wireguard.yml` — serveur ou client selon `wireguard_role: server|client`.
  Template `wg.conf.j2` : PostUp/PostDown NAT côté serveur, Endpoint + PersistentKeepalive côté client.
  `playbooks/gatus.yml` — monitoring uptime (binaire GitHub, config YAML via template).
  `playbooks/vps.yml` — orchestrateur : wireguard → unbound → adguard → traefik → gatus, chaque service taggable séparément.
  Unbound sur VPS écoute uniquement sur `127.0.0.1:5335` (config `files/unbound/unbound_loopback.conf`).
  AdGuard sur VPS : port admin `3000` (port 80 occupé par Traefik), upstream = `127.0.0.1:5335`.
  Clés WireGuard dans vault : `vault_wireguard_<host>_private_key` + `vault_wg_<host>_pubkey`.
  Exemple client dans `host_vars/wireguard_client_example.yml`.

- [x] ~~**Mise en place VPS**~~ ✅ déployé (VPS + traefik_wasp fonctionnels)

  **Ordre de déploiement testé et validé :**
  ```bash
  # Pré-requis : ssh-copy-id root sur les deux machines
  ssh-copy-id -i ~/.ssh/ansibleWiseRiskHomelab.pub root@77.90.52.180   # VPS
  ssh-copy-id -i ~/.ssh/ansibleWiseRiskHomelab.pub root@10.0.0.82      # Wasp

  # Dans le dossier Ansible/

  # VPS
  ansible-playbook playbooks/hardening.yml -e target=debian_vps
  ansible-playbook playbooks/hardening.yml -e target=debian_vps -e hardening_connect_as=ansible
  ansible-playbook playbooks/vps.yml

  # Proxmox Wasp
  ansible-playbook playbooks/hardening.yml -e target=proxmox_wasp
  ansible-playbook playbooks/hardening.yml -e target=proxmox_wasp -e hardening_connect_as=ansible
  ansible-playbook playbooks/proxmox_bootstrap.yml --limit proxmox_wasp
  ansible-playbook playbooks/proxmox_storage.yml --limit proxmox_wasp
  ansible-playbook playbooks/proxmox.yml -e target=proxmox_wasp

  # Traefik Wasp
  ansible-playbook playbooks/hardening.yml -e target=traefik --limit traefik_wasp
  ansible-playbook playbooks/hardening.yml -e target=traefik --limit traefik_wasp -e hardening_connect_as=ansible
  ansible-playbook playbooks/wireguard.yml -e target=traefik --limit traefik_wasp
  ansible-playbook playbooks/traefik.yml --limit traefik_wasp

  # LXC Wasp (hardening phase 1 root → ansible, puis services)
  ansible-playbook playbooks/hardening.yml -e target=unbound --limit unbound_wasp
  ansible-playbook playbooks/hardening.yml -e target=adguard --limit adguard_wasp
  ansible-playbook playbooks/hardening.yml -e target=semaphore
  ansible-playbook playbooks/hardening.yml -e target=gitea
  ansible-playbook playbooks/hardening.yml -e target=gatus
  ansible-playbook playbooks/hardening.yml -e target=unbound --limit unbound_wasp -e hardening_connect_as=ansible
  ansible-playbook playbooks/hardening.yml -e target=adguard --limit adguard_wasp -e hardening_connect_as=ansible
  ansible-playbook playbooks/hardening.yml -e target=semaphore -e hardening_connect_as=ansible
  ansible-playbook playbooks/hardening.yml -e target=gitea -e hardening_connect_as=ansible
  ansible-playbook playbooks/hardening.yml -e target=gatus -e hardening_connect_as=ansible
  ansible-playbook playbooks/unbound.yml --limit unbound_wasp
  ansible-playbook playbooks/adguard.yml --limit adguard_wasp
  ansible-playbook playbooks/semaphore.yml
  ansible-playbook playbooks/gitea.yml
  ansible-playbook playbooks/gatus.yml --limit gatus
  ```

---

## Bloc 6 — Améliorations transverses

- [ ] **Migration modules `community.proxmox`**
  Les modules `community.general.proxmox*` sont dépréciés → déplacés dans `community.proxmox` (supprimé en v15.0.0).
  Remplacer dans tous les playbooks : `community.general.proxmox` → `community.proxmox.proxmox`, idem pour `proxmox_kvm` et `proxmox_template`.
  Ajouter `community.proxmox` dans `requirements.yml`.

- [ ] **Automatisation token TrueNAS**
  Ajouter dans `proxmox_bootstrap.yml` ou un playbook dédié la création du token API TrueNAS via API admin (POST `/api/v2.0/api_key`), pour éviter l'étape manuelle pendant la pause OS install

- [ ] **Automatisation mises à jour**
  Planifier `update.yml` via Semaphore ou cron sur une fenêtre de maintenance (nuit du dimanche), avec notification en cas d'échec

- [ ] **Monitoring stack K3S**
  Vérifier que les exporters (node_exporter sur LXC/VMs, iLO exporter, TrueNAS exporter) remontent correctement dans la stack monitoring ArgoCD

- [ ] **Open WebUI ↔ Ollama LXC**
  Open WebUI tourne dans K3S (10.100.0.151/152), Ollama dans un LXC (10.100.0.104).
  Vérifier que l'URL Ollama configurée dans Open WebUI est accessible depuis les pods K3S.

- [ ] **Vérification des apps ArgoCD après fresh bootstrap**
  Après un reinstall complet, valider que toutes les ArgoCD apps passent Healthy dans l'ordre des waves :
  argocd → kube-system → traefik → vault → registry → system-upgrade-controller → renovate → monitoring → tools (nextcloud, portainer, prowlarr, sonarqube, open-webui, flaresolverr, librespeed, graylog-stack)

- [ ] **Centralisation des logs avec Graylog**
  Graylog stack (Graylog + Elasticsearch + MongoDB) est déployé via ArgoCD.
  Configurer les sources : syslog des LXC/VMs, logs K3S, logs Proxmox → Graylog inputs.

- [ ] **Migration `Ingress` → `IngressRoute` CRD (Traefik)**
  Tous les manifests K3S utilisent encore le `Ingress` standard Kubernetes. Migrer vers l'`IngressRoute` CRD Traefik pour :
  - Combiner `.be` et `.home` en une seule règle : `Host('x.k3s.wiserisk.be') || Host('x.k3s.wiserisk.home')`
  - Déclarer `web` et `websecure` sur la même ressource sans duplication du bloc `host`
  - Référencer les middlewares directement dans le manifest sans annotations
  ```yaml
  apiVersion: traefik.containo.us/v1alpha1
  kind: IngressRoute
  spec:
    entryPoints: [web, websecure]
    routes:
      - match: Host(`x.k3s.wiserisk.be`) || Host(`x.k3s.wiserisk.home`)
        services:
          - name: x-svc
            port: 8080
  ```

- [ ] **Routes TCP/UDP via IngressRoute pour Graylog**
  Graylog expose des inputs UDP/TCP (GELF, syslog). L'`IngressRoute` Traefik supporte nativement les routes TCP et UDP — utiliser `IngressRouteTCP` / `IngressRouteUDP` dans K3S pour exposer les ports Graylog sans passer par un `NodePort` :
  ```yaml
  apiVersion: traefik.containo.us/v1alpha1
  kind: IngressRouteUDP
  metadata:
    name: graylog-gelf-udp
    namespace: graylog-stack
  spec:
    entryPoints:
      - graylog-udp   # entrypoint UDP dédié à définir dans la config K3S Traefik
    routes:
      - services:
          - name: graylog-svc
            port: 12201
  ```
  Nécessite d'ajouter un entrypoint UDP dans `traefik-config.yaml.j2` (ex: `--entryPoints.graylog-udp.address=:12201/udp`).
  **État actuel (`graylog/service.yaml`) :** deux services séparés :
  - `graylog-svc` (ClusterIP) — port 9000 (web) + port 12201 TCP (GELF TCP)
  - `graylog-udp-svc` (LoadBalancer) — port 12201 UDP, `externalTrafficPolicy: Local`

  Le `LoadBalancer` K3S (klipper-lb) expose le port UDP sur les IPs des noeuds (`10.100.0.151:12201` + `10.100.0.152:12201`), ce qui explique pourquoi le Traefik interne pointe vers les deux noeuds directement.

  **Après migration :**
  - Supprimer `graylog-udp-svc` (LoadBalancer) — remplacé par `IngressRouteUDP` K3S Traefik
  - Ajouter `IngressRouteTCP` pour GELF TCP 12201 (actuellement non routé depuis l'extérieur)
  - `graylog-svc` reste ClusterIP, K3S Traefik route vers lui
  - Le Traefik interne (`k3s.yml`) garde son entrypoint `graylog` mais pointe vers K3S Traefik (qui devient le seul point d'entrée UDP/TCP pour Graylog)

- [ ] **Cloud-init pour K3S master/worker** *(optionnel — élimine la pause OS install)*
  Créer un template Debian cloud image sur Flash, modifier les VMs K3S dans host_vars pour cloner depuis template au lieu de booter sur ISO

---

## Bloc 7 — Migration CI/CD vers Gitea + dépréciation Webhook

- [ ] **Migration pipelines GitHub Actions → Gitea**
  Remplacer `.github/workflows/traefik.yml` et `webhook.yml` par des pipelines Gitea Actions.
  Déclencheur : push sur la branche main → job Ansible via Semaphore (API) → `playbooks/traefik.yml`.

- [ ] **Dépréciation du LXC Webhook**
  Une fois les pipelines Gitea en place, le LXC webhook (vmid 1103) devient inutile.
  Le retirer de `host_vars/proxmox_flash.yml`.

- [ ] **Pipelines Gitea pour les apps K3S**
  Même logique que Traefik : modifications des manifests K3S → push Gitea → pipeline → ArgoCD sync.
  À définir selon la maturité de ArgoCD auto-sync (peut-être déjà géré par ArgoCD webhook Gitea)

---

## Bloc 8 — Raspberry Pi + UPS

- [ ] **Ajout Raspberry Pi dans l'inventaire**
  Ajouter un groupe `raspberry_pi` dans `inventory/hosts.yml`, créer `host_vars/raspberry_pi.yml`

- [ ] **Serveur NUT (UPS)**
  Créer `playbooks/nut.yml` — installation NUT server sur le Pi (connecté à l'UPS en USB), configuration des clients NUT sur Flash et Wasp pour shutdown propre en cas de coupure

---

## Bloc 9 — Home Assistant

- [ ] **Import backup / création**
  Créer `playbooks/home_assistant.yml` — procédure d'import d'un backup HAOS existant via API HA (`/api/backup`) ou restauration depuis snapshot PBS, config des intégrations de base (réseau, Z-Wave via USB passthrough déjà défini)

---

## Bloc 10 — TrueNAS Hades *(distant — à faire quand accès facile)*

- [ ] **Pool + datasets Hades**
  Compléter `host_vars/truenas_hades.yml` avec `truenas_pool_name` et `truenas_datasets` (même pattern que Hermes), lancer `truenas_pool.yml --limit truenas_hades`

- [ ] **Réplication Hermes → Hades**
  Créer `playbooks/truenas_replication.yml` — configurer les tâches de réplication ZFS via API TrueNAS (`/replication`) pour les datasets critiques (K3S, K3S-Secure, Data)

- [ ] **Apps TrueNAS Hades**
  Définir les apps à déployer sur Hades dans `host_vars/truenas_hades.yml`, lancer `truenas.yml --limit truenas_hades --tags upgrade_all`
