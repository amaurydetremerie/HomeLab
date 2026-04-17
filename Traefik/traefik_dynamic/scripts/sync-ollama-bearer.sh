#!/bin/bash

VAULT_ADDR="${VAULT_ADDR}"
VAULT_TOKEN="${VAULT_TOKEN}"
OUTPUT_FILE="/etc/Homelab/Traefik/traefik_dynamic/ollama-bearer.yaml"

TOKENS=$(curl --silent \
  -H "X-Vault-Request: true" \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/ollama/tokens" | jq -r '.data.data | to_entries | .[] | .value')

# Générer le fichier
cat > "$OUTPUT_FILE" << 'YAML'
http:
  middlewares:
    ollama-bearer:
      plugin:
        bearer-auth:
          tokens:
YAML

echo "$TOKENS" | while read token; do
  echo "            - \"$token\"" >> "$OUTPUT_FILE"
done