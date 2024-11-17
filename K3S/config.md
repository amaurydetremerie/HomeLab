To use registry in K3S, add lines to /etc/rancher/k3s/registries.yaml
```yaml
mirrors:
  docker.io:
    endpoint:
      - "http://registry.registry-system:5000"
    rewrite:
      "^library/(.*)": "$1"
configs:
  "registry.registry-system:5000":
    auth:
      username: <your_docker_username>
      password: <your_docker_password>
```

We need to create some secrets in Vault.

For registry :
```
kubectl exec -it vault-0 -n vault -- sh
vault login <root_token>
vault kv put secret/k3s/registry \
  docker_username=<your_docker_username> \
  docker_password=<your_docker_password>
```