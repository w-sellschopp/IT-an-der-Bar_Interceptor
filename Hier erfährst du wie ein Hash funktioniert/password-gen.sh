#!/bin/bash

# Passwort Generator

# Hilfetext anzeigen
show_help() {
    echo "Passwort Generator"
    echo "=================="
    echo ""
    echo "Verwendung: $0 [OPTIONEN]"
    echo ""
    echo "Optionen:"
    echo "  -l, --length <Länge>         Länge des Passworts"
    echo "  -c, --count <Anzahl>         Anzahl der zu generierenden Passwörter"
    echo "  -t, --type <Typ>             Typ des Zeichenraums"
    echo "                                1 - Zahlen, Buchstaben und Sonderzeichen"
    echo "                                2 - Hexadezimale Zeichen (0-9, a-f)"
    echo "                                3 - Base64-Zeichen (A-Za-z0-9+/)"
    echo "  -h, --help                   Zeigt diese Hilfe an"
    echo ""
    echo "Beispiel:"
    echo "  $0 --length 12 --count 5 --type 1"
    echo ""
}

# Standardwerte für die Variablen
PASSWORD_LENGTH=""
PASSWORD_COUNT=""
CHARSET_OPTION=""

# Argumente verarbeiten
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -l|--length)
            PASSWORD_LENGTH="$2"
            shift
            ;;
        -c|--count)
            PASSWORD_COUNT="$2"
            shift
            ;;
        -t|--type)
            CHARSET_OPTION="$2"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unbekannte Option: $1"
            show_help
            exit 1
            ;;
    esac
    shift
done

# Wenn keine Parameter angegeben sind, in den interaktiven Modus wechseln
if [[ -z "$PASSWORD_LENGTH" || -z "$PASSWORD_COUNT" || -z "$CHARSET_OPTION" ]]; then
    echo "Interaktiver Modus aktiviert (keine Parameter gefunden)"
    echo ""

    read -p "Bitte geben Sie die Passwortlänge: " PASSWORD_LENGTH
    if ! [[ "$PASSWORD_LENGTH" =~ ^[0-9]+$ ]]; then
        echo "Fehler: Bitte eine gültige Zahl eingeben."
        exit 1
    fi

    read -p "Wie viele Passwörter sollen generiert werden? " PASSWORD_COUNT
    if ! [[ "$PASSWORD_COUNT" =~ ^[0-9]+$ ]]; then
        echo "Fehler: Bitte eine gültige Zahl eingeben."
        exit 1
    fi

    echo ""
    echo "Bitte wählen Sie den gewünschten Zeichenraum:"
    echo "1 - Zahlen, Buchstaben und Sonderzeichen"
    echo "2 - Hexadezimale Zeichen (0-9, a-f)"
    echo "3 - Base64-Zeichen (A-Za-z0-9+/)"
    read -p "Auswahl (1-3): " CHARSET_OPTION
fi

# Überprüfen, ob die Passwortlänge und -anzahl gültige Zahlen sind
if ! [[ "$PASSWORD_LENGTH" =~ ^[0-9]+$ ]]; then
    echo "Fehler: Passwortlänge muss eine Zahl sein."
    exit 1
fi

if ! [[ "$PASSWORD_COUNT" =~ ^[0-9]+$ ]]; then
    echo "Fehler: Passwortanzahl muss eine Zahl sein."
    exit 1
fi

# Generierung der Passwörter basierend auf der Auswahl
echo ""
for p in $(seq 1 $PASSWORD_COUNT); do
    case $CHARSET_OPTION in
        1)
            # Erweitertes Zeichenset mit Sonderzeichen
            CHARSET='A-Za-z0-9!@#$%^&*()-_=+{}[]:;,.?'
            PASSWORD=$(tr -dc "$CHARSET" < /dev/urandom | head -c $PASSWORD_LENGTH)
            ;;
        2)
            # Hexadezimale Zeichen
            PASSWORD=$(openssl rand -hex $PASSWORD_LENGTH | cut -c1-$PASSWORD_LENGTH)
            ;;
        3)
            # Base64-Zeichen
            PASSWORD=$(openssl rand -base64 48 | cut -c1-$PASSWORD_LENGTH)
            ;;
        *)
            echo "Fehler: Ungültiger Zeichensatz-Typ. Verwenden Sie 1, 2 oder 3."
            show_help
            exit 1
            ;;
    esac
    echo "Passwort $p: $PASSWORD"
done
echo ""
