#!/bin/bash

# Setup Interceptor mit offenem/gesichertem AP, mitmproxy und Benutzerabfragen
# Basierend auf: https://raw.githubusercontent.com/it-and-der-bar/YouTube/refs/heads/main/interceptor/setup-interceptor.sh

# Check if script is run as root
if [ "$EUID" -ne 0 ]
  then echo "Bitte als root ausführen (sudo -i)"
  exit
fi

# ----- Funktionen -----
valid_ipv4() {
  local ip=$1
  if [[ ! $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    return 1
  fi
  IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
  for o in $o1 $o2 $o3 $o4; do
    if (( o < 0 || o > 255 )); then
      return 1
    fi
  done
  return 0
}

valid_country_code() {
  local cc=$1
  if [[ $cc =~ ^[A-Za-z]{2}$ ]]; then
    return 0
  else
    return 1
  fi
}

prompt_with_default() {
  local prompt_text=$1
  local default=$2
  local ret
  read -r -p "$prompt_text [$default]: " ret
  if [[ -z "$ret" ]]; then
    ret=$default
  fi
  printf '%s' "$ret"
}

# ----- User-Abfragen -----

# --- 1) SSID ---
while true; do
  AP_SSID=$(prompt_with_default "SSID für den Access Point" "AP_SSID")
  if [[ -n "${AP_SSID// /}" ]]; then
    break
  else
    echo "SSID darf nicht leer sein. Bitte erneut eingeben."
  fi
done
# read -p "SSID für den Access Point [AP_SSID]: " AP_SSID
# AP_SSID=${AP_SSID:-AP_SSID}

# --- 2) AP IP (als Basis für Netzwerkteil) ---
while true; do
  AP_IP=$(prompt_with_default "IP-Adresse für den AP (z.B. 192.168.4.1)" "192.168.4.1")
  if valid_ipv4 "$AP_IP"; then
    break
  else
    echo "Ungültige IPv4-Adresse: $AP_IP. Bitte im Format x.x.x.x (0-255) eingeben."
  fi
done

# Netzwerkteil aus AP-IP extrahieren (erste drei Oktette)
NET_PREFIX="${AP_IP%.*}"        # z.B. "192.168.4"
NET_PREFIX_DOTTED="${NET_PREFIX}."  # "192.168.4."

# read -p "IP-Adresse für den AP (z.B. 192.168.4.1): " AP_IP
# AP_IP=${AP_IP:-192.168.4.1}


# --- 3) DHCP Range: nur letzte Oktette abfragen ---
while true; do
  read -r -p "Anfangs-Host für DHCP (nur letzte Oktette, z.B. 2) [2]: " DHCP_START
  DHCP_START=${DHCP_START:-2}
  if ! [[ $DHCP_START =~ ^[0-9]+$ ]]; then
    echo "Bitte eine Zahl eingeben."
    continue
  fi
  if (( DHCP_START < 1 || DHCP_START > 254 )); then
    echo "Host muss zwischen 1 und 254 liegen."
    continue
  fi

  read -r -p "End-Host für DHCP (nur letzte Oktette, z.B. 100) [100]: " DHCP_END
  DHCP_END=${DHCP_END:-100}
  if ! [[ $DHCP_END =~ ^[0-9]+$ ]]; then
    echo "Bitte eine Zahl eingeben."
    continue
  fi
  if (( DHCP_END < 1 || DHCP_END > 254 )); then
    echo "Host muss zwischen 1 und 254 liegen."
    continue
  fi

  if (( DHCP_START > DHCP_END )); then
    echo "Start-Host darf nicht größer als End-Host sein."
    continue
  fi

  # prüfen, ob AP-IP innerhalb der Range liegt
  AP_HOST=${AP_IP##*.}
  conflict=false
  if (( DHCP_START <= AP_HOST && AP_HOST <= DHCP_END )); then
    echo "Warnung: AP-IP ($AP_IP) liegt in der gewählten DHCP-Range."
    conflict=true
  fi

  if $conflict; then
    echo "Bitte wähle eine Range, die den AP nicht einschließt, oder bestätige."
    read -r -p "Trotzdem verwenden? (j/N) " yn
    yn=${yn:-N}
    if [[ $yn =~ ^[jJ] ]]; then
      break
    else
      echo "Range neu eingeben."
      continue
    fi
  else
    break
  fi
done

# DHCP_RANGE zusammensetzen
DHCP_RANGE="${NET_PREFIX_DOTTED}${DHCP_START},${NET_PREFIX_DOTTED}${DHCP_END}"
# read -p "IP-Range für DHCP (z.B. 192.168.4.2,192.168.4.20,192.168.4.2,192.168.4.100): " DHCP_RANGE
# DHCP_RANGE=${DHCP_RANGE:-192.168.4.2,192.168.4.100}

# --- 4) Country code ---
while true; do
  COUNTRY_CODE=$(prompt_with_default "Ländercode für WLAN (z.B. DE für Deutschland)" "DE")
  if valid_country_code "$COUNTRY_CODE"; then
    COUNTRY_CODE=$(echo "$COUNTRY_CODE" | tr '[:lower:]' '[:upper:]')
    break
  else
    echo "Ungültiger Ländercode. Bitte genau 2 Buchstaben eingeben (z.B. DE)."
  fi
done
# read -p "Ländercode für WLAN (z.B. DE für Deutschland) [DE]: " COUNTRY_CODE
# COUNTRY_CODE=${COUNTRY_CODE:-DE}

# --- 5) Passwort ---
read -p "Möchten Sie ein Passwort für den Access Point setzen? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    read -p "WLAN-Passwort (min. 8 Zeichen): " AP_PASS
    while [ -z "$AP_PASS" ] || [ ${#AP_PASS} -lt 8 ]; do
        echo "Passwort muss mindestens 8 Zeichen haben!"
        read -p "WLAN-Passwort: " AP_PASS
    done
    SECURE_AP=true
else
    SECURE_AP=false
fi

# Update System (falls noch nicht geschehen)
echo "System wird aktualisiert..."
apt update
apt full-upgrade -y

# Install necessary packages
echo "Installiere benötigte Pakete..."
apt install -y hostapd dnsmasq mitmproxy python3-pip

# Python-Pakete für mitmproxy
echo "Installiere MitmProxy"
pip3 install mitmproxy

# hostapd und systemctl stoppen, um sie zu konfigurieren
systemctl stop hostapd
systemctl stop dnsmasq

# konfiguriere DHCP (dnsmasq)
echo "Konfiguriere dnsmasq..."
cat > /etc/dnsmasq.conf <<EOF
interface=wlan0
dhcp-range=${DHCP_RANGE},255.255.255.0,24h
EOF

# konfiguriere Access Point (hostapd)
echo "Konfiguriere hostapd..."
if [ "$SECURE_AP" = true ]; then
    # Mit WPA2/WPA3 Sicherheit
    cat > /etc/hostapd/hostapd.conf <<EOF
interface=wlan0
driver=nl80211
ssid=${AP_SSID}
hw_mode=g
channel=7
wmm_enabled=1
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
country_code=${COUNTRY_CODE}
ieee80211d=1
ieee80211h=1
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_passphrase=${AP_PASS}
EOF
else
    # Offener AP
    cat > /etc/hostapd/hostapd.conf <<EOF
interface=wlan0
driver=nl80211
ssid=${AP_SSID}
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
country_code=${COUNTRY_CODE}
ieee80211d=1
ieee80211h=1
EOF
fi

# konfiguriere hostapd
sed -i 's/#DAEMON_CONF=""/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/' /etc/default/hostapd

# konfiguriere network interface
echo "Konfiguriere Netzwerk..."
cat >> /etc/dhcpcd.conf <<EOF
interface wlan0
    static ip_address=${AP_IP}/24
    nohook wpa_supplicant
EOF

# IP forwarding
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
echo 1 > /proc/sys/net/ipv4/ip_forward

# konfiguriere NAT
echo "Richte NAT und Redirect ein..."
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT

# Redirect zu mitmproxy
iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 80 -j REDIRECT --to-port 8080
iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 443 -j REDIRECT --to-port 8080

sh -c "iptables-save > /etc/iptables.ipv4.nat"

# Make iptables rules persistent
cat > /etc/rc.local <<EOF
#!/bin/sh -e
#
# rc.local
#
iptables-restore < /etc/iptables.ipv4.nat
exit 0
EOF

chmod +x /etc/rc.local

# services starten
echo "Starte Dienste..."
systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq
systemctl start hostapd
systemctl start dnsmasq

# mitmproxy Zertifikat erstellen
echo "Erstelle mitmproxy Zertifikat..."
mkdir -p ~/.mitmproxy
mitmproxy --create-ca-cert

# starte mitmproxy im Hintergrund
echo "Starte mitmproxy (transparent mode)..."
mitmproxy --mode transparent --showhost --set block_global=false -p 8080 > /dev/null 2>&1 &

echo "===================================================="
echo "Setup abgeschlossen!"
if [ "$SECURE_AP" = true ]; then
    echo "Access Point ist gesichert (WPA2/WPA3)"
    echo "SSID: ${AP_SSID}"
    echo "Passwort: ${AP_PASS}"
else
    echo "Access Point ist offen (kein Passwort)"
    echo "SSID: ${AP_SSID}"
fi
echo "IP-Adresse des AP: ${AP_IP}"
echo "IP-Range für DHCP: ${DHCP_RANGE}"
echo "Ländercode: ${COUNTRY_CODE}"
echo ""
echo "mitmproxy läuft auf Port 8080 (HTTP/HTTPS)"
echo "Zertifikat für HTTPS-Interception: ~/.mitmproxy/mitmproxy-ca-cert.pem"
echo "===================================================="
