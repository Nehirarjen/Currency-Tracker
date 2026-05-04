#!/bin/bash
# =============================================================
# DATEI:      api.sh
# ZWECK:      API-Abfragen, Datenverarbeitung, Alert-System
# AUTOR:      Nehir
# KRITERIEN:  (c) Funktionen/Arrays/Schleifen  (f) Benutzer-Information
# =============================================================

source "$(dirname "$0")/storage.sh"

# --- Konfiguration ---
BASE_URL="https://api.exchangerate-api.com/v4/latest/CHF"
ALERT_THRESHOLD=5
DISCORD_WEBHOOK=""     # Discord-Webhook-URL hier eintragen
ALERT_MAIL=""          # E-Mail-Adresse hier eintragen (optional)

# --- Währungs-Array (Kriterium c: Arrays) ---
CURRENCIES=("USD" "EUR" "GBP" "JPY" "BTC" "ETH")

# Globales assoziatives Array für Kurse
declare -A RATES

# =============================================================
# FUNKTION:   fetch_rates
# ZWECK:      Ruft aktuelle Wechselkurse von der ExchangeRate-API ab
#             und speichert sie im globalen Array RATES[]
# PARAMETER:  keine
# RÜCKGABE:   Exit-Code 0=OK / 1=Fehler
# =============================================================
fetch_rates() {
    log_status "INFO" "Starte API-Abfrage: $BASE_URL"

    local response
    response=$(curl -s --max-time 10 "$BASE_URL")

    if [[ $? -ne 0 || -z "$response" ]]; then
        log_status "NotOK" "API-Abfrage fehlgeschlagen – keine Antwort erhalten"
        return 1
    fi

    local api_status
    api_status=$(echo "$response" | jq -r '.result // "error"')

    if [[ "$api_status" != "success" ]]; then
        log_status "NotOK" "API hat Fehler zurückgegeben: $api_status"
        return 1
    fi

    # Kurse ins Array laden (Kriterium c: Schleifen + Arrays)
    for currency in "${CURRENCIES[@]}"; do
        local rate
        rate=$(echo "$response" | jq -r ".rates.${currency} // \"N/A\"")
        RATES["$currency"]="$rate"
    done

    log_status "OK" "Kurse erfolgreich geladen: ${CURRENCIES[*]}"
    return 0
}

# =============================================================
# FUNKTION:   send_alert
# ZWECK:      Sendet eine Benachrichtigung bei starken Kursschwankungen
#             via Discord Webhook und/oder E-Mail (mailx)
# PARAMETER:  $1 = Währung (z.B. USD)
#             $2 = Änderung in Prozent (z.B. 6.23)
#             $3 = Richtung (UP oder DOWN)
# RÜCKGABE:   Exit-Code 0=gesendet / 1=Fehler
# =============================================================


# =============================================================
# FUNKTION:   check_thresholds
# ZWECK:      Vergleicht aktuelle Kurse mit dem letzten gespeicherten
#             Wert aus der CSV-Datenbank. Löst send_alert() aus,
#             wenn die Änderung den ALERT_THRESHOLD überschreitet.
# PARAMETER:  keine
# RÜCKGABE:   keine
# =============================================================
check_thresholds() {
    local csv_file="$(dirname "$0")/data/kurse_history.csv"
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

    # Versand-Befehl
    echo "$body" | mailx -s "$subject" "$ALERT_MAIL"
    
    if [[ $? -eq 0 ]]; then
        log_status "OK" "E-Mail-Alert für $curr erfolgreich versendet."
    else
        log_status "NotOK" "E-Mail-Versand für $curr fehlgeschlagen."
    fi
}
    
    # Falls Datei nicht existiert oder leer ist (nur Header), abbrechen
    [[ ! -f "$csv_file" || $(wc -l < "$csv_file") -lt 2 ]] && return

    for currency in "${CURRENCIES[@]}"; do
        local current_rate=${RATES[$currency]}
        
        # Spaltenindex der Währung ermitteln
        local col_index=$(head -1 "$csv_file" | tr ',' '\n' | grep -n "^${currency}$" | cut -d: -f1)

        if [[ -z "$col_index" ]]; then
            continue
        fi

        # Letzten Kurs aus der letzten Zeile extrahieren
        local last_rate=$(tail -1 "$csv_file" | cut -d',' -f"$col_index")

        # Prozentuale Änderung berechnen mit bc (Gleitkomma)
        if [[ "$last_rate" != "N/A" && "$current_rate" != "N/A" && "$last_rate" != "0" ]]; then
            local change=$(echo "scale=2; (($current_rate - $last_rate) / $last_rate) * 100" | bc)

            # Absolutwert für den Vergleich berechnen (Minuszeichen entfernen)
            local abs_change=$(echo "$change" | tr -d '-')

            # Prüfen, ob die Änderung den Schwellenwert erreicht
            if (( $(echo "$abs_change >= $ALERT_THRESHOLD" | bc -l) )); then
                local direction="UP"
                # Wenn change kleiner 0 ist, ist die Richtung DOWN
                (( $(echo "$change < 0" | bc -l) )) && direction="DOWN"
                
                send_alert "$currency" "$change" "$direction"
            fi
        fi
    done
}

# =============================================================
# FUNKTION:   run_api
# ZWECK:      Hauptablauf von api.sh – wird von main.sh aufgerufen.
#             Führt Fetch und Threshold-Check in der richtigen
#             Reihenfolge aus.
# PARAMETER:  keine
# RÜCKGABE:   Exit-Code 0=OK / 1=Fehler
# =============================================================
run_api() {
    fetch_rates || return 1
    check_thresholds
    return 0
}
