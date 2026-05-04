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
# Zweck: Rendert das komplette Dashboard
function display_dashboard() {
    clear
    echo -e "${COLOR_BOLD}=== SafeSync Enterprise Monitor ===${COLOR_RESET}\n"

    draw_table_header

    # Hier kommt später eine Schleife hin, die alle Währungen durchgeht.
    # Für das Layout-Testing hier ein Hardcoded-Beispiel:

    local trend_sym=$(get_trend_symbol 0.95 0.94)
    local trend_col=$(get_trend_color 0.95 0.94)
    local bar=$(draw_progress_bar 80)

    # Spalte 4: Balken hat immer 12 sichtbare Zeichen → pad_right auf 20 mit visible_len=12
    local col1=$(pad_right "EUR"      8)
    local col2=$(pad_right "0.95 CHF" 12)
    local col4=$(pad_right "$bar"     20 12)

    # Trendspalte: Symbol ist immer 1 sichtbares Zeichen → 8 Leerzeichen festes Padding
    printf "║ %s ║ %s ║ ${trend_col}%s${COLOR_RESET}        ║ %s ║\n" \
        "$col1" "$col2" "$trend_sym" "$col4"

    draw_table_footer
}

