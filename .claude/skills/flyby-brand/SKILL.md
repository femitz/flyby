---
name: flyby-brand
description: Flyby visual identity ("direção Órbita"): palette, typography, logo, voice and UI component rules. Use when designing or changing any Flyby UI (panel, preferences, icons, README/website visuals), picking colors or fonts, writing UI copy, or reviewing whether a screen follows the brand.
---

# Flyby brand — direção Órbita

**Tagline:** "Telemetria do seu Mac, de passagem."

Inspired by Artemis II and its free-return trajectory: the spacecraft passes the Moon, reads what it needs and
comes back home. Flyby does the same for the Mac: a quick look at CPU, memory, temperature and per-app volume,
then back to what you were doing.

## Principles

1. **De relance** — everything readable in two seconds. If it needs explaining, it is not ready.
2. **Sinal, não ruído** — thin lines, mono numbers, no decoration. Mission telemetry, not a game HUD.
3. **Um só acento** — orange (Ignição) is the spacecraft: it marks *where something happens* (the tip of a gauge,
   a slider fill, the dot of the logo). Everything else is moon and vacuum. Never use it as a large fill in the
   panel, never add a second accent.

## Palette (`Sources/Flyby/Design/Brand.swift`)

| Name | Hex | Use |
|---|---|---|
| Vácuo | `#0B0E14` | background |
| Casco | `#151A24` | surfaces (the panel) |
| Órbita | `#2A3142` | lines, tracks, tiles, hover fill |
| Poeira | `#8A93A6` | secondary text, captions |
| Lua | `#E6E8EE` | text, the mark |
| Ignição | `#FF6B2C` | the single accent |

Extras used by the panel: `#A9B0BF` (soft text, values) and `#4A5266` (fill of a muted slider).
The panel is **dark only** (no light theme).

## Typography

- **Geist** — interface and titles (400 / 500 / 600). Title tracking is slightly negative (−0.03em).
- **Geist Mono** — numbers, telemetry, captions. Section captions are UPPERCASE mono 11pt, 0.14em tracking.
- Until the fonts are bundled the app uses the system UI face and the system monospaced face through
  `Brand.sans` / `Brand.mono`; never reference `Font.system` directly in views — go through `Brand`.

## Logo

A comet-like trail that curls around a bright head (`FlybyGlyph` in `Sources/Flyby/Utilities/AppIcon.swift`,
drawn in a 120×120 box). The dot at the start of the trail is the accent.

- App icon variations: **Vácuo** (default, dark tile), **Lua** (light tile), **Ignição** (accent tile).
- Use heavier stroke weights at small sizes (`GlyphWeight`): regular for large, medium ≈ 64pt, heavy for ≤ 32pt
  and the menu bar.
- **Menu bar:** always the monochrome template glyph so macOS tints it; optionally followed by CPU % in mono.
- The Finder icon (`Resources/App/Flyby.icns`) is static (Vácuo); regenerate with `scripts/generate-icns.sh`.

## Panel components

- Panel: 380pt wide, Casco surface, 1px Órbita border, 16pt radius, 20pt padding, 20pt between sections,
  1px Órbita dividers between sections.
- **Telemetry ring** (`TelemetryRing`): 88pt, 5pt track in Órbita, Lua arc with round caps, 10pt Ignição dot at the
  tip, mono value inside, label (13pt medium) and mono detail (11pt Poeira) below.
- **Mixer row** (`MixerRow`): 32pt Órbita tile with initials, name + mono value, 4pt slider with Ignição fill and a
  14pt Lua thumb, 44pt mute button. Muted rows drop to 60% opacity, fill `#4A5266`, value reads "mudo".
- **Buttons** (`BrandButtonStyle`): text only, 44pt minimum hit target, Órbita fill on hover.
- Toggles use the system switch tinted Ignição.

## Voice (UI copy)

Portuguese (pt-BR), short, mission-control flavored but never cute: "Tempo de missão" (T+ = time since boot),
"Telemetria", "Mixer", "Sinal estável", "Preferências", "Sair". Numbers in mono, units after a space ("5 s",
"6,6 / 8 GB"). No exclamation marks, no emoji.

## Do / don't

- Do keep one accent, thin lines and generous spacing; do keep every control reachable at 44pt.
- Don't add gradients, glows, drop shadows inside the panel, or colored status fills (green/yellow/red).
- Don't introduce new colors; extend the palette here first.
