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
configmap_template="configmap.yml.template"
deployment_template="deploy.yml.template"

ingress_file="ingress.yml"
configmap_file="configmap.yml"
deployment_file="deploy.yml"

# Funktion: bestehenden Wert aus Datei auslesen, sanitize und als leeren String zurückgeben
default_value() {
  local file="$1" pattern="$2" field="$3"
  local val=""
  if [[ -f "$file" ]]; then
    val=$(grep -E -- "$pattern" "$file" | head -n1 | awk "{print \$$field}" || true)
    # Entferne führende/trailing Quotes
    val=${val//\'/}
  fi
  echo "$val"
}

# Standardwerte aus bestehenden Dateien holen (sanitized + dekodiert)
default_fqdn=$(default_value "$ingress_file" "host:" 3)
maria_db_pass=$(default_value "$configmap_file" "mariadb_pass_sys:" 2)

# Eingaben abfragen (mit Vorschlägen)
read -rp "FQDN [${default_fqdn:-none}]: " fqdn
fqdn=${fqdn:-$default_fqdn}


# MariaDB-Root Password: nutze bestehendes oder generiere neu
if [[ -n "$maria_db_pass" ]]; then
  MARIA_PASS="$maria_db_pass"
else
  MARIA_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)
fi

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

# configmap.yml
out="$configmap_file"
if [[ -f "$configmap_template" ]]; then
  sed \
    -e "s|#MARIA_PASS#|$MARIA_PASS|g" \
    "$configmap_template" > "$out"
  echo "-> $out erstellt"
else
  echo "Fehler: $configmap_template nicht gefunden" >&2
  exit 1
fi


# deploy.yml
out="$deployment_file"
if [[ -f "$deployment_template" ]]; then
  sed \
    -e "s|#fqdn#|$fqdn|g" \
    "$deployment_template" > "$out"
  echo "-> $out erstellt"
else
  echo "Fehler: $deployment_template nicht gefunden" >&2
  exit 1
fi

echo "Wende Paperless IaC an..."
kubectl apply -f .
