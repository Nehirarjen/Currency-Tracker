#!/bin/bash
# ==========================================
# Modul: SafeSync - Benachrichtigungs-System
# Beschreibung: E-Mail-Konfiguration und Benachrichtigungen bei Kursalarmen
# ==========================================

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$BASE_DIR/data/config.cfg"

# Farben
_N_BOLD='\033[1m'
_N_GREEN='\033[0;32m'
_N_RED='\033[0;31m'
_N_YELLOW='\033[1;33m'
_N_CYAN='\033[0;36m'
_N_RESET='\033[0m'

# =============================================================
# FUNKTION: load_notification_config
# ZWECK:    Lädt gespeicherte Konfiguration aus config.cfg
# =============================================================
load_notification_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
}

# =============================================================
# FUNKTION: save_notification_config
# PARAMETER: $1 = E-Mail, $2 = Schwellenwert, $3 = Aktiv (true/false)
# =============================================================
save_notification_config() {
    local email="$1"
    local threshold="${2:-5}"
    local enabled="${3:-true}"

    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" << EOF
# SafeSync Konfiguration
# Zuletzt gespeichert: $(date '+%d.%m.%Y %H:%M:%S')
ALERT_MAIL="$email"
ALERT_THRESHOLD=$threshold
NOTIFICATIONS_ENABLED=$enabled
EOF
}

# =============================================================
# FUNKTION: validate_email
# ZWECK:    Prüft ob eine E-Mail-Adresse gültig aussieht
# =============================================================
validate_email() {
    [[ "$1" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

# =============================================================
# FUNKTION: setup_notifications
# ZWECK:    Erster-Start-Dialog zur E-Mail-Einrichtung
# =============================================================
setup_notifications() {
    load_notification_config

    # Nur beim ersten Start (keine Config-Datei vorhanden)
    [[ -f "$CONFIG_FILE" ]] && return

    clear
    echo -e "${_N_BOLD}╔══════════════════════════════════════════════════╗${_N_RESET}"
    echo -e "${_N_BOLD}║        SafeSync – Benachrichtigungs-Setup        ║${_N_RESET}"
    echo -e "${_N_BOLD}╚══════════════════════════════════════════════════╝${_N_RESET}"
    echo ""
    echo "  Willkommen bei SafeSync!"
    echo "  Sie können E-Mail-Benachrichtigungen einrichten."
    echo "  Sie werden alarmiert, wenn sich ein Kurs um mehr"
    echo -e "  als ${_N_YELLOW}${ALERT_THRESHOLD:-5}%${_N_RESET} verändert."
    echo ""
    echo -e "  ${_N_CYAN}Tipp: Drücken Sie Enter ohne Eingabe, um zu überspringen.${_N_RESET}"
    echo ""

    local email=""
    while true; do
        read -rp "  E-Mail-Adresse eingeben: " email

        if [[ -z "$email" ]]; then
            save_notification_config "" "${ALERT_THRESHOLD:-5}" "false"
            ALERT_MAIL=""
            NOTIFICATIONS_ENABLED="false"
            echo ""
            echo -e "  ${_N_YELLOW}Benachrichtigungen deaktiviert.${_N_RESET}"
            echo -e "  ${_N_CYAN}(Einstellungen später mit [E] ändern)${_N_RESET}"
            break
        elif validate_email "$email"; then
            save_notification_config "$email" "${ALERT_THRESHOLD:-5}" "true"
            ALERT_MAIL="$email"
            NOTIFICATIONS_ENABLED="true"
            echo ""
            echo -e "  ${_N_GREEN}✓ Benachrichtigungen aktiviert für: $email${_N_RESET}"
            break
        else
            echo -e "  ${_N_RED}Ungültige E-Mail-Adresse. Bitte erneut versuchen.${_N_RESET}"
        fi
    done

    sleep 2
}

# =============================================================
# FUNKTION: configure_email_interactive
# ZWECK:    Einstellungs-Menü zum Ändern der E-Mail-Konfiguration
# =============================================================
configure_email_interactive() {
    load_notification_config

    while true; do
        clear
        echo -e "${_N_BOLD}=== Benachrichtigungs-Einstellungen ===${_N_RESET}"
        echo ""

        if [[ -n "$ALERT_MAIL" && "$NOTIFICATIONS_ENABLED" == "true" ]]; then
            echo -e "  Status:        ${_N_GREEN}Aktiv${_N_RESET}"
            echo -e "  E-Mail:        ${_N_GREEN}$ALERT_MAIL${_N_RESET}"
        else
            echo -e "  Status:        ${_N_RED}Deaktiviert${_N_RESET}"
            echo -e "  E-Mail:        ${_N_YELLOW}(keine)${_N_RESET}"
        fi
        echo -e "  Alarmgrenze:   ${ALERT_THRESHOLD:-5}% Kursänderung"
        echo ""
        echo "  [1] E-Mail-Adresse ändern"
        echo "  [2] Benachrichtigungen deaktivieren"
        echo "  [3] Alarmgrenze ändern"
        echo "  [0] Zurück zum Dashboard"
        echo ""
        read -rp "  Auswahl: " choice

        case "$choice" in
            1)
                echo ""
                local new_email=""
                while true; do
                    read -rp "  Neue E-Mail-Adresse: " new_email
                    if [[ -z "$new_email" ]]; then
                        echo -e "  ${_N_YELLOW}Abgebrochen.${_N_RESET}"
                        break
                    elif validate_email "$new_email"; then
                        save_notification_config "$new_email" "${ALERT_THRESHOLD:-5}" "true"
                        ALERT_MAIL="$new_email"
                        NOTIFICATIONS_ENABLED="true"
                        echo -e "  ${_N_GREEN}✓ E-Mail gespeichert: $new_email${_N_RESET}"
                        sleep 1
                        break
                    else
                        echo -e "  ${_N_RED}Ungültige E-Mail. Bitte erneut versuchen.${_N_RESET}"
                    fi
                done
                ;;
            2)
                save_notification_config "" "${ALERT_THRESHOLD:-5}" "false"
                ALERT_MAIL=""
                NOTIFICATIONS_ENABLED="false"
                echo -e "  ${_N_YELLOW}Benachrichtigungen deaktiviert.${_N_RESET}"
                sleep 1
                ;;
            3)
                echo ""
                read -rp "  Neue Alarmgrenze in Prozent [aktuell: ${ALERT_THRESHOLD:-5}]: " new_thresh
                if [[ "$new_thresh" =~ ^[0-9]+$ && "$new_thresh" -gt 0 && "$new_thresh" -le 100 ]]; then
                    ALERT_THRESHOLD="$new_thresh"
                    save_notification_config "${ALERT_MAIL:-}" "$ALERT_THRESHOLD" "${NOTIFICATIONS_ENABLED:-false}"
                    echo -e "  ${_N_GREEN}✓ Alarmgrenze gesetzt auf: $ALERT_THRESHOLD%${_N_RESET}"
                    sleep 1
                else
                    echo -e "  ${_N_RED}Ungültige Eingabe (1–100).${_N_RESET}"
                    sleep 1
                fi
                ;;
            0|"")
                break
                ;;
            *)
                echo -e "  ${_N_RED}Ungültige Auswahl.${_N_RESET}"
                sleep 1
                ;;
        esac
    done
}

# =============================================================
# FUNKTION: send_notification
# PARAMETER: $1 = Währung, $2 = Änderung%, $3 = Richtung (UP/DOWN), $4 = Rohkurs
# =============================================================
send_notification() {
    local curr="$1"
    local diff="$2"
    local dir="$3"
    local raw_rate="$4"

    load_notification_config

    [[ -z "$ALERT_MAIL" || "$NOTIFICATIONS_ENABLED" != "true" ]] && return

    local dir_de="gestiegen"
    [[ "$dir" == "DOWN" ]] && dir_de="gefallen"

    # Rohkurs in CHF pro Einheit umrechnen
    local display_rate="N/A"
    if [[ -n "$raw_rate" && "$raw_rate" != "0" ]]; then
        display_rate=$(echo "scale=4; 1 / $raw_rate" | bc -l 2>/dev/null)
        display_rate=$(printf "%.4f CHF" "$display_rate")
    fi

    local sign=""
    (( $(echo "$diff >= 0" | bc -l 2>/dev/null) )) && sign="+"

    local subject="[SafeSync] Alarm: $curr ${sign}${diff}% ($dir_de)"
    local body="SafeSync Markt-Benachrichtigung
================================================

  Währung:     $curr
  Richtung:    $dir_de
  Veränderung: ${sign}${diff}%
  Kurs:        $display_rate
  Zeitpunkt:   $(date '+%d.%m.%Y %H:%M:%S')

------------------------------------------------
Automatische Nachricht von SafeSync.
Benachrichtigungs-Grenze: ${ALERT_THRESHOLD:-5}%

Einstellungen ändern: Programm starten → [E]"

    echo "$body" | mailx -s "$subject" "$ALERT_MAIL" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        log_status "OK" "E-Mail-Alarm gesendet an $ALERT_MAIL: $curr ${sign}${diff}%"
    else
        log_status "NotOK" "E-Mail-Versand fehlgeschlagen an $ALERT_MAIL für $curr"
    fi
}

# =============================================================
# FUNKTION: show_notification_status
# ZWECK:    Zeigt den Benachrichtigungs-Status im Dashboard an
# =============================================================
show_notification_status() {
    load_notification_config

    echo ""
    if [[ -n "$ALERT_MAIL" && "$NOTIFICATIONS_ENABLED" == "true" ]]; then
        echo -e "  Benachrichtigungen: ${_N_GREEN}Aktiv${_N_RESET} → ${_N_CYAN}$ALERT_MAIL${_N_RESET}  (Grenze: ${ALERT_THRESHOLD:-5}%)"
    else
        echo -e "  Benachrichtigungen: ${_N_RED}Nicht konfiguriert${_N_RESET}  ${_N_YELLOW}→ Drücke [E] zum Einrichten${_N_RESET}"
    fi
}
