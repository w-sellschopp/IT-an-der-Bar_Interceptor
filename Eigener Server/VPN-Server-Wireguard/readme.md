# WireGuard Verwaltungs-Skript

## Übersicht  
Dieses Skript bietet eine umfassende Lösung zur Verwaltung einer WireGuard-Installation auf Ubuntu. Es führt eine Basisinstallation durch – inklusive der Generierung von Server-Schlüsseln, der Konfiguration der Netzwerkeinstellungen (Adressbereich, Port, DNS, externe IP) und der Einrichtung der grundlegenden Server-Konfiguration. Anschließend gelangst du in ein interaktives Verwaltungsmenü, in dem du Clients hinzufügen, entfernen oder die gesamte Konfiguration neu aufsetzen kannst. Alle Verbindungen werden zusätzlich mit einem Pre-Shared Key (PSK) abgesichert.

## Funktionen  
- **Grundinstallation**  
  - Installiert die benötigten Pakete (`wireguard`, `wireguard-tools`, `ipcalc`).  
  - Aktiviert IP-Forwarding.  
  - Konfiguriert den Adressbereich (Standard: `10.0.0.0/24`; anpassbar).  
  - Wählt einen Listen-Port (Standard: zufällig zwischen 30000 und 50000, anpassbar).  
  - Konfiguriert den DNS-Server (Standard: `1.1.1.1`; anpassbar).  
  - Bestimmt die externe IP oder nutzt eine angegebene DNS-Adresse.  
  - Erstellt Server-Schlüssel und richtet die Server-Konfiguration ein.

- **Verwaltungsmenü**  
  - **Neuen Client hinzufügen:** Generiert Client-Schlüssel, weist eine freie IP aus dem konfigurierten Bereich zu und erstellt eine Client-Konfiguration mit PSK-Schutz und QR-Code.  
  - **Bestehenden Client löschen:** Entfernt einen Client und seinen zugehörigen Eintrag aus der Server-Konfiguration.  
  - **Alle Konfigurationen entfernen:** Löscht die gesamte WireGuard-Konfiguration.  
  - **Grundinstallation erneut durchführen:** Startet die Basisinstallation neu (bestehende Konfiguration wird entfernt).  
  - **Beenden:** Beendet das Skript.

- **ASCII-Art Banner**  
  Beim Start zeigt das Skript ein kleines Banner (ca. 1/3 der ASCII-Art aus einer Datei), um dem Skript ein individuelles Erscheinungsbild zu verleihen.

## Voraussetzungen  
- Ubuntu oder ein kompatibles Linux-System  
- Bash-Shell  
- Root-Rechte (`sudo`)  
- Internetverbindung (für Paketinstallationen und externe IP-Ermittlung)

## Installation  
1. Lade das Skript (`wg-full.sh`) herunter und speichere es an einem gewünschten Ort.  
2. Mache das Skript ausführbar:  
   ```bash
   chmod +x wg-full.sh
   ```

## Nutzung  
Führe das Skript als Root-Benutzer aus:  
   ```bash
   sudo ./wg-full.sh
   ```

### Grundinstallation  
Falls keine WireGuard-Basiskonfiguration gefunden wird, fragt das Skript, ob du die Grundinstallation durchführen möchtest. Während der Installation kannst du folgende Parameter anpassen:

- **Adressbereich:**  
  Standard ist `10.0.0.0/24`. Du kannst aber auch einen anderen CIDR-Bereich eingeben.  
- **Listen-Port:**  
  Standard ist ein zufälliger Port zwischen 30000 und 50000, falls nichts eingegeben wird.  
- **DNS-Server:**  
  Standard ist `1.1.1.1`.  
- **Externe IP/DNS:**  
  Falls du hinter einem Router sitzt, kannst du hier deine externe IP oder einen DNS-Namen angeben. Falls nichts eingegeben wird, ermittelt das Skript die öffentliche IP automatisch.

### Verwaltungsmenü  
Nach einer erfolgreichen Grundinstallation gelangst du in ein interaktives Verwaltungsmenü mit folgenden Optionen:

1. **Neuen Client hinzufügen:** Erstellt einen Client-Schlüssel, weist eine freie IP zu und generiert eine Client-Konfigurationsdatei (inklusive PSK und QR-Code).  
2. **Bestehenden Client löschen:** Entfernt einen Client aus der Konfiguration.  
3. **Alle Konfigurationen entfernen:** Löscht die gesamte WireGuard-Konfiguration.  
4. **Grundinstallation erneut durchführen:** Führt die Basisinstallation erneut aus (bestehende Konfiguration wird entfernt).  
5. **Beenden:** Beendet das Skript.

Client-Konfigurationen werden unter `/etc/wireguard/clients/` gespeichert und können in deine WireGuard-Clients importiert werden.

## Haftungsausschluss  
Dieses Skript wird ohne jegliche Garantie bereitgestellt. Der Autor übernimmt keine Verantwortung für Schäden oder Fehlkonfigurationen. Die Nutzung erfolgt auf eigenes Risiko.
