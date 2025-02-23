#!/bin/bash
echo "-------------------------------------------------------------"
echo " ACHTUNG: Dieses Skript wird ohne jegliche Gewähr bereitgestellt."
echo " Es wird keine Haftung für eventuelle Schäden oder Fehlkonfigurationen übernommen."
echo "-------------------------------------------------------------"

##############################
# Globale Variablen
##############################
WG_IFACE="wg0"
WG_CONF="/etc/wireguard/${WG_IFACE}.conf"
CLIENTS_DIR="/etc/wireguard/clients"
SERVER_KEYS_DIR="/etc/wireguard/keys"
GLOBAL_CONF="/etc/wireguard/wg_manager.conf"

# Default DNS: Quad9
DEFAULT_DNS="9.9.9.9"

# Falls vorhanden, globale Konfiguration laden (z.B. DNS_SERVER, PUBLIC_IP, LISTEN_PORT)
if [ -f "$GLOBAL_CONF" ]; then
    source "$GLOBAL_CONF"
fi

##############################
# Funktion: Abfrage für Ja/Nein (akzeptiert ja, j, yes, y bzw. nein, n, no)
##############################
ask_confirm() {
    local prompt="$1"
    local answer
    read -p "$prompt" answer
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
    case "$answer" in
        ja|j|yes|y) return 0 ;;
        nein|n|no) return 1 ;;
        *) return 1 ;;
    esac
}

##############################
# Hilfsfunktionen für IP-Arithmetik
##############################
ip_to_int() {
    local IFS=.
    read -r a b c d <<< "$1"
    echo $(( (a << 24) + (b << 16) + (c << 8) + d ))
}

int_to_ip() {
    local ip_int=$1
    echo "$(( (ip_int >> 24) & 0xFF )).$(( (ip_int >> 16) & 0xFF )).$(( (ip_int >> 8) & 0xFF )).$(( ip_int & 0xFF ))"
}

##############################
# Aus der WG_CONF den Netzwerkbereich laden
##############################
load_network_config() {
    if [ ! -f "$WG_CONF" ]; then
        echo "Die WG-Konfiguration wurde nicht gefunden."
        exit 1
    fi
    # Erwartet eine Zeile wie: "Address = 10.0.0.1/24"
    local addr_line
    addr_line=$(grep "^Address" "$WG_CONF" | head -n1 | awk '{print $3}')
    SERVER_IP=$(echo "$addr_line" | cut -d'/' -f1)
    CIDR=$(echo "$addr_line" | cut -d'/' -f2)
    # Ermitteln des Netzwerkbereichs mittels ipcalc
    local net_addr
    net_addr=$(ipcalc -n "${SERVER_IP}/${CIDR}" | cut -d'=' -f2)
    WG_SUBNET="${net_addr}/${CIDR}"
    HOST_MIN=$(ipcalc "${WG_SUBNET}" | grep 'HostMin' | awk '{print $2}')
    HOST_MAX=$(ipcalc "${WG_SUBNET}" | grep 'HostMax' | awk '{print $2}')
}

##############################
# Ermittelt die nächste freie IP im konfigurierten Subnetz
##############################
get_next_ip() {
    load_network_config
    local server_int
    server_int=$(ip_to_int "$SERVER_IP")
    # Clients beginnen ab Server-IP + 1
    local next_ip_int=$(( server_int + 1 ))
    local host_max_int
    host_max_int=$(ip_to_int "$HOST_MAX")
    local used_ints=()
    # Sammle alle in der WG-Konfiguration vorhandenen IPs (im Peer-Bereich)
    while read -r line; do
         local ip
         ip=$(echo "$line" | awk -F'=' '{print $2}' | awk -F'/' '{print $1}' | tr -d ' ')
         if [ -n "$ip" ]; then
             used_ints+=("$(ip_to_int "$ip")")
         fi
    done < <(grep "AllowedIPs" "$WG_CONF")

    for (( ip_int=next_ip_int; ip_int<=host_max_int; ip_int++ )); do
         local found=0
         for used in "${used_ints[@]}"; do
             if [ "$ip_int" -eq "$used" ]; then
                 found=1
                 break
             fi
         done
         if [ "$found" -eq 0 ]; then
             int_to_ip "$ip_int"
             return
         fi
    done
    echo "Keine freie IP im Subnetz ${WG_SUBNET} verfügbar." >&2
    exit 1
}

##############################
# Grundinstallation: Installiert WireGuard, generiert Schlüssel,
# fragt nach dem Adressbereich, Port, DNS sowie externer IP/DNS und legt die
# Basis-Konfiguration (nur den Server) an.
##############################
basic_install() {
    echo "Starte Grundinstallation von WireGuard und Basis-Konfiguration..."

    # Schnittstelle ggf. herunterfahren
    wg-quick down ${WG_IFACE} 2>/dev/null

    # System aktualisieren und notwendige Pakete installieren
    apt update && apt upgrade -y
    apt install -y wireguard wireguard-tools qrencode curl git iptables ipcalc

    # IP-Forwarding aktivieren (temporär und persistent)
    sysctl -w net.ipv4.ip_forward=1
    sysctl -w net.ipv6.conf.all.forwarding=1
    grep -qxF "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    grep -qxF "net.ipv6.conf.all.forwarding=1" /etc/sysctl.conf || echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf

    # Standard-Netzwerkinterface ermitteln (für NAT-Regeln)
    DEFAULT_IFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
    echo "Dein Standard-Netzwerkinterface ist: ${DEFAULT_IFACE}"

    # Erstellen der Verzeichnisse für Schlüssel und Client-Konfigurationen
    mkdir -p "$SERVER_KEYS_DIR"
    chmod 700 "$SERVER_KEYS_DIR"
    mkdir -p "$CLIENTS_DIR"
    chmod 700 "$CLIENTS_DIR"

    # Adressbereich konfigurieren
    read -p "Bitte gib den Adressbereich ein (Default: 10.0.0.0/24): " input_range
    if [ -z "$input_range" ]; then
        WG_SUBNET="10.0.0.0/24"
    else
        WG_SUBNET="$input_range"
    fi
    CIDR=$(echo "$WG_SUBNET" | cut -d'/' -f2)
    # Mithilfe von ipcalc wird der erste nutzbare Host (HostMin) ermittelt – als Server-IP
    SERVER_IP=$(ipcalc "$WG_SUBNET" | grep 'HostMin' | awk '{print $2}')
    # WG_SUBNET als Netzwerkadresse neu zusammenbauen
    local net_addr
    net_addr=$(ipcalc -n "$WG_SUBNET" | cut -d'=' -f2)
    WG_SUBNET="${net_addr}/${CIDR}"
    HOST_MIN=$(ipcalc "${WG_SUBNET}" | grep 'HostMin' | awk '{print $2}')
    HOST_MAX=$(ipcalc "${WG_SUBNET}" | grep 'HostMax' | awk '{print $2}')

    echo "Verwendeter Adressbereich: ${WG_SUBNET}"
    echo "Die Server-IP wird auf ${SERVER_IP} gesetzt."

    # Port wählen: Zufälliger Standardport zwischen 30000 und 50000
    DEFAULT_PORT=$(( RANDOM % (50000 - 30000 + 1) + 30000 ))
    read -p "Bitte gib den ListenPort ein (Default: $DEFAULT_PORT): " input_port
    if [ -z "$input_port" ]; then
        LISTEN_PORT=$DEFAULT_PORT
    else
        LISTEN_PORT=$input_port
    fi
    echo "Der ListenPort wird auf ${LISTEN_PORT} gesetzt."

    # DNS konfigurieren (Default: DEFAULT_DNS)
    read -p "Bitte gib den DNS-Server ein (Default: ${DEFAULT_DNS}): " input_dns
    if [ -z "$input_dns" ]; then
        DNS_SERVER="${DEFAULT_DNS}"
    else
        DNS_SERVER="$input_dns"
    fi
    echo "Der DNS-Server wird auf ${DNS_SERVER} gesetzt."

    # Externe Adresse (IP oder DNS) abfragen
    read -p "Bitte gib die externe IP oder den DNS-Namen ein (leer für automatische Ermittlung): " input_ext
    if [ -n "$input_ext" ]; then
        # Prüfen, ob es sich um eine IP handelt
        if [[ "$input_ext" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Eingegebene externe Adresse wird als IP erkannt."
            PUBLIC_IP="$input_ext"
        else
            echo "Eingegebene externe Adresse wird als DNS-Name interpretiert."
            PUBLIC_IP="$input_ext"
        fi
    else
        PUBLIC_IP=$(curl -4 -s ifconfig.me)
        if [ -z "$PUBLIC_IP" ]; then
            PUBLIC_IP=$(curl -4 -s https://ipv4.icanhazip.com)
        fi
        PUBLIC_IP=$(echo "$PUBLIC_IP" | tr -d '\n')
    fi
    echo "Die öffentliche Adresse/DNS lautet: ${PUBLIC_IP}"

    # Persistiere die globalen Einstellungen (DNS, PUBLIC_IP und LISTEN_PORT)
    {
      echo "DNS_SERVER=${DNS_SERVER}"
      echo "PUBLIC_IP=${PUBLIC_IP}"
      echo "LISTEN_PORT=${LISTEN_PORT}"
    } > "$GLOBAL_CONF"

    # Generieren der Server-Schlüssel
    umask 077
    wg genkey | tee "$SERVER_KEYS_DIR/server_private.key" > /dev/null
    wg pubkey < "$SERVER_KEYS_DIR/server_private.key" > "$SERVER_KEYS_DIR/server_public.key"
    SERVER_PRIV_KEY=$(cat "$SERVER_KEYS_DIR/server_private.key" | xargs)
    if [ -z "$SERVER_PRIV_KEY" ]; then
        echo "Fehler: Der SERVER_PRIV_KEY ist leer. Die Schlüssel konnten nicht generiert werden."
        exit 1
    fi

    # Anlegen der Server-Konfiguration (nur Server, ohne Client-Abschnitte)
    cat <<EOF > "$WG_CONF"
[Interface]
Address = ${SERVER_IP}/${CIDR}
ListenPort = ${LISTEN_PORT}
PrivateKey = ${SERVER_PRIV_KEY}
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${DEFAULT_IFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${DEFAULT_IFACE} -j MASQUERADE
EOF

    # Starte die WireGuard-Schnittstelle
    wg-quick down ${WG_IFACE} 2>/dev/null
    wg-quick up ${WG_IFACE}
    systemctl enable wg-quick@${WG_IFACE}

    echo "---------------------------------------------------------"
    echo "Die Grundinstallation wurde abgeschlossen."
    echo "Die Basis-Konfiguration (Server) wurde angelegt."
    echo "---------------------------------------------------------"
}

##############################
# Verwaltungsfunktionen zum Hinzufügen/Löschen von Clients und Entfernen aller Konfigurationen
##############################
add_client() {
    echo "Neuen Client hinzufügen"
    read -p "Bitte gib den Client-Namen ein: " client_name
    if [ -f "$CLIENTS_DIR/${client_name}.conf" ]; then
        echo "Client ${client_name} existiert bereits."
        return
    fi

    # Sicherstellen, dass ein DNS-Wert vorhanden ist (Default: DEFAULT_DNS)
    DNS_SERVER=${DNS_SERVER:-${DEFAULT_DNS}}

    umask 077
    client_priv=$(wg genkey)
    client_pub=$(echo "$client_priv" | wg pubkey)

    client_ip=$(get_next_ip)

    if [ ! -f "$SERVER_KEYS_DIR/server_public.key" ]; then
        echo "Der Server Public Key wurde nicht gefunden in $SERVER_KEYS_DIR/server_public.key"
        exit 1
    fi
    server_pub=$(cat "$SERVER_KEYS_DIR/server_public.key")

    # PSK für diese Verbindung generieren
    psk=$(wg genpsk)

    # Verwende den persistierten LISTEN_PORT, sonst aus der WG-Konfiguration
    LISTEN_PORT=${LISTEN_PORT:-$(grep "^ListenPort" "$WG_CONF" | awk '{print $3}')}

    # Verwende den persistierten PUBLIC_IP, falls vorhanden – sonst automatische Ermittlung
    if [ -z "$PUBLIC_IP" ]; then
        public_ip=$(curl -4 -s ifconfig.me)
        if [ -z "$public_ip" ]; then
            public_ip=$(curl -4 -s https://ipv4.icanhazip.com)
        fi
        public_ip=$(echo "$public_ip" | tr -d '\n')
    else
        public_ip="$PUBLIC_IP"
    fi

    # Erstelle die Client-Konfiguration (inklusive PSK und DNS)
    cat <<EOF > "$CLIENTS_DIR/${client_name}.conf"
[Interface]
PrivateKey = ${client_priv}
Address = ${client_ip}/32
DNS = ${DNS_SERVER}

[Peer]
PublicKey = ${server_pub}
PresharedKey = ${psk}
Endpoint = ${public_ip}:${LISTEN_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

    # Hänge den neuen Peer-Eintrag in die Server-Konfiguration ein (inklusive PSK)
    cat <<EOF >> "$WG_CONF"

# Client: ${client_name}
[Peer]
PublicKey = ${client_pub}
PresharedKey = ${psk}
AllowedIPs = ${client_ip}/32
EOF

    wg syncconf ${WG_IFACE} <(wg-quick strip "$WG_CONF")

    echo "Client ${client_name} wurde mit der IP ${client_ip} hinzugefügt."
    echo "Client-Konfiguration:"
    cat "$CLIENTS_DIR/${client_name}.conf"
    echo "QR-Code für den Client ${client_name}:"
    qrencode -t ANSIUTF8 < "$CLIENTS_DIR/${client_name}.conf"
}

delete_client() {
    echo "Vorhandene Clients:"
    clients=($(ls "$CLIENTS_DIR"/*.conf 2>/dev/null | xargs -n1 basename | sed 's/\.conf//'))
    if [ ${#clients[@]} -eq 0 ]; then
        echo "Es wurden keine Clients gefunden."
        return
    fi
    for i in "${!clients[@]}"; do
        echo "$((i+1)). ${clients[$i]}"
    done
    read -p "Bitte wähle die Nummer des zu löschenden Clients: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#clients[@]}" ]; then
        echo "Ungültige Auswahl."
        return
    fi
    client_name="${clients[$((choice-1))]}"

    # Entferne den entsprechenden [Peer]-Abschnitt aus der WG-Konfiguration
    awk -v client="# Client: ${client_name}" '{
        if($0 == client) {skip=1; next}
        if(skip && /^$/) {skip=0}
        if(!skip) print $0
    }' "$WG_CONF" > "$WG_CONF.tmp" && mv "$WG_CONF.tmp" "$WG_CONF"

    rm -f "$CLIENTS_DIR/${client_name}.conf"
    wg syncconf ${WG_IFACE} <(wg-quick strip "$WG_CONF")

    echo "Client ${client_name} wurde entfernt."
}

remove_all_config() {
    wg-quick down ${WG_IFACE} 2>/dev/null
    rm -f "$WG_CONF"
    rm -rf "$CLIENTS_DIR"
    rm -f "$GLOBAL_CONF"
    echo "Alle WireGuard-Konfigurationen wurden entfernt."
}

remove_all() {
    if ask_confirm "Bist du sicher, dass du ALLE WireGuard-Konfigurationen entfernen möchtest? (ja/nein): "; then
        remove_all_config
        exit 0
    else
        echo "Abgebrochen."
    fi
}

##############################
# Ablaufsteuerung
##############################
if [ ! -f "$WG_CONF" ]; then
    if ask_confirm "Keine Basisinstallation gefunden. Möchtest du die Grundinstallation durchführen? (ja/nein): "; then
        basic_install
    else
        echo "Abbruch. Es wurde keine Installation vorgenommen."
        exit 1
    fi
fi

while true; do
    echo "---------------------------------------------------------"
    echo "WireGuard Management Menu:"
    echo "1. Neuen Client anlegen"
    echo "2. Bestehenden Client löschen"
    echo "3. Alle Konfigurationen entfernen"
    echo "4. Grundinstallation neu durchführen (ACHTUNG: Bestehende Konfiguration wird entfernt!)"
    echo "5. Beenden"
    read -p "Bitte wähle eine Option: " option
    case $option in
        1) add_client ;;
        2) delete_client ;;
        3) remove_all ;;
        4)
            echo "Die Grundinstallation wird neu durchgeführt. Bestehende Konfiguration wird entfernt."
            remove_all_config
            basic_install
            ;;
        5) exit 0 ;;
        *) echo "Ungültige Option." ;;
    esac
done
