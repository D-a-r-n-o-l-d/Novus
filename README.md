# Novus

Combat utility for Roblox. Linoria UI, Adonis bypass, config save/load.

## Files

| File | Description |
|------|-------------|
| `novus.lua` | Stable build — aimbot, triggerbot, ESP, movement, visuals. No silent aim. |
| `novus_silent.lua` | Silent aim build — adds aimpoint-based silent aim via metatable hooks. |

## Loadstring

Stable:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/D-a-r-n-o-l-d/Novus/master/novus.lua"))()
```

Silent aim:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/D-a-r-n-o-l-d/Novus/master/novus_silent.lua"))()
```

## Features

- Aimbot (mouse + camera) with prediction, lock aim, FOV
- Triggerbot with fire rate, hold click
- Silent aim — metatable hooks (Raycast, ScreenPointToRay, FindPartOnRay, Mouse Target/Hit)
- ESP via Sense — box, name, healthbar, chams, distance
- Adonis anticheat bypass
- ClickTP, movement options
- Config save/load, theme manager

## Credits

- **Parvus Hub** (AlexR32) — silent aim hook structure and method implementations
- **Linoria** — UI library
- **Sense** — ESP framework

## Keybinds

Defaults:
- `RightShift` — toggle menu
- Manual keybind setup for aimbot, triggerbot, etc.
