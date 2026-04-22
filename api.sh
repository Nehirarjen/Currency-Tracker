#!/bin/bash
# =============================================================
# DATEI:      api.sh
# ZWECK:      API-Abfragen, Datenverarbeitung, E-Mail-Alerts
# AUTOR:      Nehir
# KRITERIEN:  (c) Funktionen/Arrays/Schleifen  (f) Benutzer-Information
# =============================================================

# Einbinden der Storage-Funktionen
source "$(dirname "$0")/storage.sh"

# --- Konfiguration ---
BASE_URL="https://api.exchangerate-api.com/v4/latest/CHF"
ALERT_THRESHOLD=5
ALERT_MAIL="deine-email@beispiel.ch"  # <--- HIER DEINE E-MAIL EINTRAGEN

# --- Währungs-Array (Kriterium c) ---
CURRENCIES=("USD" "EUR" "GBP" "JPY" "BTC" "ETH")

# Globales assoziatives Array für aktuelle Kurse
declare -A RATES

# =============================================================
# FUNKTION:    fetch_rates
# ZWECK:       Ruft aktuelle Wechselkurse ab und parst JSON
# =============================================================
fetch_rates() {
    log_status "INFO" "Starte API-Abfrage: $BASE_URL"

    local response
    response=$(curl -s --max-time 10 "$BASE_URL")

    if [[ $? -ne 0 || -z "$response" ]]; then
        log_status "NotOK" "API-Abfrage fehlgeschlagen."
        return 1
    fi

    for curr in "${CURRENCIES[@]}"; do
        local rate=$(echo "$response" | jq -r ".rates.$curr")
        if [[ "$rate" != "null" && -n "$rate" ]]; then
            RATES[$curr]=$rate
        else
            log_status "NotOK" "Kurs für $curr konnte nicht gelesen werden."
        fi
    done

    log_status "OK" "API-Daten erfolgreich verarbeitet."
    return 0
}

# =============================================================
# FUNKTION:    send_alert
# ZWECK:       Verschickt E-Mail via mailx (Kriterium f)
# =============================================================
send_alert() {
    local curr=$1
    local diff=$2
    local dir=$3
    local val=${RATES[$curr]}
    
    local subject="[SafeSync] Markt-Alarm: $curr ist $dir ($diff%)"
    local body="Achtung: Der Kurs von $curr hat sich signifikant verändert.
    
Währung: $curr
Richtung: $dir
Veränderung: $diff%
Aktueller Kurs: $val CHF

Zeitpunkt: $(date '+%d.%m.%Y %H:%M:%S')
Dies ist eine automatisierte Nachricht von SafeSync."

    # Versand via mailx
    echo "$body" | mailx -s "$subject" "$ALERT_MAIL"
    
    if [[ $? -eq 0 ]]; then
        log_status "OK" "E-Mail-Alert für $curr erfolgreich versendet."
    else
        log_status "NotOK" "E-Mail-Versand für $curr fehlgeschlagen."
    fi
}

# =============================================================
# FUNKTION:    check_thresholds
# ZWECK:       Vergleicht Kurse mit der CSV und triggert Alerts
# =============================================================
check_thresholds() {
    local csv_file="$(dirname "$0")/data/kurse_history.csv"
    
    # Prüfen ob Datei existiert und Daten enthält (mehr als nur Header)
    [[ ! -f "$csv_file" || $(wc -l < "$csv_file") -lt 2 ]] && return

    for currency in "${CURRENCIES[@]}"; do
        local current_rate=${RATES[$currency]}
        
        # Spaltenindex der Währung ermitteln
        local col_index=$(head -1 "$csv_file" | tr ',' '\n' | grep -n "^${currency}$" | cut -d: -f1)

        if [[ -z "$col_index" ]]; then
            continue
        fi

        # Letzten Kurs aus der CSV lesen
        local last_rate=$(tail -1 "$csv_file" | cut -d',' -f"$col_index")

        if [[ "$last_rate" != "N/A" && "$current_rate" != "N/A" && "$last_rate" != "0" ]]; then
            # Prozentuale Änderung berechnen
            local change=$(echo "scale=2; (($current_rate - $last_rate) / $last_rate) * 100" | bc)
            local abs_change=$(echo "$change" | tr -d '-')

            if (( $(echo "$abs_change >= $ALERT_THRESHOLD" | bc -l) )); then
                local direction="UP"
                (( $(echo "$change < 0" | bc -l) )) && direction="DOWN"
                
                send_alert "$currency" "$change" "$direction"
            fi
        fi
    done
}

# =============================================================
# FUNKTION:    run_api
# =============================================================
run_api() {
    fetch_rates || return 1
    check_thresholds
    return 0
}
