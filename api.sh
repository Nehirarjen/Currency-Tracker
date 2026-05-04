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
CRYPTO_URL="https://api.coingecko.com/api/v3/simple/price"
ALERT_THRESHOLD="${ALERT_THRESHOLD:-5}"

# --- Währungs-Arrays (Kriterium c) ---
FIAT_CURRENCIES=("USD" "EUR")
CRYPTO_CURRENCIES=("BTC" "ETH" "SOL" "XRP")
CURRENCIES=("${FIAT_CURRENCIES[@]}" "${CRYPTO_CURRENCIES[@]}")

# Mapping: Symbol → CoinGecko-ID
declare -A CRYPTO_IDS=(
    ["BTC"]="bitcoin"
    ["ETH"]="ethereum"
    ["SOL"]="solana"
    ["XRP"]="ripple"
)

# Globales assoziatives Array für aktuelle Kurse
declare -A RATES

# Globales Array für Schwankungs-Alarme (wird in display_dashboard ausgegeben)
declare -a ALERTS=()

# =============================================================
# FUNKTION:    fetch_rates
# ZWECK:       Ruft aktuelle Wechselkurse ab und parst JSON
# =============================================================
fetch_rates() {
    log_status "INFO" "Starte Fiat-API-Abfrage: $BASE_URL"

    local response
    response=$(curl -s --max-time 10 "$BASE_URL")

    if [[ $? -ne 0 || -z "$response" ]]; then
        log_status "NotOK" "Fiat-API-Abfrage fehlgeschlagen."
        return 1
    fi

    for curr in "${FIAT_CURRENCIES[@]}"; do
        local rate=$(echo "$response" | jq -r ".rates.$curr")
        if [[ "$rate" != "null" && -n "$rate" ]]; then
            RATES[$curr]=$rate
        else
            log_status "NotOK" "Kurs für $curr konnte nicht gelesen werden."
        fi
    done

    log_status "OK" "Fiat-Daten erfolgreich verarbeitet."
    return 0
}

# =============================================================
# FUNKTION:    fetch_crypto_rates
# ZWECK:       Ruft Krypto-Kurse via CoinGecko ab (CHF pro Coin)
# =============================================================
fetch_crypto_rates() {
    local id_list=""
    for sym in "${CRYPTO_CURRENCIES[@]}"; do
        id_list+="${CRYPTO_IDS[$sym]},"
    done
    id_list="${id_list%,}"

    log_status "INFO" "Starte Krypto-API-Abfrage: CoinGecko"

    local response
    response=$(curl -s --max-time 10 "${CRYPTO_URL}?ids=${id_list}&vs_currencies=chf")

    if [[ $? -ne 0 || -z "$response" ]]; then
        log_status "NotOK" "Krypto-API-Abfrage fehlgeschlagen."
        return 1
    fi

    for sym in "${CRYPTO_CURRENCIES[@]}"; do
        local cg_id="${CRYPTO_IDS[$sym]}"
        local price_chf
        price_chf=$(echo "$response" | jq -r ".[\"$cg_id\"].chf")
        if [[ "$price_chf" != "null" && -n "$price_chf" && "$price_chf" != "0" ]]; then
            # Umrechnen auf "Coins pro CHF" (konsistent mit Fiat-Format)
            local rate
            rate=$(echo "scale=10; 1 / $price_chf" | bc -l)
            RATES[$sym]=$rate
        else
            log_status "NotOK" "Kurs für $sym (CoinGecko) konnte nicht gelesen werden."
        fi
    done

    log_status "OK" "Krypto-Daten erfolgreich verarbeitet."
    return 0
}

# =============================================================
# FUNKTION:    send_alert
# ZWECK:       Leitet Alarm an Benachrichtigungs-System weiter (Kriterium f)
# =============================================================
send_alert() {
    local curr=$1
    local diff=$2
    local dir=$3
    local val=${RATES[$curr]}

    # Delegiert an notify.sh (send_notification)
    send_notification "$curr" "$diff" "$dir" "$val"
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
        [[ -z "$current_rate" ]] && continue

        # Letzten gespeicherten Kurs aus zeilenbasierter CSV lesen
        local last_rate=$(grep ",$currency," "$csv_file" | tail -1 | cut -d',' -f3)

        if [[ -n "$last_rate" && "$last_rate" != "N/A" && "$current_rate" != "N/A" && "$last_rate" != "0" ]]; then
            # Prozentuale Änderung berechnen
            local change=$(echo "scale=2; (($current_rate - $last_rate) / $last_rate) * 100" | bc)
            local abs_change=$(echo "$change" | tr -d '-')

            if (( $(echo "$abs_change >= $ALERT_THRESHOLD" | bc -l) )); then
                local direction="UP"
                (( $(echo "$change < 0" | bc -l) )) && direction="DOWN"

                send_alert "$currency" "$change" "$direction"

                local alert_sign=""
                [[ "$direction" == "UP" ]] && alert_sign="+"
                ALERTS+=("$currency: ${alert_sign}${change}% Schwankung erkannt!")
            fi
        fi
    done
}

# =============================================================
# FUNKTION:    run_api
# =============================================================
run_api() {
    fetch_rates || return 1
    fetch_crypto_rates  # Fehler hier sind nicht kritisch
    check_thresholds
    return 0
}
