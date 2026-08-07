# Novus

Roblox script with Adonis anticheat bypass. (AI coded, Don't @ me)

## Variants

- `novus.lua` — Legacy Release (less hooks, less AC detection.)
- `novus_silent.lua` — silent aim variant

## Features

- **Aimbot** — mouse aim with lock, prediction, FOV, team/distance/visibility checks
- **Silent Aim** — server-side aim spoofing via metatable hooks (Mouse, Camera, Workspace raycasts)
- **Magic Bullet (New)** — spoofs raycast origin to target position; hits through walls when toggled (only works on some games)
- **Trigger Bot** — auto-fire when crosshair over target
- **Lock Aim** — keeps same target while key held
- **Prediction** — ballistic trajectory compensation (velocity + gravity)
- **ESP** — chams, name, healthbar, box
- **Movement** — WalkSpeed, JumpPower, ClickTP
- **Adonis Bypass** — Works as of 08/04/2026
- **Linoria UI** — keybinds, config save/load, themes

## Loadstrings

```lua
-- Legacy (no silent aim):
loadstring(game:HttpGet("https://raw.githubusercontent.com/D-a-r-n-o-l-d/Novus/master/novus.lua"))()

-- Silent aim + magic bullet:
loadstring(game:HttpGet("https://raw.githubusercontent.com/D-a-r-n-o-l-d/Novus/master/novus_silent.lua"))()
```

Credits to,
  Sense
  
  Linora
  
  Parvus Hub (The OG)
