#!/bin/bash
clear

# Logo und Banner anzeigen
if [ -f logo ]; then
  cat logo
else
  echo "-------------------------------------------------------------"
  echo " ACHTUNG: Dieses Skript wird ohne jegliche Gewähr bereitgestellt."
  echo " Es wird keine Haftung für eventuelle Schäden oder Fehlkonfigurationen übernommen."
  echo "-------------------------------------------------------------"
fi

set -e

FIREWALL_DIR="/etc/iptables"
CONFIG_FILE="$FIREWALL_DIR/firewall.conf"
RULES_FILE="$FIREWALL_DIR/rules"
SYSTEMD_UNIT="/etc/systemd/system/iptables-rules.service"
CRON_FILE="/etc/cron.d/iptables_rules_restart"

# Sicherstellen, dass /etc/iptables existiert
mkdir -p "$FIREWALL_DIR"

# Falls bereits eine Konfiguration existiert, laden wir sie
if [ -f "$CONFIG_FILE" ]; then
  echo "Vorhandene Firewall-Konfiguration wird geladen..."
  source "$CONFIG_FILE"
fi

# Funktion, um Eingaben mit Defaultwert zu erhalten
prompt() {
  local var_name="$1"
  local prompt_text="$2"
  local current_val="${!var_name}"
  read -p "$prompt_text [${current_val}]: " input
  if [ -n "$input" ]; then
    eval "$var_name=\"$input\""
  fi
}

# Falls der systemd-Dienst bereits existiert, Auswahl anbieten
if [ -f "$SYSTEMD_UNIT" ]; then
  echo "Ein systemd-Dienst (iptables-rules.service) existiert bereits."
  echo "Bitte wähle:"
  echo "1) Dienst deaktivieren"
  echo "2) Firewall-Regeln bearbeiten (bestehende Konfiguration verwenden und ggf. ergänzen)"
  echo ""
  read -p "Deine Auswahl (1-2): " svc_choice
  case $svc_choice in
    1)
      systemctl disable iptables-rules.service || true
      systemctl stop iptables-rules.service || true
      rm "$SYSTEMD_UNIT"
      systemctl daemon-reload
      if [ -f "$CRON_FILE" ]; then
        rm "$CRON_FILE"
        echo "Cronjob zum stündlichen Neustart wurde entfernt."
      fi
      iptables -P INPUT ACCEPT
      iptables -F
      echo "Dienst wurde deaktiviert. Du kannst das Skript erneut ausführen, um die Regeln anzupassen."
      exit 0
      ;;
    2)
      echo "Bearbeitung der Firewall-Regeln wird fortgesetzt."
      ;;
    *)
      echo "Ungültige Auswahl, das Skript wird beendet."
      exit 1
      ;;
  esac
fi

# --- Interaktive Abfragen zur Konfiguration ---

# 1. Vertrauenswürdige Endpunkte (IPs oder DNS, kommagetrennt)
prompt TRUSTED_ENDPOINTS "Bitte gib vertrauenswürdige IPs/DNS-Endpunkte (kommagetrennt) ein"

# 2. Wireguard-Konfiguration prüfen: /etc/wireguard/wg_manager.conf
WG_CONF="/etc/wireguard/wg_manager.conf"
ALLOW_WG_UDP="ja"
if [ -f "$WG_CONF" ]; then
  source "$WG_CONF"
  prompt ALLOW_WG_UDP "Wireguard-Konfiguration gefunden. Möchtest du den UDP-Port $LISTEN_PORT freigeben? (ja/nein)"
fi

# 3. Zusätzliche öffentliche Ports (kommagetrennt)
prompt PUBLIC_PORTS "Bitte gib zusätzliche öffentliche Ports zum Freigeben (kommagetrennt) ein"

# 4. SSH: öffentlich oder nur für vertrauenswürdige Endpunkte?
prompt SSH_RULE "Soll SSH öffentlich freigegeben werden oder nur für vertrauenswürdige Endpunkte? (public/trusted)"

# Persistente Speicherung der Konfiguration (ohne TRUSTED_ONLY_PORTS)
cat <<EOF > "$CONFIG_FILE"
# Persistierte Firewall-Konfiguration
TRUSTED_ENDPOINTS="$TRUSTED_ENDPOINTS"
ALLOW_WG_UDP="$ALLOW_WG_UDP"
PUBLIC_PORTS="$PUBLIC_PORTS"
SSH_RULE="$SSH_RULE"
EOF

echo "Deine Konfiguration wurde unter $CONFIG_FILE gespeichert."

# --- Generierung der iptables-Regeln ---
echo "Erstelle /etc/iptables/rules ..."
cat <<'EOF' > "$RULES_FILE"
#!/bin/bash
# Generierte iptables-Regeln

# Zunächst: Alle Chains auf ACCEPT setzen und flushen
iptables -P INPUT ACCEPT
iptables -F
iptables -P FORWARD ACCEPT
iptables -F FORWARD
iptables -P OUTPUT ACCEPT
iptables -F OUTPUT

# IPv6 komplett blockieren, related und lo erlauben
ip6tables -P INPUT DROP
ip6tables -F
ip6tables -A INPUT -i lo -j ACCEPT
ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Standardregeln:
# Loopback-Schnittstelle erlauben
iptables -A INPUT -i lo -j ACCEPT
# Etablierte und zugehörige Verbindungen erlauben
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

EOF

# Dynamisch weitere Regeln einfügen
{
  echo ""
  echo "# Erlaube alle Verbindungen von den vertrauenswürdigen Endpunkten (für alle Protokolle)"
  IFS=',' read -ra ADDR <<< "$TRUSTED_ENDPOINTS"
  for addr in "${ADDR[@]}"; do
    t=$(echo "$addr" | xargs)
    echo "iptables -A INPUT -s $t -j ACCEPT"
  done

  # Wireguard UDP-Port freigeben (falls gewünscht)
  if [ "$ALLOW_WG_UDP" == "ja" ]; then
    echo ""
    echo "# Wireguard UDP-Port $LISTEN_PORT wird freigegeben"
    echo "iptables -A INPUT -p udp --dport $LISTEN_PORT -j ACCEPT"
  fi

  # Öffentliche Ports (für TCP und UDP)
  if [ -n "$PUBLIC_PORTS" ]; then
    IFS=',' read -ra PUB <<< "$PUBLIC_PORTS"
    for port in "${PUB[@]}"; do
      p=$(echo "$port" | xargs)
      echo ""
      echo "# Öffentlicher Port $p"
      echo "iptables -A INPUT -p tcp --dport $p -j ACCEPT"
      echo "iptables -A INPUT -p udp --dport $p -j ACCEPT"
    done
  fi

  # SSH-Regel
  echo ""
  if [ "$SSH_RULE" == "public" ]; then
    echo "# SSH wird öffentlich freigegeben"
    echo "iptables -A INPUT -p tcp --dport 22 -j ACCEPT"
  else
    echo "# SSH wird nur für vertrauenswürdige Endpunkte freigegeben"
    echo "iptables -A INPUT -p tcp --dport 22 -s $TRUSTED_ENDPOINTS -j ACCEPT"
  fi

  # Default-Drop: Alle weiteren Pakete verwerfen
  echo ""
  echo "# Default: Alle eingehenden Pakete verwerfen"
  echo "iptables -P INPUT DROP"
} >> "$RULES_FILE"

chmod +x "$RULES_FILE"
echo "Die iptables-Regeln wurden in $RULES_FILE erstellt."

# --- Systemd-Unit erstellen und aktivieren ---
echo "Erstelle den systemd-Dienst /etc/systemd/system/iptables-rules.service ..."
cat <<'EOF' > "$SYSTEMD_UNIT"
[Unit]
Description=Iptables Firewall Rules
After=network.target

[Service]
Type=oneshot
ExecStart=/etc/iptables/rules
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# systemd-Dienst laden, aktivieren und starten
systemctl daemon-reload
systemctl enable iptables-rules.service
systemctl restart iptables-rules.service

echo "Der systemd-Dienst iptables-rules.service wurde erstellt und aktiviert."

# --- Cronjob erstellen, der den Dienst stündlich neu startet ---
echo "Erstelle Cronjob zum stündlichen Neustart des Dienstes..."
cat <<EOF > "$CRON_FILE"
0 * * * * root systemctl restart iptables-rules.service
EOF
chmod 644 "$CRON_FILE"
echo "Cronjob unter $CRON_FILE wurde erstellt."

echo "Deine Firewall-Konfiguration ist abgeschlossen."
