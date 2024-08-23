#! /bin/bash

case $1 in

  traefik)
    echo "systemctl restart traefik.service" | ssh webhook@10.100.0.1 /bin/bash
    exit 0
    ;;

  *)
    exit 1
    ;;
esac