# Windows 11 - Upgrade ohne Prüfung

Dieses Repository enthält Skripte und Registry-Dateien, um das Upgrade auf Windows 11 ohne die offiziellen Hardware-Prüfungen (z. B. TPM, Secure Boot, CPU-Anforderungen) durchzuführen. Diese Methode ist besonders hilfreich für ältere PCs, die von Microsoft offiziell nicht unterstützt werden.

## ⚠️ Wichtiger Hinweis
Diese Änderungen umgehen die offiziellen Systemanforderungen von Windows 11. Microsoft kann dies in zukünftigen Updates unterbinden oder die Funktionalität einschränken. Die Nutzung geschieht auf eigene Verantwortung!

---

## 📂 Inhalt des Repositories

### `inPlace_fix.cmd`
Ein Batch-Skript, das die notwendigen Registrierungseinträge direkt setzt, ohne dass der Nutzer eine `.reg`-Datei importieren muss. Es enthält im Grunde die Inhalte von `inPlace_fix.reg` und setzt folgende Werte:

- **Täuscht Windows vor**, dass Secure Boot, TPM 2.0 und 8 GB RAM vorhanden sind.
- **Erlaubt Upgrades mit nicht unterstützter Hardware (TPM/CPU)**.

#### **Anwendung:**
1. **Rechtsklick auf `inPlace_fix.cmd` → "Als Administrator ausführen"**.
2. Das Skript setzt automatisch die erforderlichen Registry-Werte.
3. **Nach der Meldung "Registrierung erfolgreich angepasst!" den PC neu starten.**
4. **Windows 11 Setup ausführen** – die Hardware-Checks sollten nun übersprungen werden.

Falls das Skript nicht funktioniert, kann alternativ eine `.reg`-Datei genutzt werden.

---

### `inPlace_fix.reg`
Diese `.reg`-Datei fügt die notwendigen Werte in die Windows-Registrierung hinzu, um die Hardware-Anforderungen von Windows 11 zu umgehen.

#### **Anwendung:**
1. **Doppelklick auf `inPlace_fix.reg`**.
2. Sicherheitswarnung bestätigen.
3. PC neu starten.
4. Windows 11-Upgrade ausführen.

---

### `inPlace_fix_alternate.reg`
Eine erweiterte Version von `inPlace_fix.reg`, die zusätzlich die LabConfig-Schlüssel setzt, um noch mehr Hardware-Prüfungen zu umgehen.

**Zusätzliche Umgehungen:**
- TPM-Überprüfung
- Secure Boot-Prüfung
- RAM-Prüfung
- CPU-Prüfung
- Speicherprüfung
- Festplattenprüfung

#### **Anwendung:**
1. **Doppelklick auf `inPlace_fix_alternate.reg`**.
2. Sicherheitswarnung bestätigen.
3. Neustart durchführen.
4. Windows 11-Upgrade ausführen.

---

## 💡 Welche Methode sollte ich nutzen?
- Falls das Standard-Upgrade fehlschlägt, zuerst `inPlace_fix.cmd` oder `inPlace_fix.reg` ausprobieren.
- Falls weiterhin Probleme auftreten, `inPlace_fix_alternate.reg` nutzen.

---

## ℹ️ Weitere Informationen
- [Offizieller Microsoft Windows 11 ISO Link](https://www.microsoft.com/de-de/software-download/windows11)

---

## 📜 Lizenz
Dieses Repository steht unter der MIT-Lizenz. Die Nutzung erfolgt auf eigene Gefahr.

---

**Autor**: [it-and-der-bar](https://github.com/it-and-der-bar)  
🔗 [YouTube-Kanal](https://www.youtube.com/@ITanderBar)
