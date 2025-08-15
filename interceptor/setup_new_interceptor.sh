#!/bin/bash

# Setup Interceptor mit offenem/gesichertem AP, mitmproxy und Benutzerabfragen
# Basierend auf: https://raw.githubusercontent.com/it-and-der-bar/YouTube/refs/heads/main/interceptor/setup-interceptor.sh

# Check if script is run as root
if [ "$EUID" -ne 0 ]
  then echo "Bitte als root ausführen (sudo -i)"
  exit
fi

# User-Abfragen
read -p "SSID für den Access Point [AP_SSID]: " AP_SSID
AP_SSID=${AP_SSID:-AP_SSID}

read -p "IP-Adresse für den AP (z.B. 192.168.4.1): " AP_IP
AP_IP=${AP_IP:-192.168.4.1}

read -p "IP-Range für DHCP (z.B. 192.168.4.2,192.168.4.20,192.168.4.2,192.168.4.100): " DHCP_RANGE
DHCP_RANGE=${DHCP_RANGE:-192.168.4.2,192.168.4.100}

read -p "Ländercode für WLAN (z.B. DE für Deutschland) [DE]: " COUNTRY_CODE
COUNTRY_CODE=${COUNTRY_CODE:-DE}

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
