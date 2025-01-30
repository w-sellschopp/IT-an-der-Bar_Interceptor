@echo off
echo Windows 11 Upgrade Bypass wird angewendet...
echo Erfordert Administratorrechte!

:: Prüfen, ob das Skript als Administrator ausgeführt wird
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Bitte das Skript als Administrator ausführen!
    pause
    exit /b
)

:: Registrierungseintrag für AppCompatFlags\HwReqChk
reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\HwReqChk" /f /v HwReqChkVars /t REG_MULTI_SZ /s , /d "SQ_SecureBootCapable=TRUE,SQ_SecureBootEnabled=TRUE,SQ_TpmVersion=2,SQ_RamMB=8192,"

:: Registrierungseintrag für MoSetup - Erlaubt Upgrade mit nicht unterstützten CPUs/TPM
reg.exe add "HKLM\SYSTEM\Setup\MoSetup" /f /v AllowUpgradesWithUnsupportedTPMOrCPU /t REG_DWORD /d 1

echo Registrierung erfolgreich angepasst!
echo Bitte starte deinen PC neu, bevor du das Windows 11 Setup startest.
pause
exit
