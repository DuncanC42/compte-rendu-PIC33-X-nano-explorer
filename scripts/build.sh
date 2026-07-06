#!/usr/bin/env bash
# =============================================================
#  BUILD.SH — Script de build Bash (Linux/macOS)
#  Usage : ./scripts/build.sh [html|pdf|all] [--open]
# =============================================================
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/config/project.yaml"
OUTPUT="$ROOT/output"
FORMAT="${1:-html}"
OPEN=false
[[ "$*" == *"--open"* ]] && OPEN=true

# Vérifier pandoc
command -v pandoc >/dev/null 2>&1 || { echo "Erreur: pandoc non installé (https://pandoc.org)"; exit 1; }

# Parser YAML minimal (valeurs simples uniquement)
yaml_get() {
    grep -E "^\s*$1:\s*" "$CONFIG" | head -1 | sed -E "s/^\s*$1:\s*['\"]?(.+?)['\"]?\s*$/\1/"
}

# Générer theme.css depuis project.yaml
build_theme_css() {
    echo "  [OK] Génération theme.css..."
    # Extraire les couleurs du bloc theme
    primary=$(grep "primary:" "$CONFIG" | head -1 | sed -E "s/.*:\s*['\"]?(#[0-9A-Fa-f]+)['\"]?.*/\1/")
    secondary=$(grep "secondary:" "$CONFIG" | head -1 | sed -E "s/.*:\s*['\"]?(#[0-9A-Fa-f]+)['\"]?.*/\1/")
    accent=$(grep "accent:" "$CONFIG" | head -1 | sed -E "s/.*:\s*['\"]?(#[0-9A-Fa-f]+)['\"]?.*/\1/")
    text_color=$(grep "^  text:" "$CONFIG" | head -1 | sed -E "s/.*:\s*['\"]?(#[0-9A-Fa-f]+)['\"]?.*/\1/")
    text_muted=$(grep "text_muted:" "$CONFIG" | head -1 | sed -E "s/.*:\s*['\"]?(#[0-9A-Fa-f]+)['\"]?.*/\1/")
    bg=$(grep "^  bg:" "$CONFIG" | head -1 | sed -E "s/.*:\s*['\"]?(#[0-9A-Fa-f]+)['\"]?.*/\1/")
    bg_alt=$(grep "bg_alt:" "$CONFIG" | head -1 | sed -E "s/.*:\s*['\"]?(#[0-9A-Fa-f]+)['\"]?.*/\1/")
    border=$(grep "border:" "$CONFIG" | head -1 | sed -E "s/.*:\s*['\"]?(#[0-9A-Fa-f]+)['\"]?.*/\1/")
    code_bg=$(grep "code_bg:" "$CONFIG" | head -1 | sed -E "s/.*:\s*['\"]?(#[0-9A-Fa-f]+)['\"]?.*/\1/")
    code_text=$(grep "code_text:" "$CONFIG" | head -1 | sed -E "s/.*:\s*['\"]?(#[0-9A-Fa-f]+)['\"]?.*/\1/")
    font_size=$(grep "font_size:" "$CONFIG" | head -1 | sed -E "s/.*:\s*['\"]?([0-9]+px)['\"]?.*/\1/")
    line_height=$(grep "line_height:" "$CONFIG" | head -1 | sed -E "s/.*:\s*['\"]?([0-9.]+)['\"]?.*/\1/")
    max_width=$(grep "max_width:" "$CONFIG" | head -1 | sed -E "s/.*:\s*['\"]?([0-9]+px)['\"]?.*/\1/")
    radius=$(grep "border_radius:" "$CONFIG" | head -1 | sed -E "s/.*:\s*['\"]?([0-9]+px)['\"]?.*/\1/")

    cat > "$ROOT/assets/css/theme.css" <<EOF
/* AUTO-GÉNÉRÉ depuis config/project.yaml — ne pas modifier manuellement */
:root {
  --color-primary:    ${primary:-#2563EB};
  --color-secondary:  ${secondary:-#64748B};
  --color-accent:     ${accent:-#F59E0B};
  --color-text:       ${text_color:-#1F2937};
  --color-text-muted: ${text_muted:-#6B7280};
  --color-bg:         ${bg:-#FFFFFF};
  --color-bg-alt:     ${bg_alt:-#F8FAFC};
  --color-border:     ${border:-#E2E8F0};
  --color-code-bg:    ${code_bg:-#1E293B};
  --color-code-text:  ${code_text:-#E2E8F0};
  --font-body:    'Inter', 'Helvetica Neue', Arial, sans-serif;
  --font-heading: 'Inter', 'Helvetica Neue', Arial, sans-serif;
  --font-mono:    'JetBrains Mono', 'Fira Code', 'Courier New', monospace;
  --font-size:    ${font_size:-16px};
  --line-height:  ${line_height:-1.75};
  --max-width:    ${max_width:-860px};
  --border-radius: ${radius:-6px};
}
EOF
}

# Slug pour le nom de fichier output
get_slug() {
    yaml_get "title" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/-\+/-/g;s/^-//;s/-$//'
}

# Lister les fichiers de contenu dans l'ordre
get_content_files() {
    ls "$ROOT/content/"*.md 2>/dev/null | sort
}

# BUILD HTML
build_html() {
    echo ""
    echo "[BUILD] HTML..."
    local slug
    slug=$(get_slug)
    local outfile="$OUTPUT/$slug.html"

    pandoc \
        $(get_content_files) \
        --to html5 \
        --standalone \
        --template "$ROOT/templates/html.html" \
        --toc \
        --toc-depth=3 \
        --highlight-style breezedark \
        --metadata-file "$CONFIG" \
        --output "$outfile"

    echo "  [OK] $outfile"
    echo "$outfile"
}

# BUILD PDF (via wkhtmltopdf ou weasyprint)
build_pdf() {
    echo ""
    echo "[BUILD] PDF..."
    local slug
    slug=$(get_slug)
    local htmlfile="$OUTPUT/$slug.html"
    local pdffile="$OUTPUT/$slug.pdf"

    [[ -f "$htmlfile" ]] || build_html >/dev/null

    # Copier pdf-overrides.css si présent
    local overrides="$ROOT/assets/css/pdf-overrides.css"
    [[ -f "$overrides" ]] && cp "$overrides" "$OUTPUT/assets/css/pdf-overrides.css"

    if command -v weasyprint >/dev/null 2>&1; then
        if [[ -f "$OUTPUT/assets/css/pdf-overrides.css" ]]; then
            weasyprint "$htmlfile" "$pdffile" \
                --stylesheet "$OUTPUT/assets/css/pdf-overrides.css"
        else
            weasyprint "$htmlfile" "$pdffile"
        fi
        echo "  [OK] $pdffile (weasyprint)"
    elif command -v wkhtmltopdf >/dev/null 2>&1; then
        wkhtmltopdf --enable-local-file-access "$htmlfile" "$pdffile"
        echo "  [OK] $pdffile (wkhtmltopdf)"
    else
        echo "  [SKIP] PDF: installez weasyprint ou wkhtmltopdf"
    fi
}

# ============ MAIN ============
echo "==================================="
echo " Markdown Template — Build Script  "
echo "==================================="

build_theme_css
# Copier les assets dans output/ pour que les chemins relatifs du HTML fonctionnent
mkdir -p "$OUTPUT/assets/css"
cp "$ROOT/assets/css/theme.css" "$OUTPUT/assets/css/theme.css"
[[ -f "$ROOT/assets/css/base.css" ]] && cp "$ROOT/assets/css/base.css" "$OUTPUT/assets/css/base.css"

case "$FORMAT" in
    html) OUT=$(build_html) ;;
    pdf)  build_pdf ;;
    all)  OUT=$(build_html); build_pdf ;;
esac

echo ""
echo "[DONE] Build terminé."

if $OPEN && [[ -n "$OUT" && -f "$OUT" ]]; then
    if command -v xdg-open >/dev/null 2>&1; then xdg-open "$OUT"
    elif command -v open >/dev/null 2>&1; then open "$OUT"
    fi
fi