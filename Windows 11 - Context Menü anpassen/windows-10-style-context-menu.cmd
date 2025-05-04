@echo off
:: Schritt 1: Prüfen ob Adminrechte vorhanden
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Starte mit Administratorrechten...
    powershell -Command "Start-Process '%~f0' -Verb runAs"
    exit /b
)
echo [INFO] Restore Windows 10 Style Context Menu...

:: Schritt 2: Registry-Schlüssel aktivieren
echo [INFO] Aktiviere Registry-Schluessel...
reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve

:: Schritt 3: Explorer neu starten
echo [INFO] Starte den Windows Explorer neu...
taskkill /f /im explorer.exe
timeout /t 2 >nul
start explorer.exe

echo [FERTIG] Der Vorgang wurde abgeschlossen.
pause