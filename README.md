# WiseRisk's Homelab
## Introduction
This repository is here to help me centralize everything I need for my HomeLab. It's open to anyone who needs the information inside, and to suggestions for modifications.
The content is not necessarily up to date and depends mainly on my use.
If you need help with a specific configuration, I'll be happy to answer your questions.
## HomeLab design
### Hardware
My Homelab consists of an HP DL380p Gen 8 server, a Dell Precision 3630 and a Dell Optiplex 3070 (d10u003). I also have a 24-port Cisco switch.
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
### To Do 
7) Find a way to replace secrets in files (ArgoCD for K3S ? Env variables ?)
8) Setup Uptime Kuma in K3S and remove it from Portainer CT
9) Migrate all apps from Portainer CT to K3S
10) Check to migrate CT in K3S
11) Find some new intresting apps
12) Install Proxmox on Dell Optiplex
13) Move one K3S Instance on each server
14) Move Traefik Principal CT in K3S (What about LB ? Is it possible to use Ingress Controller to call external service like TrueNas or Pve ? What happen if home disconnected and service going to offsite ?)
15) Install off site server with instant sync for nas data, daily backup, k3s worker (or master ?)
16) Move Home Assistant to Dell Optiplex
17) Setup personal Docker Registry (Registry ? Pull Through ?)
       https://www.paulsblog.dev/how-to-install-a-private-docker-container-registry-in-kubernetes/
       https://medium.com/geekculture/deploying-docker-registry-on-kubernetes-3319622b8f32
18) Upgrade DL380p to run Truenas on it, decommissioning off-site I7, move Dell Precision off-site