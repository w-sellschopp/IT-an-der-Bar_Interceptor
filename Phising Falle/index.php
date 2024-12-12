<?php
    // Datei, in die die Daten gespeichert werden
    $logfile = '/var/www/html/client_data.txt';

    // IP-Adresse des Clients
    $ip_address = $_SERVER['HTTP_X_REAL_IP'];

    // Weitere Client-Daten
    $user_agent = $_SERVER['HTTP_USER_AGENT'];
    $access_time = date('Y-m-d H:i:s');

    // Daten in die Datei schreiben
    $log_data = "IP-Adresse: $ip_address\n";
    $log_data .= "Requested HOST: {$_SERVER['HTTP_HOST']}\n";
    $log_data .= "Requested URI: {$_SERVER['REQUEST_URI']}\n";

    $log_data .= "User-Agent: $user_agent\n";
    $log_data .= "Zugriffszeit: $access_time\n";


if (isset($_GET['id']) && preg_match('/^[a-f0-9]{32}$/', $_GET['id'])) {
    $log_data .= "Hash: {$_GET['id']}\n";
}else{
    $log_data .= "no hash provided!\n";
    $log_data .= "----------------------------\n";

    file_put_contents($logfile, $log_data, FILE_APPEND | LOCK_EX);
	die("2T-Videomarketing ERP - exception - please provide your order id");
}


$client_ip = $_SERVER['HTTP_X_REAL_IP'];

// URL der IP-API, um die Geolocation zu ermitteln
$api_url = "http://ip-api.com/php/{$client_ip}";

// Daten von der API abrufen
$response = @file_get_contents($api_url);
if ($response === FALSE) {
    // Falls die API nicht erreichbar ist, blockiere den Zugriff vorsichtshalber
    header('HTTP/1.0 403 Forbidden');
    echo 'Access denied. Could not determine your location.';
        $log_data .= "Access denied. This site is only available in the EU without VPN.\n";
        $log_data .= "----------------------------\n";
        file_put_contents($logfile, $log_data, FILE_APPEND | LOCK_EX);

    exit();
}

// Unserialisiere die Antwort (IP-API gibt die Antwort im PHP-Array-Format zurück)
$data = @unserialize($response);

// Überprüfe, ob die Anfrage erfolgreich war
if ($data && $data['status'] == 'success') {
    $country_code = $data['countryCode'];  // Ländercode der IP-Adresse (ISO-3166 Alpha-2)

   $log_data .= "Country: $country_code\n";     

    // Liste der EU-Länder nach ISO-3166 Alpha-2 Code
    $eu_countries = [
        'AT', 'BE', 'BG', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', 'GR',
        'HR', 'HU', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PL', 'PT', 'RO',
        'SE', 'SI', 'SK'
    ];

    // Überprüfe, ob der Client aus der EU kommt
    if (!in_array($country_code, $eu_countries)) {
        // Wenn der Traffic nicht aus der EU kommt, blockiere den Zugriff
        header('HTTP/1.0 403 Forbidden');
        echo 'Access denied. This site is only available in the EU without VPN.';
	$log_data .= "Access denied. This site is only available in the EU without VPN.\n";
        $log_data .= "----------------------------\n";
        file_put_contents($logfile, $log_data, FILE_APPEND | LOCK_EX);

        exit();
    } else {
        // Besucher kommt aus der EU
    }
} else {
    // Falls keine gültigen GeoIP-Daten verfügbar sind, blockiere den Zugriff vorsichtshalber
    header('HTTP/1.0 403 Forbidden');
   $log_data .= "unknown country\n";	 
   $log_data .= "----------------------------\n";

    echo 'Access denied. Could not determine your location. Our service is only available without VPNs and only within the EU';
    exit();
}

if (isset($_REQUEST['checkin'])){
	$rnd_nr = random_int(101, 9999);
	$log_data .= "Check-In clicked: FM-2T-2024-$rnd_nr\n";
	$order_id = "FM-2T-2024-$rnd_nr <br/><b>Bitte auf Ihrem Lieferschein und Rechnung als Kundenbestellnummer angeben.</b>";
}
else{
	$log_data .="Check-In not performed yet\n";
	$order_id = "<font style=\"color:red;font-weight:bold\">Bitte Check-In Button bestätigen</font>";
}
   $log_data .= "----------------------------\n";
   file_put_contents($logfile, $log_data, FILE_APPEND | LOCK_EX);


?>

<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ERP Einkauf - 2T-Videomarketing</title>
    <style>
        body {
            font-family: 'Arial', sans-serif;
            background-color: #f0f0f0;
            margin: 0;
            padding: 0;
        }
        header {
            background-color: #0a485b; /* Dunkles Blau */
            color: #fff;
            padding: 20px;
            text-align: center;
        }
        header img {
            max-width: 150px;
        }
        nav {
            text-align: center;
            background-color: #0a485b; /* Dunkles Blau */
            padding: 10px;
        }
        nav a {
            margin: 0 15px;
            color: #ff6f6f; /* Helles Korallenrot */
            text-decoration: none;
            font-weight: bold;
        }
        .cta-button {
            background-color: #ff6f6f; /* Helles Korallenrot */
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
        .supplier-info, .order-info {
            background-color: #fff;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
        }
        .order-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        .order-table th, .order-table td {
            border: 1px solid #ddd;
            padding: 12px;
            text-align: left;
        }
        .order-table th {
            background-color: #0a485b; /* Dunkles Blau */
            color: #fff;
        }
        footer {
            background-color: #0a485b; /* Dunkles Blau */
            color: white;
            padding: 20px;
            text-align: center;
            margin-top: 40px;
        }
    </style>
</head>
<body>

    <header>
        <img src="2t-logo.svg" alt="2T Videomarketing Logo">
        <h1 style="color:#ff6f6f">ERP Einkaufssystem</h1>
    </header>

    <nav>
        <form method="POST" action="?id=<?php echo $_REQUEST['id'] ?>&checkin=true">
            <button class="cta-button" type="submit">Check-In</button>
        </form>
    </nav>

    <div class="container">
        <div class="supplier-info">
            <h2>Lieferanteninformationen</h2>
            <p><strong>Lieferant:</strong> Foto Mundus GmbH & Co. KG</p>
            <p><strong>Adresse:</strong> Döppers Kamp 4, 48531 Nordhorn</p>
            <p><strong>Inhaber:</strong> Lutz Bergknecht</p>
            <p><strong>Lieferanten-Besteller-Nummer:</strong> <span id="supplier-order-number"><?php echo $order_id ?></span></p>
        </div>

        <div class="order-info">
            <h2>Bestellinformationen</h2>
            <table class="order-table">
                <thead>
                    <tr>
                        <th>Artikelnummer</th>
                        <th>Bezeichnung</th>
                        <th>Menge</th>
                        <th>Einheitspreis</th>
                        <th>Gesamtpreis</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>2005</td>
                        <td>Canon EOS 5D Mark IV Gehäuse</td>
                        <td>2</td>
                        <td>1.650,00 €</td>
                        <td>3.300,00 €</td>
                    </tr>
                    <tr>
                        <td>2007</td>
                        <td>Nikon D780 Gehäuse Schwarz</td>
                        <td>1</td>
                        <td>1.200,00 €</td>
                        <td>1.200,00 €</td>
                    </tr>
                    <tr>
                        <td>2001</td>
                        <td>Canon EOS 250D Gehäuse Schwarz</td>
                        <td>5</td>
                        <td>350,00 €</td>
                        <td>1.750,00 €</td>
                    </tr>
                    <tr>
                        <td>2016</td>
                        <td>Canon RF 18-150mm F/3.5-6.3 IS STM</td>
                        <td>3</td>
                        <td>310,00 €</td>
                        <td>930,00 €</td>
                    </tr>
                    <tr>
                        <td colspan="4" style="text-align: right; font-weight: bold;">Gesamtbetrag:</td>
                        <td><strong>7.180,00 €</strong></td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>

    <footer>
        <p>© 2024 2T-Videomarketing Thimo Tremmel | ERP Einkaufssystem</p>
    </footer>

</body>
</html>
