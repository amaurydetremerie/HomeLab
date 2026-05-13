#!/bin/bash
# À lancer une fois après chaque clone : ./setup.sh

set -e

git config core.hooksPath .githooks
echo "✓ Git hooks activés (.githooks/)"

if [ ! -f ~/.vault_pass ]; then
  echo ""
  echo "⚠  Fichier ~/.vault_pass absent."
  echo "   Crée-le avec le mot de passe du vault Ansible :"
  echo "   echo 'mon_mot_de_passe' > ~/.vault_pass && chmod 600 ~/.vault_pass"
fi

echo ""
echo "Setup terminé."