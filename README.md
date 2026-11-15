<h1 align="center">Bomb Site</h1>

<p align="center">
  <a href="https://www.youtube.com/watch?v=0xiqKXp8d5c"><img src="https://img.youtube.com/vi/0xiqKXp8d5c/maxresdefault.jpg" alt="Watch on YouTube" width="600"></a>
</p>

## 📝 Description
This plugin gives full control over bomb sites in Counter-Strike 1.6.
Bomb sites can be created, removed and toggled on or off during gameplay, with runtime control over radar visibility, activation chance and timing.
Custom setups are saved per map and automatically loaded on every map start.
- Create and remove bomb sites during gameplay via an in-game menu
- A C4 HUD sprite marks each bomb site's location instead of a map decal
- Sprite color changes dynamically based on the site's active/inactive state
- Configurable per site: flags, radar visibility, activation chance, activation delay, duration and cooldown
- Radar visibility can be restricted to Terrorists, CTs, both teams, or disabled entirely
- Independent axis scaling with an Add/Remove mode toggle and factor control for precise box resizing
- Noclip for players while placing bomb sites, for easier and more accurate positioning
- Optional support for plantable C4 on every map/mode, not just bomb-defusal maps
- [color=red]Requires AMX Mod X 1.9.0+[/color]

## 💬 Commands
- `say /bs` - Opens the Bomb Site menu.
- `say_team /bs` - Opens the Bomb Site menu.
- `say /bombsite` - Opens the Bomb Site menu.
- `say_team /bombsite` - Opens the Bomb Site menu.
- `bs_reload` - Reloads the configuration file.
- `bomesite_reload` - Reloads the configuration file.

## ⚙️ Configuration
```ini
# [Main Settings]
# SETTING_DEFAULT_FLAGS           = Default flags (a - Radar, b - Icon, c - Active Delay, d - Active Duration)
# SETTING_DEFAULT_RADAR           = Default radar visibility (0 - Disabled, 1 - Terrorists Only, 2 - CT Only, 3 - Both Teams)
# SETTING_DEFAULT_ACTIVE_CHANCE   = Default probability the site activates each round (0.0 - 1.0)
# SETTING_DEFAULT_ACTIVE_DELAY    = Default random delay before the site goes active (min - max)
# SETTING_DEFAULT_ACTIVE_DURATION = Default duration the site stays active (min - max)
# SETTING_DEFAULT_ACTIVE_COOLDOWN = Default cooldown before the site can reactivate (min - max)
# SETTING_DEFAULT_ICON            = Default path to the bomb site's icon sprite
# SETTING_DEFAULT_ICON_SCALE      = Default icon scale
# SETTING_DEFAULT_ICON_ALPHA      = Default icon alpha
# Per-site settings (defined under each [Bomb Site Name] section):
# BOMB_FLAGS   = a - Radar, b - Icon, c - Active Delay, d - Active Duration
# BOMB_RADAR   = 0 - Disabled, 1 - Terrorists Only, 2 - CT Only, 3 - Both Teams
```

## 🔄 Changelog
```text
* v1.0: Initial release.
* v1.1: Optimized code, sites can be expanded without being blocked by other objects, a C4 HUD sprite is used to indicate the location of a bomb site instead of a decal, bomb sites can be used with plantable C4 on every map/mode.
* v1.2: Sprite color changes based on state, radar visibility can be configured for Terrorists, CTs, both teams or disabled.
* v1.3: Added independent axis scaling, mode toggle (Add/Remove), and factor control for precise box resizing, added noclip for players placing Bomb Sites for easier positioning.
* v1.4: Bug fixes and config improvements.
* v1.5: Added per-Bomb Site configuration.
* v1.6: Added FLAG_ACTIVE_DURATION, improved round-start logic.
```
