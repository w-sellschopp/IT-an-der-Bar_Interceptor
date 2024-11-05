#include <iostream>
#include <string>

#ifdef _WIN32
#include <windows.h> // Für SetConsoleOutputCP und SetConsoleCP
#endif

void zeigeGeheimesMenue() {
    int auswahl = 0;

    while (auswahl != 3) {
        std::cout << "\nIT an der Bar Geheim Menü:\n";
        std::cout << "1. Bestseller Rezepte\n";
        std::cout << "2. Gefällt es? Gerne ein Abo da lassen\n";
        std::cout << "3. Beenden\n";
        std::cout << "Bitte wählen Sie eine Option (1-3): ";
        std::cin >> auswahl;

        switch (auswahl) {
        case 1:
            std::cout << "1cl geheime Zutat\n";
            break;
        case 2:
            std::cout << "Juhuuuuuuu :)\n";
            break;
        case 3:
            std::cout << "Programm wird beendet...\n";
            break;
        default:
            std::cout << "Ungültige Auswahl. Bitte versuchen Sie es erneut.\n";
        }
    }
}

int main() {
#ifdef _WIN32
    // Setze die Konsolencodierung auf UTF-8 (Codepage 65001)
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleCP(CP_UTF8);
#endif

    const std::string richtigesPasswort = "GehEimE5!";
    std::string eingegebenesPasswort;

    // Passwortabfrage-Schleife
    while (true) {
        std::cout << "Bitte geben Sie das Passwort ein: ";
        std::cin >> eingegebenesPasswort;

        if (eingegebenesPasswort == richtigesPasswort) {
            std::cout << "Passwort korrekt! Zugang zum geheimen Menü gewährt.\n";
            zeigeGeheimesMenue(); // Geheimes Menü anzeigen
            break; // Beenden der Passwortschleife nach dem Menü
        }
        else {
            std::cout << "Zugang verweigert! Falsches Passwort. Bitte erneut versuchen.\n";
        }
    }

    return 0;
}
