<?php
// Datei für Logs
$logfile = __DIR__ . '/client_data.txt';

// Client-IP abrufen (Real-IP oder Remote-IP)
$ip_address = $_SERVER['HTTP_X_REAL_IP'] ?? $_SERVER['REMOTE_ADDR'];
$hostname = gethostbyaddr($ip_address); // Hostname der IP
$user_agent = $_SERVER['HTTP_USER_AGENT'] ?? 'Unknown';
$referrer = $_SERVER['HTTP_REFERER'] ?? 'No Referrer';
$access_time = date('Y-m-d H:i:s');

// Serverseitige Daten loggen
$log_data = "----------------------------\n";
$log_data .= "IP-Adresse: $ip_address\n";
$log_data .= "Hostname: $hostname\n";
$log_data .= "User-Agent: $user_agent\n";
$log_data .= "Referrer: $referrer\n";
$log_data .= "Zugriffszeit: $access_time\n";

// Wenn JavaScript-Daten per POST empfangen werden
if ($_SERVER['REQUEST_METHOD'] === 'POST' && !empty($_POST['js_data'])) {
    $js_data = json_decode($_POST['js_data'], true);
    if ($js_data) {
        $log_data .= "JavaScript-Data:\n";
        foreach ($js_data as $key => $value) {
            $log_data .= ucfirst($key) . ": $value\n";
        }
    }
}

// Log-Datei schreiben
file_put_contents($logfile, $log_data, FILE_APPEND | LOCK_EX);
?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ERP Einkaufssystem - 2T Videomarketing</title>
    <style>
        body {
            font-family: 'Arial', sans-serif;
            background-color: #f0f0f0;
            margin: 0;
            padding: 0;
        }
        header {
            background-color: #0a485b;
            color: #fff;
            padding: 20px;
            text-align: center;
        }
        nav {
            text-align: center;
            background-color: #0a485b;
            padding: 10px;
        }
        nav a {
            margin: 0 15px;
            color: #ff6f6f;
            text-decoration: none;
            font-weight: bold;
        }
        .cta-button {
            background-color: #ff6f6f;
            color: #fff;
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            font-weight: bold;
            cursor: pointer;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        h1, h2 {
            color: #333;
        }
        .info-box {
            background-color: #fff;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
        }
        footer {
            background-color: #0a485b;
            color: white;
            padding: 20px;
            text-align: center;
            margin-top: 40px;
        }
    </style>
    <script>
        window.onload = function() {
            const js_data = {
                screenResolution: `${screen.width}x${screen.height}`,
                timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
                browserLanguage: navigator.language,
                platform: navigator.platform,
                userAgent: navigator.userAgent,
                cookiesEnabled: navigator.cookieEnabled ? 'Yes' : 'No',
                plugins: Array.from(navigator.plugins).map(p => p.name).join(", ")
            };

            // Daten per POST an den Server senden
            const formData = new FormData();
            formData.append('js_data', JSON.stringify(js_data));

            fetch(window.location.href, {
                method: 'POST',
                body: formData
            });
        };
    </script>
</head>
<body>
    <header>
        <h1>ERP Einkaufssystem - 2T Videomarketing</h1>
    </header>
    <nav>
        <button class="cta-button">Check-In</button>
    </nav>
    <div class="container">
        <div class="info-box">
            <h2>Lieferanteninformationen</h2>
            <p><strong>Lieferant:</strong> Foto Mundus GmbH & Co. KG</p>
            <p><strong>Adresse:</strong> Döppers Kamp 4, 48531 Nordhorn</p>
            <p><strong>Inhaber:</strong> Lutz Bergknecht</p>
        </div>
        <div class="info-box">
            <h2>Bestellinformationen</h2>
            <ul>
                <li>Canon EOS 5D Mark IV Gehäuse - 2 Stück</li>
                <li>Nikon D780 Gehäuse Schwarz - 2 Stück</li>
                <li>Canon EOS 250D Gehäuse Schwarz - 5 Stück</li>
                <li>Canon RF 18-150mm F/3.5-6.3 IS STM - 3 Stück</li>
            </ul>
            <p><strong>Gesamtbetrag:</strong> 8.380,00 €</p>
        </div>
    </div>
    <footer>
        <p>© 2024 2T Videomarketing | ERP Einkaufssystem</p>
    </footer>
</body>
</html>
