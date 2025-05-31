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

ingress_file="ingress.yml"

# Funktion: bestehenden Wert aus Datei auslesen
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

# Eingaben abfragen (mit Vorschlägen)
read -rp "FQDN [${default_fqdn:-none}]: " fqdn
fqdn=${fqdn:-$default_fqdn}

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

echo "Wende YoPass IaC an..."
kubectl apply -f .
