# Changelog

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