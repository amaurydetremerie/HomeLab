#! /bin/bash

case $1 in

  traefik)
    echo "git -C /etc/Homelab reset --hard;git -C /etc/Homelab pull origin main" | ssh -i ../id_rsa root@10.100.0.1 /bin/bash
    exit 0
        ;;
  webhook)
    git -C /etc/Homelab reset --hard
    git -C /etc/Homelab pull origin main
    exit 0
        ;;
  *)
    exit 1
        ;;
esac