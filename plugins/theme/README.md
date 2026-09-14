# statd-theme

Color themes and custom gradient palette manager for [StatD](https://github.com/Jaseunda/statd).

## Install

```sh
statd install theme
```

## Usage

```sh
# View current theme and active metric colors
statd theme

# List all premade themes with live visual previews
statd theme list

# Apply a premade theme
statd theme set cyberpunk
statd theme set nord
statd theme set dracula
statd theme set catppuccin
statd theme set matrix
statd theme set sunset
statd theme set monokai
statd theme set synthwave

# Preview any theme without applying it
statd theme preview cyberpunk

# Customize an individual metric color
statd theme set-color gpu amber
statd theme set-color cpu matrix
statd theme set-color gpu 0,255,200:0,100,255   # Custom RGB gradient

# Create a custom named theme
statd theme create mytheme

# Reset to default
statd theme reset
```

## Included Themes

| Theme | Vibe |
|-------|------|
| `default` | Standard StatD (Green load, Cyan GPU, Magenta Swap) |
| `cyberpunk` | High-contrast Night City (Amber, Cyan, Hot Pink) |
| `nord` | Arctic, Frost blue, and Polar night tones |
| `dracula` | Dark fantasy palette (Purple, Cyan, Emerald) |
| `catppuccin` | Soothing pastel palette (Lavender, Teal, Peach) |
| `matrix` | Pure terminal lime, emerald, and dark green |
| `sunset` | Fiery sunset gradient (Crimson, Orange, Violet) |
| `monokai` | Vibrant coding palette (Lime, Cyan, Magenta) |
| `synthwave` | 80s retro neon aesthetic (Hot Pink, Neon Cyan) |
