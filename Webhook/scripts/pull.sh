#! /bin/bash

case $1 in

  traefik)
    echo "cd /var/traefik; git fetch; git pull" | ssh webhook@10.100.0.1 /bin/bash
    exit 0
    ;;

  *)
    exit 1
    ;;
esac