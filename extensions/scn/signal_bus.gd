extends "res://scn/signal_bus.gd"

## Emitted whenever map size / opacity / Diablo mode changes, so the mod's
## map controller can re-apply the minimap layout.
signal map_display_changed
