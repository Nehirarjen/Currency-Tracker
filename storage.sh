#!/bin/bash

# ==============================================================================
# ZWECK: Daten-Persistenz, Logging (OK/NotOK) und Analyse
# LB3-KRITERIEN: e (Logging), c (Arrays/Schleifen), b (Kommentare)
# ==============================================================================

# Pfad-Definitionen
# Wir nutzen diesen Trick, damit Cron den Ordner immer findet:
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HISTORY_FILE="$BASE_DIR/data/kurse_history.csv"
LOG_FILE="$BASE_DIR/data/safesync.log"
BACKUP_DIR="$BASE_DIR/data/backups"

# --- FUNKTION: log_status (Kriterium e) ---
# Schreibt System-Ereignisse automatisch mit Status OK oder NotOK in das Log.
log_status() {
    local status=$1 # Erwartet "OK" oder "NotOK"
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo "[$timestamp] [$status] - $message" >> "$LOG_FILE"
}

# --- FUNKTION: init_storage ---
# Erstellt automatisch die Ordnerstruktur und die CSV-Datenbank mit Header.
init_storage() {
    mkdir -p "$BACKUP_DIR"
    if [ ! -f "$HISTORY_FILE" ]; then
        # Erstellt die Datei mit Kopfzeile (Header)
        echo "Zeitstempel,Währung,Kurs" > "$HISTORY_FILE"
        log_status "OK" "Datenbank und Struktur initialisiert."
    fi
}

# --- FUNKTION: create_backup (WOW-EFFEKT) ---
# Erstellt eine Sicherheitskopie der Daten mit aktuellem Datum.
create_backup() {
    local backup_file="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M).csv"
    cp "$HISTORY_FILE" "$backup_file"
    log_status "OK" "Automatisches Backup erstellt: $backup_file"
}

# --- FUNKTION: save_rates (Kriterium c) ---
# Speichert alle Kurse in einer Schleife und prüft auf Fehler.
save_rates() {
    init_storage
    local error_count=0
    
    # Array der zu überwachenden Währungen
    local currencies=("EUR" "USD" "BTC" "ETH" "GBP" "JPY")
    
    log_status "OK" "Starte Synchronisation der Kurse..."
    
    for curr in "${currencies[@]}"; do
        # Aufruf der API-Funktion (von Person 1)
        local rate=$(get_rate "$curr")
        
        if [[ -n "$rate" && "$rate" != "null" ]]; then
            echo "$(date "+%Y-%m-%d %H:%M:%S"),$curr,$rate" >> "$HISTORY_FILE"
        else
            log_status "NotOK" "Fehler: Kurs für $curr konnte nicht empfangen werden."
            ((error_count++))
        fi
    done
    
    # Erfolgskontrolle
    if [ "$error_count" -eq 0 ]; then
        log_status "OK" "Synchronisation erfolgreich abgeschlossen."
        # Backup alle X Durchläufe (Logik: Wenn Zeilenanzahl durch 60 teilbar ist)
        local lines=$(wc -l < "$HISTORY_FILE")
        if (( lines % 60 == 0 )); then create_backup; fi
    else
        log_status "NotOK" "Synchronisation mit $error_count Fehlern beendet."
    fi
}

# --- FUNKTION: calc_diff ---
# Berechnet die prozentuale Änderung zwischen zwei Werten mit 'bc'.
calc_diff() {
    local now=$1
    local old=$2
    # Fehlerprüfung: Falls kein alter Wert vorhanden ist
    if [[ -z "$old" || "$old" == "0" || "$old" == "0.00" ]]; then
        echo "0.00"
        return
    fi
    # Berechnung via bc
    echo "scale=2; (($now / $old) - 1) * 100" | bc
}

# --- FUNKTION: load_old_rate ---
# Sucht den letzten gespeicherten Wert einer Währung für den Vergleich.
load_old_rate() {
    local currency=$1
    if [ ! -f "$HISTORY_FILE" ]; then echo "0.00"; return; fi
    
    # Holt den letzten Wert (tail -n 1) vor dem aktuellsten Eintrag
    local val=$(grep ",$currency," "$HISTORY_FILE" | tail -n 2 | head -n 1 | cut -d',' -f3)
    echo "${val:-0.00}"
}
