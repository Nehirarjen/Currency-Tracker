#!/bin/bash
# ==========================================
# Modul: SafeSync - UX/UI & Grafische Visualisierung
# Autor: Elina Hulliger
# Beschreibung: Handhabt die Terminal-Ausgabe, Tabellen & Formatierung
# ==========================================

# --- ANSI Farbcodes ---
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_RESET='\033[0m'
COLOR_BOLD='\033[1m'

# Funktion: draw_table_header
# Zweck: Zeichnet den Kopf der Währungstabelle
function draw_table_header() {
    printf "╔════════════╦══════════════════╦══════════════╦══════════════════════╗\n"
    printf "║ Währung    ║ Aktueller        ║ Trend        ║ Abstand zum ATH      ║\n"
    printf "╠════════════╬══════════════════╬══════════════╬══════════════════════╣\n"
}

# Funktion: draw_table_footer
# Zweck: Schließt die Tabelle ab
function draw_table_footer() {
    printf "╚════════════╩══════════════════╩══════════════╩══════════════════════╝\n"
}

# Funktion: get_trend_symbol
# Zweck: Gibt NUR das Pfeilsymbol zurück (ohne Farbe)
function get_trend_symbol() {
    local current=$1
    local previous=$2
    local is_greater=$(echo "$current >= $previous" | bc -l)

    if [ "$is_greater" -eq 1 ]; then
        echo "↑"
    else
        echo "↓"
    fi
}

# Funktion: get_trend_color
# Zweck: Gibt NUR den Farbcode zurück (ohne Symbol)
function get_trend_color() {
    local current=$1
    local previous=$2
    local is_greater=$(echo "$current >= $previous" | bc -l)

    if [ "$is_greater" -eq 1 ]; then
        echo -e "${COLOR_GREEN}"
    else
        echo -e "${COLOR_RED}"
    fi
}

# Funktion: draw_progress_bar
# Zweck: Erstellt einen ASCII-Ladebalken basierend auf Prozentwerten
# Parameter: $1 = Prozentualer Wert (0-100)
# Sichtbare Breite ist immer 12 Zeichen: [ + 10 Blöcke + ]
function draw_progress_bar() {
    local percentage=$1
    local filled_blocks=$((percentage / 10))
    local empty_blocks=$((10 - filled_blocks))
    local GREEN=$'\033[32m'
    local GRAY=$'\033[2;37m'
    local RESET=$'\033[0m'

    local bar="["

    for ((i=0; i<filled_blocks; i++)); do
        bar+="${GREEN}█${RESET}"
    done

    for ((i=0; i<empty_blocks; i++)); do
        bar+="${GRAY}░${RESET}"
    done

    bar+="]"
    echo "$bar"
}

# Funktion: convert_chf
# Zweck: Rechnet einen CHF-Betrag in Zielwährungen um
# Parameter: $1 = CHF Betrag
function convert_chf() {
    local chf_amount=$1
    local currencies=("EUR:0.95" "USD:1.10" "BTC:0.000015")

    echo -e "${COLOR_BOLD}Umrechnung für $chf_amount CHF:${COLOR_RESET}"

    for entry in "${currencies[@]}"; do
        local curr="${entry%%:*}"
        local rate="${entry##*:}"
        local result=$(echo "$chf_amount * $rate" | bc -l)
        printf " ► %s: %.4f\n" "$curr" "$result"
    done
}

# Funktion: pad_right
# Zweck: Füllt einen String rechtsseitig mit Leerzeichen auf Zielbreite auf
# Parameter: $1 = String, $2 = Zielbreite, $3 = sichtbare Länge (optional, für Unicode-Strings)
function pad_right() {
    local str="$1"
    local width="$2"
    local visible_len="${3:-${#str}}"
    local spaces=$(( width - visible_len ))
    printf "%s%*s" "$str" "$spaces" ""
}

# Funktion: display_dashboard
# Zweck: Rendert das komplette Dashboard mit Live-Daten aus dem RATES-Array
function display_dashboard() {
    clear
    echo -e "${COLOR_BOLD}=== SafeSync Enterprise Monitor ===${COLOR_RESET}"
    echo -e "Zeit: $(date '+%d.%m.%Y %H:%M:%S')\n"

    draw_table_header

    for curr in "${CURRENCIES[@]}"; do
        local current_rate="${RATES[$curr]}"
        [[ -z "$current_rate" || "$current_rate" == "null" ]] && continue

        # API liefert "X Fremdwährung pro 1 CHF" → umrechnen auf "X CHF pro 1 Fremdwährung"
        local current_chf
        current_chf=$(echo "scale=6; 1 / $current_rate" | bc -l)

        local old_rate
        old_rate=$(load_old_rate "$curr")

        local old_chf="$current_chf"
        if [[ -n "$old_rate" && "$old_rate" != "0" && "$old_rate" != "0.00" ]]; then
            old_chf=$(echo "scale=6; 1 / $old_rate" | bc -l)
        fi

        local trend_sym trend_col
        if [[ -v TREND_PCT[$curr] ]]; then
            local is_positive
            is_positive=$(echo "${TREND_PCT[$curr]} >= 0" | bc -l)
            if [[ "$is_positive" -eq 1 ]]; then
                trend_sym="↑"
                trend_col="${COLOR_GREEN}"
            else
                trend_sym="↓"
                trend_col="${COLOR_RED}"
            fi
        else
            trend_sym=$(get_trend_symbol "$current_chf" "$old_chf")
            trend_col=$(get_trend_color "$current_chf" "$old_chf")
        fi

        # Abstand zum ATH: minimaler Rohkurs = maximaler CHF-Kurs (ATH)
        local min_raw_rate
        min_raw_rate=$(grep ",$curr," "$HISTORY_FILE" 2>/dev/null | cut -d',' -f3 | sort -n | head -1)
        local pct=100
        if [[ -n "$min_raw_rate" && "$min_raw_rate" != "0" ]]; then
            local max_chf
            max_chf=$(echo "scale=6; 1 / $min_raw_rate" | bc -l)
            pct=$(echo "scale=0; ($current_chf / $max_chf) * 100 / 1" | bc 2>/dev/null)
            pct=${pct:-100}
            (( pct > 100 )) && pct=100
            (( pct < 0 ))   && pct=0
        fi

        local bar
        bar=$(draw_progress_bar "$pct")

        local rate_str
        rate_str=$(printf "%.4f CHF" "$current_chf")

        # Prozentuale Änderung für Trend-Spalte (API-Wert bevorzugt)
        local change_pct="0.0"
        if [[ -v TREND_PCT[$curr] ]]; then
            change_pct=$(printf "%.1f" "${TREND_PCT[$curr]}" 2>/dev/null || echo "0.0")
        elif [[ -n "$old_rate" && "$old_rate" != "0" && "$old_rate" != "0.00" ]]; then
            change_pct=$(echo "scale=1; (($current_chf - $old_chf) / $old_chf) * 100" | bc)
            change_pct=$(printf "%.1f" "$change_pct" 2>/dev/null || echo "0.0")
        fi
        local change_sign=""
        (( $(echo "$change_pct >= 0" | bc -l) )) && change_sign="+"
        local trend_content="${trend_sym} ${change_sign}${change_pct}%"

        local col1 col2 col3 col4
        col1=$(pad_right "$curr"           10)
        col2=$(pad_right "$rate_str"      16)
        col3=$(pad_right "$trend_content" 12)
        col4=$(pad_right "$bar"           20 12)

        printf "║ %s ║ %s ║ ${trend_col}%s${COLOR_RESET} ║ %s ║\n" \
            "$col1" "$col2" "$col3" "$col4"
    done

    draw_table_footer

    # Schwankungs-Alarme anzeigen
    if [[ ${#ALERTS[@]} -gt 0 ]]; then
        local COLOR_YELLOW='\033[1;33m'
        echo ""
        echo -e "${COLOR_BOLD}${COLOR_RED}!! MARKT-ALARM !!${COLOR_RESET}"
        for alert in "${ALERTS[@]}"; do
            echo -e "  ${COLOR_YELLOW}[!] ${alert}${COLOR_RESET}"
        done
    fi

    echo ""
}
