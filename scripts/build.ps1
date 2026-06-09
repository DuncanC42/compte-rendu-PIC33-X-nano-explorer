# =============================================================
#  BUILD.PS1 — Script de build PowerShell
#  Usage : .\scripts\build.ps1 [-Format html|pdf|all] [-Open]
# =============================================================
param(
    [ValidateSet("html","pdf","all")]
    [string]$Format = "html",
    [switch]$Open
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$Config = "$Root\config\project.yaml"
$Output = "$Root\output"

# Vérifier les dépendances
if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) {
    Write-Error "Pandoc n'est pas installé. Téléchargez-le sur https://pandoc.org/installing.html"
    exit 1
}

# Charger la config YAML (mini-parser pour les valeurs de base)
function Get-YamlValue($file, $key) {
    $lines = Get-Content $file | Where-Object { $_ -match "^\s*${key}:\s*" }
    if ($lines) {
        return ($lines[0] -replace "^\s*${key}:\s*[`"']?(.+?)[`"']?\s*$", '$1').Trim()
    }
    return ""
}

# Générer theme.css depuis les valeurs du projet
function Build-ThemeCSS {
    $yaml = Get-Content $Config -Raw

    # Extraire les valeurs du bloc theme avec regex
    $extractColor = { param($name)
        if ($yaml -match "${name}:\s*[`"']?(#[0-9A-Fa-f]{3,8}|[a-z]+\([^)]+\)|[a-z]+)[`"']?") { $Matches[1] }
        else { "" }
    }

    $primary    = & $extractColor "primary"
    $secondary  = & $extractColor "secondary"
    $accent     = & $extractColor "accent"
    $text       = & $extractColor "text"
    $text_muted = if ($yaml -match "text_muted:\s*[`"']?(#[0-9A-Fa-f]{3,8})[`"']?") { $Matches[1] } else { "#6B7280" }
    $bg         = & $extractColor "bg"
    $bg_alt     = if ($yaml -match "bg_alt:\s*[`"']?(#[0-9A-Fa-f]{3,8})[`"']?") { $Matches[1] } else { "#F8FAFC" }
    $border     = & $extractColor "border"
    $code_bg    = if ($yaml -match "code_bg:\s*[`"']?(#[0-9A-Fa-f]{3,8})[`"']?") { $Matches[1] } else { "#1E293B" }
    $code_text  = if ($yaml -match "code_text:\s*[`"']?(#[0-9A-Fa-f]{3,8})[`"']?") { $Matches[1] } else { "#E2E8F0" }

    $font_size   = if ($yaml -match "font_size:\s*[`"']?([0-9]+px)[`"']?") { $Matches[1] } else { "16px" }
    $line_height = if ($yaml -match "line_height:\s*[`"']?([0-9.]+)[`"']?") { $Matches[1] } else { "1.75" }
    $max_width   = if ($yaml -match "max_width:\s*[`"']?([0-9]+px)[`"']?") { $Matches[1] } else { "860px" }
    $radius      = if ($yaml -match "border_radius:\s*[`"']?([0-9]+px)[`"']?") { $Matches[1] } else { "6px" }

    $css = @"
/* AUTO-GÉNÉRÉ depuis config/project.yaml — ne pas modifier manuellement */
:root {
  --color-primary:    $primary;
  --color-secondary:  $secondary;
  --color-accent:     $accent;
  --color-text:       $text;
  --color-text-muted: $text_muted;
  --color-bg:         $bg;
  --color-bg-alt:     $bg_alt;
  --color-border:     $border;
  --color-code-bg:    $code_bg;
  --color-code-text:  $code_text;
  --font-body:    'Inter', 'Helvetica Neue', Arial, sans-serif;
  --font-heading: 'Inter', 'Helvetica Neue', Arial, sans-serif;
  --font-mono:    'JetBrains Mono', 'Fira Code', 'Courier New', monospace;
  --font-size:    $font_size;
  --line-height:  $line_height;
  --max-width:    $max_width;
  --border-radius: $radius;
}
"@
    $css | Set-Content "$Root\assets\css\theme.css" -Encoding utf8
    Write-Host "  [OK] theme.css généré"
}

# Collecter les fichiers de contenu dans l'ordre
function Get-ContentFiles {
    Get-ChildItem "$Root\content\*.md" | Sort-Object Name | ForEach-Object { $_.FullName }
}

# Slug pour le nom de fichier output
function Get-OutputSlug {
    $title = Get-YamlValue $Config "title"
    if (-not $title) { $title = "document" }
    $slug = $title.ToLower() -replace "[^a-z0-9]", "-" -replace "-+", "-"
    return $slug.Trim("-")
}

# ---- BUILD HTML ----
function Build-HTML {
    Write-Host "`n[BUILD] HTML..."
    $slug = Get-OutputSlug
    $outFile = "$Output\$slug.html"
    $contentFiles = Get-ContentFiles

    $pandocArgs = @(
        $Config,                          # Métadonnées du projet
        $contentFiles,                    # Fichiers de contenu
        "--to", "html5",
        "--standalone",
        "--template", "$Root\templates\html.html",
        "--toc",
        "--toc-depth=3",
        "--highlight-style", "breezedark",
        "--metadata-file", $Config,
        "--output", $outFile
    )

    & pandoc @pandocArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] $outFile"
    } else {
        Write-Error "  Pandoc a échoué (HTML)"
    }

    return $outFile
}

# ---- BUILD PDF ----
function Build-PDF {
    $wkhtml = Get-Command wkhtmltopdf -ErrorAction SilentlyContinue
    $weasyprint = Get-Command weasyprint -ErrorAction SilentlyContinue

    if (-not $wkhtml -and -not $weasyprint) {
        Write-Warning "PDF: wkhtmltopdf ou weasyprint requis. Génération HTML uniquement."
        return
    }

    Write-Host "`n[BUILD] PDF..."
    $slug = Get-OutputSlug
    $htmlFile = "$Output\$slug.html"
    $pdfFile  = "$Output\$slug.pdf"

    if (-not (Test-Path $htmlFile)) { Build-HTML | Out-Null }

    if ($wkhtml) {
        & wkhtmltopdf --enable-local-file-access --print-media-type $htmlFile $pdfFile
    } elseif ($weasyprint) {
        & weasyprint $htmlFile $pdfFile
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] $pdfFile"
    }
}

# ============ MAIN ============
Write-Host "==================================="
Write-Host " Markdown Template — Build Script  "
Write-Host "==================================="

Build-ThemeCSS

switch ($Format) {
    "html" { $out = Build-HTML }
    "pdf"  { Build-PDF }
    "all"  { $out = Build-HTML; Build-PDF }
}

Write-Host "`n[DONE] Build terminé."

if ($Open -and $out -and (Test-Path $out)) {
    Start-Process $out
}
