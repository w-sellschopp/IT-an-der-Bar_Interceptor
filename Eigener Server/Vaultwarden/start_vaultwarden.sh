#!/usr/bin/env bash
clear
set -euo pipefail

# Logo und Banner anzeigen
if [ -f logo ]; then
  cat logo
else
  echo "-------------------------------------------------------------"
  echo " ACHTUNG: Dieses Skript wird ohne jegliche Gewähr bereitgestellt."
  echo " Es wird keine Haftung für eventuelle Schäden oder Fehlkonfigurationen übernommen."
  echo "-------------------------------------------------------------"
fi

echo ""
echo ""

# Template- und Zieldateien
ingress_template="ingress.yml.template"
secrets_template="secrets.yml.template"
configmap_template="configmap.yml.template"

ingress_file="ingress.yml"
secrets_file="secrets.yml"
configmap_file="configmap.yml"

# Funktion: bestehenden Wert aus Datei auslesen, optional Base64-dekodieren, sanitize und als leeren String zurückgeben
default_value() {
  local file="$1" pattern="$2" field="$3"
  local val=""
  if [[ -f "$file" ]]; then
    val=$(grep -E -- "$pattern" "$file" | head -n1 | awk "{print \$$field}" || true)
    # Entferne führende/trailing Quotes
    val=${val//\'/}
    # Base64-dekodieren für secrets
    if [[ "$pattern" =~ "emailUser:" ]] || [[ "$pattern" =~ "emailPassword:" ]] || [[ "$pattern" =~ "ADMIN_TOKEN:" ]]; then
      val=$(echo -n "$val" | base64 --decode)
    fi
  fi
  echo "$val"
}

# Standardwerte aus bestehenden Dateien holen (sanitized + dekodiert)
default_fqdn=$(default_value "$ingress_file" "host:" 3)
default_emailUser=$(default_value "$secrets_file" "emailUser:" 2)
default_emailPassword=$(default_value "$secrets_file" "emailPassword:" 2)
default_admin_token=$(default_value "$secrets_file" "ADMIN_TOKEN:" 2)
default_SMTP_HOST=$(default_value "$configmap_file" "SMTP_HOST:" 2)
default_SMTP_FROM=$(default_value "$configmap_file" "SMTP_FROM:" 2)
default_SMTP_PORT=$(default_value "$configmap_file" "SMTP_PORT:" 2)
default_SMTP_SSL=$(default_value "$configmap_file" "SMTP_SSL:" 2)

# Eingaben abfragen (mit Vorschlägen)
read -rp "FQDN [${default_fqdn:-none}]: " fqdn
fqdn=${fqdn:-$default_fqdn}

read -rp "SMTP Host [${default_SMTP_HOST:-none}]: " SMTP_HOST
SMTP_HOST=${SMTP_HOST:-$default_SMTP_HOST}

read -rp "SMTP From [${default_SMTP_FROM:-none}]: " SMTP_FROM
SMTP_FROM=${SMTP_FROM:-$default_SMTP_FROM}

read -rp "SMTP Port [${default_SMTP_PORT:-none}]: " SMTP_PORT
SMTP_PORT=${SMTP_PORT:-$default_SMTP_PORT}

read -rp "SMTP SSL (true/false) [${default_SMTP_SSL:-none}]: " SMTP_SSL
SMTP_SSL=${SMTP_SSL:-$default_SMTP_SSL}

read -rp "E-Mail Benutzer [${default_emailUser:-none}]: " emailUser
emailUser=${emailUser:-$default_emailUser}

read -rsp "E-Mail Passwort [${default_emailPassword:+vorhanden}]: " emailPassword
echo
emailPassword=${emailPassword:-$default_emailPassword}

# Admin-Token: nutze bestehenden oder generiere neu
if [[ -n "$default_admin_token" ]]; then
  ADMIN_TOKEN="$default_admin_token"
else
  ADMIN_TOKEN=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)
fi

# Base64-Encoding der sensiblen Werte
e_emailUser=$(echo -n "$emailUser" | base64)
e_emailPassword=$(echo -n "$emailPassword" | base64)
e_ADMIN_TOKEN=$(echo -n "$ADMIN_TOKEN" | base64)

# Aus Templates generieren
# ingress.yml
out="$ingress_file"
if [[ -f "$ingress_template" ]]; then
  sed \
    -e "s|#fqdn#|$fqdn|g" \
    "$ingress_template" > "$out"
  echo "-> $out erstellt"
else
  echo "Fehler: $ingress_template nicht gefunden" >&2
  exit 1
fi

# secrets.yml
out="$secrets_file"
if [[ -f "$secrets_template" ]]; then
  sed \
    -e "s|#emailUser#|$e_emailUser|g" \
    -e "s|#emailPassword#|$e_emailPassword|g" \
    -e "s|#ADMIN_TOKEN#|$e_ADMIN_TOKEN|g" \
    "$secrets_template" > "$out"
  echo "-> $out erstellt"
else
  echo "Fehler: $secrets_template nicht gefunden" >&2
  exit 1
fi

# configmap.yml
out="$configmap_file"
if [[ -f "$configmap_template" ]]; then
  sed \
    -e "s|#SMTP_HOST#|$SMTP_HOST|g" \
    -e "s|#SMTP_FROM#|$SMTP_FROM|g" \
    -e "s|#SMTP_PORT#|$SMTP_PORT|g" \
    -e "s|#SMTP_SSL#|$SMTP_SSL|g" \
    -e "s|#fqdn#|$fqdn|g" \
    "$configmap_template" > "$out"
  echo "-> $out erstellt"
else
  echo "Fehler: $configmap_template nicht gefunden" >&2
  exit 1
fi

echo "Fertig! Admin-Token: $ADMIN_TOKEN"

echo "Wende Vaultwarden IaC an..."
kubectl apply -f .

echo "Starte Vaultwarden Pod neu"
if kubectl get pod vaultwarden-0 -n vaultwarden &>/dev/null; then
  echo "Pod vaultwarden-0 gefunden, lösche..."
  kubectl delete pod vaultwarden-0 -n vaultwarden
  echo "Pod vaultwarden-0 wurde neugestartet (gelöscht)"
fi
