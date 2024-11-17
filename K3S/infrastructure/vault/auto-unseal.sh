#!/bin/bash
# Script à exécuter après l'installation de Vault pour configurer l'auto-unseal

# Initialisation du premier nœud Vault
INIT_RESPONSE=$(kubectl exec vault-0 -n vault -- vault operator init -key-shares=1 -key-threshold=1 -format=json)

# Extraction des clés
UNSEAL_KEY=$(echo $INIT_RESPONSE | jq -r .unseal_keys_b64[0])
ROOT_TOKEN=$(echo $INIT_RESPONSE | jq -r .root_token)

# Déverrouillage du premier nœud
kubectl exec vault-0 -n vault -- vault operator unseal $UNSEAL_KEY

# Authentification avec le token root
kubectl exec vault-0 -n vault -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault secrets enable transit"
kubectl exec vault-0 -n vault -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault write -f transit/keys/autounseal"

# Configuration des politiques et des rôles pour ArgoCD
kubectl exec vault-0 -n vault -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault policy write argocd - <<EOF
path \"secret/data/k3s/*\" {
  capabilities = [\"read\"]
}
EOF"

kubectl exec vault-0 -n vault -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault auth enable kubernetes"
kubectl exec vault-0 -n vault -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault write auth/kubernetes/config \
    kubernetes_host=\"https://\$KUBERNETES_PORT_443_TCP_ADDR:443\" \
    token_reviewer_jwt=\"\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)\" \
    kubernetes_ca_cert=\"\$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)\" \
    issuer=\"https://kubernetes.default.svc.cluster.local\""

kubectl exec vault-0 -n vault -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault write auth/kubernetes/role/argocd \
    bound_service_account_names=argocd-repo-server \
    bound_service_account_namespaces=argocd \
    policies=argocd \
    ttl=1h"