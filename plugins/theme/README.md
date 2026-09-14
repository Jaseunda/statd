# statd-theme

Color themes and custom gradient palette manager for [StatD](https://github.com/Jaseunda/statd).

## Install

```sh
statd install theme
```

## Usage

```sh
# Launch interactive theme picker (use ↑/↓ arrow keys to browse, Enter to apply)
statd theme

# List all premade themes with live visual previews
statd theme list

# View active theme status
statd theme status

# Apply a premade theme
statd theme set cyberpunk
statd theme set tokyonight
statd theme set gruvbox
statd theme set rosepine
statd theme set oceanic
statd theme set emerald
statd theme set sakura
statd theme set stealth
# (or any of the 18 included themes)

# Preview any theme without applying it
statd theme preview tokyonight

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

| Theme | Vibe / Description |
|-------|--------------------|
| `default` | Standard StatD (Green load, Cyan GPU, Magenta Swap) |
| `cyberpunk` | High-contrast Night City (Amber, Cyan, Hot Pink) |
| `nord` | Arctic, Frost blue, and Polar night tones |
| `dracula` | Dark fantasy palette (Purple, Cyan, Emerald) |
| `catppuccin` | Soothing pastel palette (Lavender, Teal, Peach) |
| `tokyonight` | Tokyo nightlife neon (Storm Blue, Cyan, Purple) |
| `gruvbox` | Retro warm groove (Terracotta, Forest, Gold) |
| `rosepine` | Minimalist elegance (Rosé, Pine, Iris, Foam) |
| `matrix` | Pure terminal lime, emerald, and dark green |
| `solarized` | Precision Solarized palette (Cyan, Blue, Amber) |
| `oceanic` | Deep ocean abyss (Marine Blue, Aqua, Sapphire) |
| `sunset` | Fiery sunset gradient (Crimson, Orange, Violet) |
| `crimson` | Molten volcano (Blood Red, Ruby, Scarlet) |
| `emerald` | Lush jade and forest greenery (Mint, Jade, Moss) |
| `sakura` | Japanese cherry blossom (Petal Pink, Blush, Coral) |
| `monokai` | Vibrant coding palette (Lime, Cyan, Magenta) |
| `synthwave` | 80s retro neon aesthetic (Hot Pink, Neon Cyan) |
| `stealth` | Monochrome minimal blackout (Slate, Silver, White) |
