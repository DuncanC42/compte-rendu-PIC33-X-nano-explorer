# Markdown Template

Template Markdown modulaire et customisable. Un seul fichier à modifier par projet.

## Architecture

```
markdown-templates/
├── config/
│   └── project.yaml          ← MODIFIER CE FICHIER par projet
├── partials/
│   ├── _cover.md             ← Page de couverture
│   ├── _header.md            ← En-tête
│   └── _footer.md            ← Pied de page
├── content/
│   ├── 01-introduction.md    ← Contenu (ordonné par préfixe)
│   ├── 02-body.md
│   └── 03-conclusion.md
├── assets/
│   ├── images/               ← Logo, illustrations
│   └── css/
│       ├── base.css          ← Structure (ne pas toucher)
│       └── theme.css         ← Généré automatiquement depuis project.yaml
├── templates/
│   └── html.html             ← Template Pandoc
├── scripts/
│   ├── build.ps1             ← Build Windows
│   └── build.sh              ← Build Linux/macOS
└── output/                   ← Fichiers générés (gitignored)
```

## Démarrage rapide

### 1. Personnaliser le projet

Éditez **uniquement** `config/project.yaml` :

```yaml
title: "Mon Document"
subtitle: "Sous-titre"
author: "Votre Nom"
recipient_name: "Client"
recipient_company: "Entreprise Client"

theme:
  primary: "#2563EB"    # Couleur principale
  accent:  "#F59E0B"    # Couleur d'accentuation
```

### 2. Ajouter votre contenu

Placez vos fichiers `.md` dans `content/` avec un préfixe numérique pour l'ordre :

```
content/
  01-contexte.md
  02-analyse.md
  03-proposition.md
  04-budget.md
```

### 3. Builder

**Windows (PowerShell) :**
```powershell
.\scripts\build.ps1 -Format html -Open
.\scripts\build.ps1 -Format pdf
.\scripts\build.ps1 -Format all
```

**Linux / macOS :**
```bash
bash scripts/build.sh html --open
bash scripts/build.sh pdf
make all
```

Le fichier généré apparaît dans `output/`.

## Prérequis

| Outil | Obligatoire | Usage |
|-------|:-----------:|-------|
| [Pandoc](https://pandoc.org) | Oui | Conversion Markdown → HTML/PDF |
| [wkhtmltopdf](https://wkhtmltopdf.org) | Non | Génération PDF |
| [weasyprint](https://weasyprint.org) | Non | Alternative PDF (meilleur CSS) |

## Customisation par projet

### Changer le thème visuel

Tout passe par `config/project.yaml` → section `theme` :

```yaml
theme:
  primary:    "#DC2626"    # Rouge pour un projet urgent
  secondary:  "#78716C"
  accent:     "#EA580C"
  bg:         "#FFFBEB"    # Fond légèrement chaud
```

Le script de build génère `assets/css/theme.css` automatiquement.

### Ajouter un logo

Déposez votre logo dans `assets/images/logo.png` et pointez-y dans la config :

```yaml
logo: "./assets/images/logo.png"
```

### Désactiver des composants

```yaml
layout:
  cover_page: false     # Pas de page de couverture
  toc: false            # Pas de table des matières
  header: false         # Pas de header
  footer: true
```

### Ajouter des sections de contenu

Créez un fichier `content/04-annexes.md` — il sera automatiquement inclus dans l'ordre.

## Workflow GitHub

```bash
# Cloner pour un nouveau projet
git clone <repo> nom-du-projet
cd nom-du-projet

# Créer une branche par destinataire/version
git checkout -b client-abc/v1

# Modifier config/project.yaml + contenu
# Builder et livrer
bash scripts/build.sh all
```

## Licence

MIT — libre d'utilisation et de modification.
