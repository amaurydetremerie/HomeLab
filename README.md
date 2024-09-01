# WiseRisk's Homelab
## Introduction
This repository is here to help me centralize everything I need for my HomeLab. It's open to anyone who needs the information inside, and to suggestions for modifications.
The content is not necessarily up to date and depends mainly on my use.
If you need help with a specific configuration, I'll be happy to answer your questions.
## HomeLab design
### Hardware
My HomeLab consists of an HP DL380p Gen 8 server, a Dell Precision 3630 and a Dell Optiplex 3070 (d10u003). I also have a 24-port Cisco switch.
Off-Site I own an old No Name computer with an I7-2600.
### Software
All my servers run under Proxmox, and my data is managed in a TrueNas Scale virtual machine.
## RoadMap
1) Create a Load Balancer with Traefik on the principal Traefik Container.
   1) Done [here](Traefik/traefik_dynamic/k3s.yml#L47)
   2) Find a way to automatically update Traefik Principal CT when files changes
2) Create HA K3S with Etcd
   1) Done with https://docs.k3s.io/datastore/ha-embedded
3) Save all K3S applications data on Truenas
   1) Based on https://www.youtube.com/watch?v=pumX2Ds5L0c&list=PLj-2elZxVPZ8U5_gxuF_GFWelIo9kFlAj&index=3&ab_channel=ChristianLempa
   2) [Persistent volume creation with NFS](Kubernetes/Example/whoami.yml#L1)
   3) [Persistent volume claim creation](Kubernetes/Example/whoami.yml#L15)
   4) [Persistent volume definition](Kubernetes/Example/whoami.yml#L53)
   5) [Persistent volume mount](Kubernetes/Example/whoami.yml#L49)
4) Use Traefik as Ingress Controller
   1) Done with K3S Traefik Ingress Controller. Usage of [HelmChartConfig](Kubernetes/K3S/Traefik/traefik-config.yaml)
5) Setup Portainer in K3S
   1) Based on https://www.youtube.com/watch?v=gHHIAprNVmk&list=PLj-2elZxVPZ8U5_gxuF_GFWelIo9kFlAj&index=8&ab_channel=ChristianLempa
6) Setup ArgoCD
   1) Based on https://www.youtube.com/watch?v=Yb3_4PZX0B0&list=PLj-2elZxVPZ8U5_gxuF_GFWelIo9kFlAj&index=13&ab_channel=ChristianLempa
7) Setup Uptime Kuma in K3S and remove it from Portainer CT
   1) Check [Gatus](https://github.com/TwiN/gatus) to deploy health check with declarative configuration
8) Migrate all apps from Portainer CT to K3S
9) Find a way to replace secrets in files
   1) Using Vault, Based on https://devopscube.com/vault-in-kubernetes/
10) Configure [Homepage](Kubernetes/K3S/Homepage/homepage.yaml#L8)
11) Configure [LibreSpeed](Kubernetes/K3S/LibreSpeed/librespeed.yaml)
12) Configure [Tautulli](Kubernetes/K3S/Tautulli/tautulli.yaml)
13) Configure [Speedtest Tracker](Kubernetes/K3S/SpeedtestTracker/speedtestTracker.yaml)
    1) https://github.com/maximemoreillon/kubernetes-manifests/tree/master/speedtest-tracker
14) Create [webhook](Webhook) to automatically update Traefik configurations with [GitHub Actions](.github/workflows/traefik.yml)
### To Do
1) Check to migrate CT in K3S (Still Graphana, Influx, Prometheus)
2) Find some new interesting apps
    1) [FireflyIII](https://firefly-iii.org/)
    2) [ActualBudget](https://actualbudget.org/)
    3) [Paisa](https://paisa.fyi/)
    7) [Authelia](https://www.authelia.com/)
3) Install Proxmox on Dell Optiplex
4) Move one K3S Instance on each server
5) Install off site server with instant sync for nas data, daily backup, k3s worker (or master ?)
6) Move Home Assistant to Dell Optiplex
7) VPS instead of Cloudflare ?
8) Setup personal Docker Registry (Registry ? Pull Through ?)
       https://www.paulsblog.dev/how-to-install-a-private-docker-container-registry-in-kubernetes/
       https://medium.com/geekculture/deploying-docker-registry-on-kubernetes-3319622b8f32
9) Upgrade DL380p to run Truenas on it, decommissioning off-site I7, move Dell Precision off-site
    1) https://www.goharddrive.com/default.asp