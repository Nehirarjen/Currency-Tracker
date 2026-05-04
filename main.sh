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
source "$SCRIPT_DIR/notify.sh"

# =============================================================
# FUNKTION:   main
# ZWECK:      Hauptablauf des gesamten SafeSync-Systems
# =============================================================
main() {
    init_storage

    # Benachrichtigungs-Setup beim ersten Start
    setup_notifications

    # Konfiguration laden (E-Mail + Schwellenwert)
    load_notification_config

    while true; do
        run_api
        if [[ $? -ne 0 ]]; then
            echo "Fehler beim API-Aufruf. Siehe data/safesync.log"
            exit 1
        fi

        save_rates
        display_dashboard
        show_notification_status

        echo ""
        echo -e "  \033[1m[R]\033[0m Aktualisieren   \033[1m[E]\033[0m Benachrichtigungs-Einstellungen   \033[1m[Q]\033[0m Beenden"
        read -t 60 -rp "  > " user_input

        case "${user_input,,}" in
            q)
                echo ""
                echo "Auf Wiedersehen!"
                exit 0
                ;;
            e)
                configure_email_interactive
                ;;
            *)
                # R, Enter oder Timeout → aktualisieren
                continue
                ;;
        esac
    done
}

main
