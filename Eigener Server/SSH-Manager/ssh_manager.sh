#!/bin/bash
clear

# Logo/Banner anzeigen
if [ -f logo ]; then
    cat logo
else
    echo "-------------------------------------------------------------"
    echo " ACHTUNG: Dieses Skript wird ohne jegliche Gewähr bereitgestellt."
    echo " Es wird keine Haftung für eventuelle Schäden oder Fehlkonfigurationen übernommen."
    echo "-------------------------------------------------------------"
fi
echo "----------------------------------------"

#########################################
# Hilfsfunktionen
#########################################

# Ermittelt den aktuellen Authentifizierungsmodus aus /etc/ssh/sshd_config.
# Falls keine unkommentierten Einträge vorhanden sind, gehen wir vom Default (Passwort und Pubkey) aus.
get_mode() {
    pa_line=$(grep -E '^[[:space:]]*PasswordAuthentication' /etc/ssh/sshd_config | grep -v '^[[:space:]]*#')
    pr_line=$(grep -E '^[[:space:]]*PermitRootLogin' /etc/ssh/sshd_config | grep -v '^[[:space:]]*#')
    if [ -z "$pa_line" ]; then
         PA="yes"
    else
         PA=$(echo "$pa_line" | awk '{print $2}')
    fi
    if [ -z "$pr_line" ]; then
         PR="yes"
    else
         PR=$(echo "$pr_line" | awk '{print $2}')
    fi

    # Interpretation:
    # "Nur Pubkey" wenn PasswordAuthentication no und PermitRootLogin auf prohibit-password oder no gesetzt ist.
    if [ "$PA" = "no" ] && { [ "$PR" = "prohibit-password" ] || [ "$PR" = "no" ]; }; then
         CURRENT_MODE="Nur Pubkey"
    else
         CURRENT_MODE="Passwort und Pubkey"
    fi
}

# Prüft, ob authorized_keys existiert und nicht leer ist.
authkeys_available() {
    if [ -s "$HOME/.ssh/authorized_keys" ]; then
         return 0
    else
         return 1
    fi
}

#########################################
# Hauptfunktionen
#########################################

# SSH Key-Paar generieren – mit einer einzigen Eingabeaufforderung, die sowohl den Schlüsselbezeichner
# (für Dateiname) als auch den Schlüsselkommentar liefert.
# Hier wird Ed25519 anstelle von RSA verwendet.
generate_keys() {
    # .ssh-Verzeichnis sicherstellen
    if [ ! -d "$HOME/.ssh" ]; then
         mkdir -p "$HOME/.ssh"
         chmod 700 "$HOME/.ssh"
    fi

    # Standard: hostname_username_id_ed25519 und Kommentar: username@hostname
    default_key_name="$(hostname)_$(whoami)_id_ed25519"
    default_comment="$(whoami)@$(hostname)"
    read -p "Geben Sie den Schlüsselbezeichner ein (wird als Dateiname und Kommentar genutzt, Standard: $default_key_name / $default_comment): " keyinput
    if [ -z "$keyinput" ]; then
         keyinput="$default_key_name"
         key_comment="$default_comment"
    else
         key_comment="$keyinput"
    fi

    # Überprüfen, ob bereits ein Schlüssel mit diesem Namen existiert.
    if [ -f "$HOME/.ssh/${keyinput}.pub" ]; then
         read -p "Ein Public Key mit dem Namen '$keyinput' existiert bereits. Neues Key-Paar generieren und bestehenden überschreiben? (y/n): " regen
         if ! [[ "$regen" =~ ^[Yy]$ ]]; then
             echo "Bestehendes Key-Paar bleibt erhalten."
             return
         fi
    fi

    echo "Generiere neues SSH Key-Paar mit Bezeichner '$keyinput'..."
    # Erzeuge das Key-Paar temporär in /tmp – Verwende Ed25519, -C setzt den Kommentar
    ssh-keygen -t ed25519 -C "$key_comment" -f /tmp/${keyinput}_tmp_id_ed25519 -N ""

    echo "---------------------"
    echo "Private Key (sensible Information!):"
    cat /tmp/${keyinput}_tmp_id_ed25519
    echo "---------------------"
    echo "Public Key:"
    cat /tmp/${keyinput}_tmp_id_ed25519.pub
    echo "---------------------"

    # Public Key ins .ssh-Verzeichnis kopieren (mit dem gewünschten Namen)
    cp /tmp/${keyinput}_tmp_id_ed25519.pub "$HOME/.ssh/${keyinput}.pub"

    # Abfrage: Soll der neu generierte Public Key in authorized_keys eingetragen werden?
    read -p "Soll der neu generierte Public Key in authorized_keys eingetragen werden? (y/n): " add_to_auth
    if [[ "$add_to_auth" =~ ^[Yy]$ ]]; then
         if [ ! -f "$HOME/.ssh/authorized_keys" ]; then
              touch "$HOME/.ssh/authorized_keys"
              chmod 600 "$HOME/.ssh/authorized_keys"
         fi
         if grep -Fq "$(cat "$HOME/.ssh/${keyinput}.pub")" "$HOME/.ssh/authorized_keys"; then
              echo "Der Public Key ist bereits in authorized_keys enthalten."
         else
              cat "$HOME/.ssh/${keyinput}.pub" >> "$HOME/.ssh/authorized_keys"
              echo "Public Key wurde zu authorized_keys hinzugefügt."
         fi
    fi

    # Abfrage: Soll der temporäre Private Key gelöscht werden?
    read -p "Soll der temporäre Private Key gelöscht werden? (y/n): " del
    if [[ "$del" =~ ^[Yy]$ ]]; then
         rm /tmp/${keyinput}_tmp_id_ed25519
         echo "Temporärer Private Key wurde gelöscht."
    else
         mv /tmp/${keyinput}_tmp_id_ed25519 "$HOME/.ssh/${keyinput}"
         echo "Private Key wurde unter ~/.ssh/${keyinput} gespeichert."
    fi
    rm /tmp/${keyinput}_tmp_id_ed25519.pub
}

# Authentifizierungsmodus auf "Passwort und Pubkey" setzen:
# PasswordAuthentication wird auf yes und PermitRootLogin auf yes gesetzt.
set_mode_password_pubkey() {
    echo "Setze Authentifizierungsmodus: Passwort und Pubkey..."
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    sudo sed -i -E 's/^[[:space:]]*#?[[:space:]]*PasswordAuthentication[[:space:]]+.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sudo sed -i -E 's/^[[:space:]]*#?[[:space:]]*PermitRootLogin[[:space:]]+.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sudo systemctl restart ssh
    echo "Modus 'Passwort und Pubkey' wurde gesetzt."
}

# Authentifizierungsmodus auf "Nur Pubkey" setzen:
# PasswordAuthentication wird auf no und PermitRootLogin auf prohibit-password gesetzt.
set_mode_pubkey_only() {
    echo "Setze Authentifizierungsmodus: Nur Pubkey..."
    if [ ! -f "$HOME/.ssh/id_ed25519.pub" ] && [ ! -f "$HOME/.ssh/id_ed25519" ]; then
         echo "Kein Public Key gefunden. Bitte erst ein SSH Key-Paar generieren."
         return
    fi
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    sudo sed -i -E 's/^[[:space:]]*#?[[:space:]]*PasswordAuthentication[[:space:]]+.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i -E 's/^[[:space:]]*#?[[:space:]]*PermitRootLogin[[:space:]]+.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    sudo systemctl restart ssh
    echo "Modus 'Nur Pubkey' wurde gesetzt."
}

# Public Key manuell zu authorized_keys hinzufügen.
add_pubkey() {
    echo "Bitte geben Sie den öffentlichen Schlüssel ein (mit Strg+D abschließen):"
    newkey=$(cat)
    if [ -z "$newkey" ]; then
         echo "Kein Schlüssel eingegeben."
         return
    fi
    if [ ! -d "$HOME/.ssh" ]; then
         mkdir -p "$HOME/.ssh"
         chmod 700 "$HOME/.ssh"
    fi
    if [ ! -f "$HOME/.ssh/authorized_keys" ]; then
         touch "$HOME/.ssh/authorized_keys"
         chmod 600 "$HOME/.ssh/authorized_keys"
    fi
    if grep -Fq "$newkey" "$HOME/.ssh/authorized_keys"; then
         echo "Dieser Schlüssel ist bereits vorhanden."
         return
    fi
    echo "$newkey" >> "$HOME/.ssh/authorized_keys"
    echo "Schlüssel wurde hinzugefügt."
}

# Public Key aus authorized_keys entfernen.
remove_pubkey() {
    if ! authkeys_available; then
         echo "Keine Public Keys in authorized_keys vorhanden."
         return
    fi
    echo "Aktuelle Public Keys in authorized_keys:"
    nl -w2 -s') ' "$HOME/.ssh/authorized_keys"
    read -p "Geben Sie die Nummer des zu entfernenden Schlüssels ein: " keynum
    if ! [[ "$keynum" =~ ^[0-9]+$ ]]; then
         echo "Ungültige Eingabe."
         return
    fi
    total=$(wc -l < "$HOME/.ssh/authorized_keys")
    if [ "$keynum" -lt 1 ] || [ "$keynum" -gt "$total" ]; then
         echo "Ungültige Schlüsselnummer."
         return
    fi
    sed -i "${keynum}d" "$HOME/.ssh/authorized_keys"
    echo "Schlüssel entfernt."
    if ! authkeys_available; then
         echo "WARNUNG: authorized_keys ist nun leer – Public-Key-Authentifizierung könnte zu Problemen führen."
    fi
}

# Konsolenfreundliches Passwort generieren und als Root-Passwort setzen.
generate_password() {
    read -p "Bitte gib die gewünschte Passwortlänge ein (mindestens 12): " pw_length
    if [ "$pw_length" -lt 12 ]; then
         echo "Die Länge muss mindestens 12 Zeichen betragen."
         return
    fi
    charset='A-Za-z0-9!@#$%&*?'
    password=$(tr -dc "$charset" </dev/urandom | head -c "$pw_length")
    echo "Generiertes Passwort: $password"
    echo "Setze das generierte Passwort als Root-Passwort..."
    echo "root:$password" | sudo chpasswd
    echo "Root-Passwort wurde geändert."
}

#########################################
# Hauptmenü
#########################################

while true; do
    get_mode
    echo ""
    echo "-------------------------------------------------------------"
    echo " ACHTUNG: Dieses Skript wird ohne jegliche Gewähr bereitgestellt."
    echo " Es wird keine Haftung für eventuelle Schäden oder Fehlkonfigurationen übernommen."
    echo "-------------------------------------------------------------"
    echo "----------------------------------------"
    echo "Aktueller Authentifizierungsmodus: $CURRENT_MODE"
    echo ""
    echo "1) SSH Key-Paar generieren"
    echo "2) Authentifizierungsmodus ändern"
    echo "3) Public Key zu authorized_keys hinzufügen"
    if authkeys_available; then
         echo "4) Public Key aus authorized_keys entfernen"
    else
         echo "4) "  # Leere Zeile, Option nicht verfügbar
    fi
    echo "5) Konsolenfreundliches Passwort generieren und als Root-Passwort setzen"
    echo "6) Beenden"
    echo -n "Auswahl: "
    read selection

    case "$selection" in
        1) generate_keys ;;
        2)
            echo ""
            echo "Aktueller Modus: $CURRENT_MODE"
            if [ "$CURRENT_MODE" = "Passwort und Pubkey" ]; then
                 echo "Wechseloption: Auf Nur Pubkey umstellen (PasswordAuthentication no, PermitRootLogin prohibit-password)"
                 read -p "Wechseln? (y/n): " ans
                 if [[ "$ans" =~ ^[Yy]$ ]]; then
                      set_mode_pubkey_only
                 else
                      echo "Keine Änderung vorgenommen."
                 fi
            else
                 echo "Wechseloption: Auf Passwort und Pubkey umstellen (PasswordAuthentication yes, PermitRootLogin yes)"
                 read -p "Wechseln? (y/n): " ans
                 if [[ "$ans" =~ ^[Yy]$ ]]; then
                      set_mode_password_pubkey
                 else
                      echo "Keine Änderung vorgenommen."
                 fi
            fi
            ;;
        3) add_pubkey ;;
        4)
            if authkeys_available; then
                 remove_pubkey
            else
                 echo "Option nicht verfügbar – authorized_keys ist leer."
            fi
            ;;
        5) generate_password ;;
        6) echo "Programm wird beendet."; exit 0 ;;
        *) echo "Ungültige Auswahl. Bitte erneut versuchen." ;;
    esac
done
