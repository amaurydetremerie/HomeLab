#! /bin/bash

case $1 in

  traefik)
    echo "git -C /root/Homelab/Traefik pull origin main" | ssh root@10.100.0.1 /bin/bash
    exit 0
        ;;
  webhook)
    git -C /root/Homelab/Webhook pull origin main
    exit 0
        ;;
  *)
    exit 1
        ;;
esac