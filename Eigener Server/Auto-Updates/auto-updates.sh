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

echo "----------------------------------------"

# Funktion zur Ermittlung des aktuellen Auto-Update-Status
get_auto_update_status() {
    local status="aus"
    if [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
        if grep -q 'APT::Periodic::Unattended-Upgrade "1"' /etc/apt/apt.conf.d/20auto-upgrades; then
            if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
                # Wenn in der Konfiguration für 50unattended-upgrades Zeilen für Updates, Proposed oder Backports
                # vorhanden sind, die nicht auskommentiert sind, dann "aktiv", ansonsten "nur Sicherheitspatches"
                if grep -q '^[[:space:]]*"\${distro_id}:\${distro_codename}-updates";' /etc/apt/apt.conf.d/50unattended-upgrades || \
                   grep -q '^[[:space:]]*"\${distro_id}:\${distro_codename}-proposed";' /etc/apt/apt.conf.d/50unattended-upgrades || \
                   grep -q '^[[:space:]]*"\${distro_id}:\${distro_codename}-backports";' /etc/apt/apt.conf.d/50unattended-upgrades; then
                    status="aktiv"
                else
                    status="nur Sicherheitspatches"
                fi
            fi
        fi
    fi
    echo "$status"
}

# Funktion zur Ermittlung des aktuellen Auto-Reboot-Status
get_auto_reboot_status() {
    local status="nicht konfiguriert"
    if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
        local reboot=$(grep 'Unattended-Upgrade::Automatic-Reboot' /etc/apt/apt.conf.d/50unattended-upgrades | grep -o '"[a-z]*"')
        reboot=${reboot//\"/}
        if [ -n "$reboot" ]; then
            status=$reboot
        fi
    fi
    echo "$status"
}

current_status=$(get_auto_update_status)
auto_reboot_status=$(get_auto_reboot_status)
echo "Auto Updates: $current_status"
echo "Auto-Reboot: $auto_reboot_status"
echo "----------------------------------------"
echo ""

# Überprüfen, ob Root-Rechte vorliegen
if [ "$EUID" -ne 0 ]; then
  echo "Bitte als root ausführen (z.B. mit sudo)."
  exit 1
fi

echo "Bitte wählen Sie eine Option:"
echo "1) Aktivieren (Alle Updates)"
echo "2) Aktivieren (Nur Sicherheitsupdates)"
echo "3) Deaktivieren"
echo "4) Auto-Reboot ändern (aktuell: $auto_reboot_status)"
echo ""
read -p "Auswahl (1-4): " option

case $option in
  1)
    echo "Aktivierung aller automatischen Updates..."
    apt update
    apt install -y unattended-upgrades

    # Periodische Konfiguration für automatische Updates
    cat <<'EOF' > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

    # Backup der Originalkonfiguration, falls vorhanden
    if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
      cp /etc/apt/apt.conf.d/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades.bak
      echo "Backup der Datei /etc/apt/apt.conf.d/50unattended-upgrades erstellt."
    fi

    # Konfiguration: Alle Update-Quellen aktivieren
    cat <<'EOF' > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
    "${distro_id}:${distro_codename}-proposed";
    "${distro_id}:${distro_codename}-backports";
};

Unattended-Upgrade::Mail "";
Unattended-Upgrade::Automatic-Reboot "true";
EOF

    systemctl enable unattended-upgrades
    systemctl start unattended-upgrades
    echo "Automatische Updates (alle Updates) wurden aktiviert."
    ;;
    
  2)
    echo "Aktivierung automatischer Sicherheitsupdates..."
    apt update
    apt install -y unattended-upgrades

    # Periodische Konfiguration für automatische Updates
    cat <<'EOF' > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

    # Backup der Originalkonfiguration, falls vorhanden
    if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
      cp /etc/apt/apt.conf.d/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades.bak
      echo "Backup der Datei /etc/apt/apt.conf.d/50unattended-upgrades erstellt."
    fi

    # Konfiguration: Nur Sicherheitsupdates aktivieren
    cat <<'EOF' > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    // "${distro_id}:${distro_codename}-updates";
    // "${distro_id}:${distro_codename}-proposed";
    // "${distro_id}:${distro_codename}-backports";
};

Unattended-Upgrade::Mail "";
Unattended-Upgrade::Automatic-Reboot "true";
EOF

    systemctl enable unattended-upgrades
    systemctl start unattended-upgrades
    echo "Automatische Sicherheitsupdates wurden aktiviert."
    ;;
    
  3)
    echo "Deaktivierung automatischer Updates..."
    # Periodische Konfiguration auf deaktiviert setzen
    cat <<'EOF' > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";
APT::Periodic::Unattended-Upgrade "0";
EOF

    systemctl disable unattended-upgrades
    systemctl stop unattended-upgrades
    echo "Automatische Updates wurden deaktiviert."
    ;;
    
  4)
    echo "Umschalten des Auto-Reboot-Parameters..."
    if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
      # Aktuellen Auto-Reboot-Wert ermitteln
      current_reboot=$(grep 'Unattended-Upgrade::Automatic-Reboot' /etc/apt/apt.conf.d/50unattended-upgrades | grep -o '"[a-z]*"')
      current_reboot=${current_reboot//\"/}
      if [ "$current_reboot" = "true" ]; then
        new_reboot="false"
      else
        new_reboot="true"
      fi
      # Zeile in der Konfiguration anpassen
      sed -i "s/^\(Unattended-Upgrade::Automatic-Reboot \)\"[a-z]*\";/\1\"$new_reboot\";/" /etc/apt/apt.conf.d/50unattended-upgrades
      echo "Auto-Reboot wurde auf $new_reboot gesetzt."
    else
      echo "Die Datei /etc/apt/apt.conf.d/50unattended-upgrades wurde nicht gefunden."
      echo "Bitte aktivieren Sie zunächst automatische Updates."
    fi
    ;;
    
  *)
    echo "Ungültige Auswahl. Bitte führen Sie das Skript erneut aus und wählen Sie eine gültige Option (1-4)."
    exit 1
    ;;
esac
