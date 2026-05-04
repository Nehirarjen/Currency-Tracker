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
    printf "╔══════════╦══════════════╦═══════════╦══════════════════════╗\n"
    printf "║ Währung  ║ Aktueller    ║ Trend     ║ Abstand zum ATH      ║\n"
    printf "╠══════════╬══════════════╬═══════════╬══════════════════════╣\n"
}

# Funktion: draw_table_footer
# Zweck: Schließt die Tabelle ab
function draw_table_footer() {
    printf "╚══════════╩══════════════╩═══════════╩══════════════════════╝\n"
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

    local bar="["

    for ((i=0; i<filled_blocks; i++)); do
        bar+="█"
    done

    for ((i=0; i<empty_blocks; i++)); do
        bar+="░"
    done

    bar+="]"
    echo "$bar"
}

# Funktion: convert_chf
# Zweck: Rechnet einen CHF-Betrag in alle Zielwährungen um (aus RATES[])
# Parameter: $1 = CHF Betrag
function convert_chf() {
    local chf_amount=$1
    local currencies=("USD" "EUR" "GBP" "JPY" "BTC" "ETH")

    echo -e "${COLOR_BOLD}Umrechnung für $chf_amount CHF:${COLOR_RESET}"

    for curr in "${currencies[@]}"; do
        local rate="${RATES[$curr]}"
        if [[ -z "$rate" || "$rate" == "N/A" ]]; then continue; fi
        local result=$(echo "$chf_amount * $rate" | bc -l)
        printf " ► %s: %.6f\n" "$curr" "$result"
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
# Zweck: Rendert das komplette Dashboard mit echten Kursen aus RATES[]
function display_dashboard() {
    clear
    echo -e "${COLOR_BOLD}=== SafeSync Enterprise Monitor ===${COLOR_RESET}"
    echo -e "Stand: $(date '+%d.%m.%Y %H:%M:%S')\n"

    draw_table_header

    # ATH-Werte (1 CHF = X Einheiten) – Referenzwerte für Fortschrittsbalken
    declare -A ATH
    ATH["USD"]="1.32"; ATH["EUR"]="1.12"; ATH["GBP"]="1.00"
    ATH["JPY"]="215";  ATH["BTC"]="0.000025"; ATH["ETH"]="0.00065"

    local currencies=("USD" "EUR" "GBP" "JPY" "BTC" "ETH")

    for curr in "${currencies[@]}"; do
        local current_rate="${RATES[$curr]}"
        if [[ -z "$current_rate" || "$current_rate" == "N/A" ]]; then continue; fi

        local previous_rate
        previous_rate=$(load_old_rate "$curr")

        local trend_sym trend_col bar pct
        trend_sym=$(get_trend_symbol "$current_rate" "$previous_rate")
        trend_col=$(get_trend_color  "$current_rate" "$previous_rate")

        local ath="${ATH[$curr]:-1}"
        pct=$(echo "scale=0; ($current_rate / $ath) * 100" | bc)
        (( pct > 100 )) && pct=100

        bar=$(draw_progress_bar "$pct")

        local col1 col2 col4
        col1=$(pad_right "$curr"            8)
        col2=$(pad_right "$current_rate"   12)
        col4=$(pad_right "$bar"            20 12)

        printf "║ %s ║ %s ║ ${trend_col}%s${COLOR_RESET}        ║ %s ║\n" \
            "$col1" "$col2" "$trend_sym" "$col4"
    done

    draw_table_footer

    echo ""
    read -rp "CHF-Betrag umrechnen (Enter zum Überspringen): " chf_input
    if [[ -n "$chf_input" ]]; then
        convert_chf "$chf_input"
    fi
}

