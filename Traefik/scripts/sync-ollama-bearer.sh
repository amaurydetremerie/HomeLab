#!/bin/bash

VAULT_ADDR="${VAULT_ADDR}"
VAULT_TOKEN="${VAULT_TOKEN}"
OUTPUT_FILE="/etc/Homelab/Traefik/traefik_dynamic/ollama-bearer.yaml"

RAW=$(curl --silent --insecure \
  -H "X-Vault-Request: true" \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/ollama")

TOKENS=$(echo "$RAW" | jq -r '.data.data | .[]')

cat > "$OUTPUT_FILE" << 'YAML'
http:
  middlewares:
    ollama-bearer:
      plugin:
        traefik-api-token-middleware:
          authenticationHeader: false
          bearerHeader: true
          bearerHeaderName: Authorization
          tokens:
YAML

echo "$TOKENS" | while read -r token; do
  echo "            - \"$token\"" >> "$OUTPUT_FILE"
done