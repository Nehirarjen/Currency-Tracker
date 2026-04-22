#!/bin/bash
# =============================================================
# DATEI:      main.sh
# ZWECK:      Einstiegspunkt – lädt alle Module und steuert den Ablauf
# AUTOR:      Alle
# =============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Module laden
source "$SCRIPT_DIR/storage.sh"
source "$SCRIPT_DIR/api.sh"
source "$SCRIPT_DIR/display.sh"

# =============================================================
# FUNKTION:   main
# ZWECK:      Hauptablauf des gesamten SafeSync-Systems
# PARAMETER:  keine
# RÜCKGABE:   keine
# =============================================================
main() {
    init_storage        # Person 3: CSV + Log vorbereiten

    run_api             # Person 1: Kurse holen + Alerts prüfen
    if [[ $? -ne 0 ]]; then
        echo "Fehler beim API-Aufruf. Siehe data/safesync.log"
        exit 1
    fi

    save_rates          # Person 3: Kurse in CSV speichern

    show_dashboard      # Person 2: Tabelle anzeigen
}

main
