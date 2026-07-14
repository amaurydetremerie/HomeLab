# Changelog

## v2026.07.14-1794e90

### Nettoyage

- Suppression d'une configuration relabel oubliée dans Prometheus

## v2026.07.14-f0c1803

### Infrastructure Proxmox
- Mise à jour des configurations Flash et Wasp
- Améliorations de la provisioning des VMs/LXC

### Services *arr (Sonarr/Radarr/Lidarr)
- Nouveau stack complet : playbook `arr.yml`, host_vars, et configuration Docker Compose
- Intégration Traefik pour exposition externe
- Templates : config homer, routeur ebook, worker KCC

### Qualité de service
- Amélioration configuration qBittorrent (Ansible + Traefik)
- Mise à jour de la configuration Authelia

### Monitoring & Observabilité
- Reconfiguration scrapes Prometheus
- Mise à jour HLabMonitor

### Cleanup K3S
- Suppression application Prowlarr (migré vers stack ARR)

### Infrastructure générale
- Ajout requirements Ansible manquants
- Mise à jour .gitignore
- Documentation mise à jour (NEXT_STEPS.md)

## v2026.06.13-0f9cf5c

### Déprécations
- Webhook déprécié

### Suppressions
- Dossier `script/` supprimé

## v2026.06.13-544df48

### Infrastructure
- GPU retiré du nœud Flash
- Ollama supprimé

## v2026.06.07-e885705

### Outils K3S
- Mise à jour de la version Termix

## v2026.06.07-9aa9f3e

### Infrastructure K3S

- Ajout de Termix avec deployment, ingress, et volumes persistants

## v2026.06.07-d699a97

### VPS & Réseau
- Mise à jour du nouveau VPS
- Ajout d'un watchdog pour le VPN

### Monitoring
- Mise à jour des configurations de monitoring

### Applications
- Désactivation de l'application de synchronisation

### Tâches planifiées
- Ajustement du spacing des tâches cron

## v2026.05.25-0f9cb29

### Monitoring

- Suppression des targets Prometheus redondantes ou inutilisées (ollama, k3s publiques, pve local, adguard VPS, prowlarr, hlabmonitor)
- Simplification des ingress : HLabMonitor et Prowlarr au seul domaine `.k3s.wiserisk.home` (suppression des `.k3s.wiserisk.be`)
- Retrait du target `pve-local` dans HLabMonitor

### Observabilité

- Ajustement des timeouts Blackbox

### Documentation

- Mise à jour du CLAUDE.md

## v2026.05.25-52e2b39

### CI/CD

- Amélioration du système de détection des changements dans les workflows Gitea Actions pour inclure les playbooks Ansible Traefik

### Infrastructure

- Ajout des dépendances `iptables` et `iptables-persistent` au playbook Traefik
- Correction de la sauvegarde des règles iptables avec création préalable du répertoire `/etc/iptables`

## v2026.05.25-5d82dc7

### Réseau Traefik
- Ajout de la règle MASQUERADE iptables (10.100.0.0/24 → 10.0.0.0/24) pour les nœuds gateway
- Sauvegarde automatique des règles iptables

### Monitoring
- Suppression du mode `hostNetwork` pour Blackbox Exporter

## v2026.05.25-b36fac5

### DNS

- Préparation du forwarder DNS pour AdGuard Flash (configuration commentée prête pour le déploiement)

## v2026.05.25-af6292a

### Monitoring

- CoreDNS : mise à jour du serveur DNS forwarder (10.0.0.181)
- Blackbox Exporter : activation du mode `hostNetwork` pour accès réseau direct

## v2026.05.25-2e3310d

### Applications
- Déploiement de it-tools dans K3S (application, service, ingress et ArgoCD)

### Infrastructure
- Mise à jour Prometheus scrape configuration
- Ajustements ingress it-tools

### CI/CD
- Correction de l'utilisation de `event.before` pour diff complet dans monitoring-check
- Optimisation des workflows Gitea Actions (changelog.yml)
- Mise à jour de l'action claude-prompt

Généré automatiquement à chaque push sur `main` via Gitea Actions + Claude.