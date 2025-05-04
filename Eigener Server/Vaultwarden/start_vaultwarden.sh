#!/usr/bin/env bash
set -euo pipefail

echo "-------------------------------------------------------------"
echo " ACHTUNG: Dieses Skript wird ohne jegliche Gewähr bereitgestellt."
echo " Es wird keine Haftung für eventuelle Schäden oder Fehlkonfigurationen übernommen."
echo "-------------------------------------------------------------"

# Eingaben abfragen
read -rp "FQDN (vaultwarden.meine-domain.de): " fqdn
read -rp "E-Mail Benutzer: " emailUser
read -rsp "E-Mail Passwort: " emailPassword
echo
read -rp "SMTP Host: " SMTP_HOST
read -rp "SMTP From: " SMTP_FROM
read -rp "SMTP Port: " SMTP_PORT
read -rp "SMTP SSL (true/false): " SMTP_SSL

# Zufälliges ADMIN_TOKEN (32 Zeichen alphanumerisch)
ADMIN_TOKEN=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)

# Base64-Encoding der sensiblen Werte
emailUser_b64=$(echo -n "$emailUser" | base64)
emailPassword_b64=$(echo -n "$emailPassword" | base64)
ADMIN_TOKEN_b64=$(echo -n "$ADMIN_TOKEN" | base64)

# Platzhalter in bestehenden Dateien ersetzen (in-place)

# ingress.yaml
if [[ -f ingress.yml ]]; then
  sed -i \
    -e "s|#fqdn#|$fqdn|g" \
    ingress.yml
  echo "-> ingress.yml aktualisiert"
else
  echo "Fehler: ingress.yml nicht gefunden" >&2
  exit 1
fi

# secrets.yml
if [[ -f secrets.yml ]]; then
  sed -i \
    -e "s|#emailUser#|$emailUser_b64|g" \
    -e "s|#emailPassword#|$emailPassword_b64|g" \
    -e "s|#ADMIN_TOKEN#|$ADMIN_TOKEN_b64|g" \
    secrets.yml
  echo "-> secrets.yml aktualisiert"
else
  echo "Fehler: secrets.yml nicht gefunden" >&2
  exit 1
fi

# configmap.yml
if [[ -f configmap.yml ]]; then
  sed -i \
    -e "s|#SMTP_HOST#|$SMTP_HOST|g" \
    -e "s|#SMTP_FROM#|$SMTP_FROM|g" \
    -e "s|#SMTP_PORT#|$SMTP_PORT|g" \
    -e "s|#SMTP_SSL#|$SMTP_SSL|g" \
    configmap.yml
  echo "-> configmap.yml aktualisiert"
else
  echo "Fehler: configmap.yml nicht gefunden" >&2
  exit 1
fi

echo "Fertig! Admin-Token: $ADMIN_TOKEN"

echo "Starte Vaultwarden"
kubectl apply -f .