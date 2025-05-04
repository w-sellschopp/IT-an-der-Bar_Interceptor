#!/usr/bin/env bash
set -euo pipefail

echo "-------------------------------------------------------------"
echo " ACHTUNG: Dieses Skript wird ohne jegliche Gewähr bereitgestellt."
echo " Es wird keine Haftung für eventuelle Schäden oder Fehlkonfigurationen übernommen."
echo "-------------------------------------------------------------"

# Template- und Zieldateien
ingress_template="ingress.yml.template"
secrets_template="secrets.yml.template"
configmap_template="configmap.yml.template"

ingress_file="ingress.yml"
secrets_file="secrets.yml"
configmap_file="configmap.yml"

# Funktion: bestehenden Wert aus Datei auslesen oder leeren String zurückgeben
get_value() {
  local file="$1" pattern="$2"
  if [[ -f "$file" ]]; then
    grep -E "$pattern" "$file" | head -n1 | awk '{print $2}'
  fi
}

# Standardwerte aus bestehenden Dateien holen
default_fqdn=$(get_value "$ingress_file" "- #")
# Aus secrets.yml base64-decodierte Werte
default_emailUser=$(get_value "$secrets_file" "emailUser:")
if [[ -n "$default_emailUser" ]]; then
  default_emailUser=$(echo -n "$default_emailUser" | base64 --decode)
fi
default_emailPassword=$(get_value "$secrets_file" "emailPassword:")
if [[ -n "$default_emailPassword" ]]; then
  default_emailPassword=$(echo -n "$default_emailPassword" | base64 --decode)
fi
# Configmap-Werte
default_SMTP_HOST=$(get_value "$configmap_file" "SMTP_HOST:")
default_SMTP_FROM=$(get_value "$configmap_file" "SMTP_FROM:")
default_SMTP_PORT=$(get_value "$configmap_file" "SMTP_PORT:")
default_SMTP_SSL=$(get_value "$configmap_file" "SMTP_SSL:")

# Eingaben abfragen (mit Vorschlägen)
read -rp "FQDN [${default_fqdn:-none}]: " fqdn
fqdn=${fqdn:-$default_fqdn}
read -rp "E-Mail Benutzer [${default_emailUser:-none}]: " emailUser
emailUser=${emailUser:-$default_emailUser}
read -rsp "E-Mail Passwort [${default_emailPassword:+vorhanden}]: " emailPassword
echo
emailPassword=${emailPassword:-$default_emailPassword}
read -rp "SMTP Host [${default_SMTP_HOST:-none}]: " SMTP_HOST
SMTP_HOST=${SMTP_HOST:-$default_SMTP_HOST}
read -rp "SMTP From [${default_SMTP_FROM:-none}]: " SMTP_FROM
SMTP_FROM=${SMTP_FROM:-$default_SMTP_FROM}
read -rp "SMTP Port [${default_SMTP_PORT:-none}]: " SMTP_PORT
SMTP_PORT=${SMTP_PORT:-$default_SMTP_PORT}
read -rp "SMTP SSL (true/false) [${default_SMTP_SSL:-none}]: " SMTP_SSL
SMTP_SSL=${SMTP_SSL:-$default_SMTP_SSL}

# Zufälliges ADMIN_TOKEN (32 Zeichen alphanumerisch)
ADMIN_TOKEN=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)

# Base64-Encoding der sensiblen Werte
e_emailUser=$(echo -n "$emailUser" | base64)
e_emailPassword=$(echo -n "$emailPassword" | base64)
e_ADMIN_TOKEN=$(echo -n "$ADMIN_TOKEN" | base64)

# Aus Templates generieren

# ingress.yml
template="$ingress_template"
out="$ingress_file"
if [[ -f "$template" ]]; then
  sed \
    -e "s|#fqdn#|$fqdn|g" \
    "$template" > "$out"
  echo "-> $out erstellt"
else
  echo "Fehler: $template nicht gefunden" >&2
  exit 1
fi

# secrets.yml
template="$secrets_template"
out="$secrets_file"
if [[ -f "$template" ]]; then
  sed \
    -e "s|#emailUser#|$e_emailUser|g" \
    -e "s|#emailPassword#|$e_emailPassword|g" \
    -e "s|#ADMIN_TOKEN#|$e_ADMIN_TOKEN|g" \
    "$template" > "$out"
  echo "-> $out erstellt"
else
  echo "Fehler: $template nicht gefunden" >&2
  exit 1
fi

# configmap.yml
template="$configmap_template"
out="$configmap_file"
if [[ -f "$template" ]]; then
  sed \
    -e "s|#SMTP_HOST#|$SMTP_HOST|g" \
    -e "s|#SMTP_FROM#|$SMTP_FROM|g" \
    -e "s|#SMTP_PORT#|$SMTP_PORT|g" \
    -e "s|#SMTP_SSL#|$SMTP_SSL|g" \
    -e "s|#fqdn#|$fqdn|g" \
    "$template" > "$out"
  echo "-> $out erstellt"
else
  echo "Fehler: $template nicht gefunden" >&2
  exit 1
fi

echo "Fertig! Admin-Token: $ADMIN_TOKEN"

echo "Starte Vaultwarden"
kubectl apply -f .