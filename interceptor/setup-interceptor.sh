#!/bin/bash

set -e

# Ask user for configuration
read -p "SSID für WLAN (default: InterceptorAP): " SSID
SSID=${SSID:-InterceptorAP}

read -p "Passwort für WLAN (min. 8 Zeichen, default: geheim123): " WLAN_PASS
WLAN_PASS=${WLAN_PASS:-geheim123}

read -p "WLAN-Land (2 Buchstaben, z.B. DE): " WLAN_COUNTRY
WLAN_COUNTRY=${WLAN_COUNTRY:-DE}

read -p "Netzwerkbasis für WLAN-Clients (nur /24, z.B. 10.3.7.0): " WLAN_BASE
WLAN_BASE=${WLAN_BASE:-10.3.7.0}

# Validate /24 network input
if [[ ! $WLAN_BASE =~ ^([0-9]{1,3}\.){3}0$ ]]; then
  echo "Ungültiger Netzwerkbereich. Bitte im Format z.B. 10.3.7.0 angeben (nur /24 erlaubt)."
  exit 1
fi

WLAN_NET="$WLAN_BASE/24"

# Derived values
WLAN_IFACE=wlan0
ETH_IFACE=eth0
WLAN_IP=${WLAN_BASE%0}1
DHCP_RANGE_START=${WLAN_BASE%0}100
DHCP_RANGE_END=${WLAN_BASE%0}200

# Unblock WLAN if soft blocked and make it persistent
rfkill unblock wifi || true
# Make persistent via systemd service
cat > /etc/systemd/system/unblock-wifi.service <<EOF
[Unit]
Description=Unblock WiFi on boot
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/rfkill unblock wifi

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable unblock-wifi.service

# Update + install packages
apt update
apt install -y hostapd dnsmasq iptables-persistent python3-pip libffi-dev libssl-dev netfilter-persistent dhcpcd5
pip3 install --break-system-packages --upgrade mitmproxy

# Unmask hostapd if needed
systemctl unmask hostapd

# Wait for unblock-wifi service before starting hostapd
mkdir -p /etc/systemd/system/hostapd.service.d
cat > /etc/systemd/system/hostapd.service.d/wait-for-unblock.conf <<EOF
[Unit]
After=unblock-wifi.service
Requires=unblock-wifi.service
EOF

systemctl daemon-reexec

# Stop services to configure
systemctl stop hostapd || true
systemctl stop dnsmasq || true

# Configure dhcpcd for wlan0 with static IP
cat > /etc/dhcpcd.conf <<EOF
interface $WLAN_IFACE
static ip_address=$WLAN_IP/24
nohook wpa_supplicant
EOF

systemctl enable dhcpcd
systemctl restart dhcpcd


# Configure dnsmasq
cat > /etc/dnsmasq.conf <<EOF
interface=$WLAN_IFACE
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,255.255.255.0,24h
EOF

# Configure hostapd
cat > /etc/hostapd/hostapd.conf <<EOF
interface=$WLAN_IFACE
driver=nl80211
ssid=$SSID
hw_mode=g
channel=7
wmm_enabled=0
auth_algs=1
wpa=2
wpa_passphrase=$WLAN_PASS
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
country_code=$WLAN_COUNTRY
EOF

echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > /etc/default/hostapd

# Enable IP forwarding
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p

# Set iptables rules
iptables -t nat -A POSTROUTING -o $ETH_IFACE -j MASQUERADE
iptables -t nat -A PREROUTING -i $WLAN_IFACE -p tcp --dport 80 -j REDIRECT --to-port 8080
iptables -t nat -A PREROUTING -i $WLAN_IFACE -p tcp --dport 443 -j REDIRECT --to-port 8080
netfilter-persistent save

# Set default DNS
echo "nameserver 9.9.9.9" > /etc/resolv.conf

# Enable and start services
systemctl enable hostapd
systemctl enable dnsmasq
systemctl start hostapd
systemctl start dnsmasq

# Create mitmproxy user
useradd --system --no-create-home --group nogroup mitm || true
mkdir -p /var/lib/mitmproxy
chown -R mitm:nogroup /var/lib/mitmproxy

# Setup mitmweb systemd service
cat > /etc/systemd/system/mitmweb.service <<EOF
[Unit]
Description=Transparent MITMWeb Proxy
After=network.target

[Service]
ExecStart=/usr/local/bin/mitmweb \
  --mode transparent \
  --showhost \
  --web-port 8081 \
  --listen-host 0.0.0.0 --web-host 0.0.0.0 \
    --ssl-insecure \
  --set confdir=/var/lib/mitmproxy
User=mitm
Group=nogroup
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable mitmweb.service
systemctl start mitmweb.service

# Final message
echo "WLAN-SSID: $SSID | Netzwerk: $WLAN_NET"
echo "mitmweb erreichbar unter: http://$(ip -4 addr show $ETH_IFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}'):8081"
