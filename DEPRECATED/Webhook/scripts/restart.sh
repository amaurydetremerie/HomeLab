#! /bin/bash

case $1 in

  traefik)
    echo "systemctl daemon-reload; systemctl restart traefik.service" | ssh -i ../id_rsa root@10.100.0.1 /bin/bash
    exit 0
    ;;
  webhook)
    systemctl daemon-reload
    systemctl restart webhook.service
    exit 0
    ;;
  *)
    exit 1
    ;;
esac