#!/bin/bash

# Pfad-Definitionen (Wichtig für Cron: Absolute Pfade nutzen!)
# Wir nutzen $(pwd), damit es überall dort funktioniert, wo der Ordner liegt
BASE_DIR=$(pwd)
HISTORY_FILE="$BASE_DIR/data/kurse_history.csv"
LOG_FILE="$BASE_DIR/data/safesync.log"

# Kriterium e: Protokollieren von OK und NotOK
log_status() {
    local status=$1 # "OK" oder "NotOK"
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # In die Datei schreiben
    echo "[$timestamp] [$status] - $message" >> "$LOG_FILE"
    
    # Optional: NotOK auch fett im Terminal anzeigen
    if [[ "$status" == "NotOK" ]]; then
        echo -e "\033[0;31m[ALARM]\033[0m Fehler protokolliert in safesync.log"
    fi
}

# Initialisierung der Datenstruktur
init_storage() {
    mkdir -p "$BASE_DIR/data"
    if [ ! -f "$HISTORY_FILE" ]; then
        echo "Zeitstempel,Währung,Kurs" > "$HISTORY_FILE"
        log_status "OK" "Datenbank-Datei neu erstellt."
    fi
}

# Speichern der Kurse (Kriterium c: Arrays & Schleifen)
save_rates() {
    init_storage
    local error_count=0
    
    # Die Liste der Währungen als Array
    currencies=("EUR" "USD" "BTC" "ETH" "GBP" "JPY")
    
    for curr in "${currencies[@]}"; do
        # Wir rufen die Funktion von Person 1 auf
        local rate=$(get_rate "$curr")
        
        if [[ -n "$rate" && "$rate" != "null" ]]; then
            echo "$(date "+%Y-%m-%d %H:%M:%S"),$curr,$rate" >> "$HISTORY_FILE"
        else
            log_status "NotOK" "Kurs für $curr konnte nicht gespeichert werden."
            ((error_count++))
        fi
    done
    
    if [ "$error_count" -eq 0 ]; then
        log_status "OK" "Alle Kurse erfolgreich synchronisiert."
    else
        log_status "NotOK" "Synchronisierung unvollständig ($error_count Fehler)."
    fi
}

# Berechnung der Differenz (mit bc für Kommastellen)
calc_diff() {
    local now=$1
    local old=$2
    if [[ -z "$old" || "$old" == "0" ]]; then echo "0.00"; return; fi
    # Formel: ((Neu / Alt) - 1) * 100
    echo "scale=2; (($now / $old) - 1) * 100" | bc
}

# Historischen Wert für den Vergleich laden
load_old_rate() {
    local currency=$1
    if [ ! -f "$HISTORY_FILE" ]; then echo "0"; return; fi
    # Holt den vorletzten Eintrag für diese Währung
    grep ",$currency," "$HISTORY_FILE" | tail -n 2 | head -n 1 | cut -d',' -f3
}
