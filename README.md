# Novus

Roblox combat script with Adonis anticheat bypass.

## Variants

- `novus.lua` — stable release (aimbot, triggerbot, movement, ESP)
- `novus_silent.lua` — silent aim variant

## Features

- **Aimbot** — mouse aim with lock, prediction, FOV, team/distance/visibility checks
- **Silent Aim** — server-side aim spoofing via metatable hooks (Mouse, Camera, Workspace raycasts)
- **Wallbang** — spoofs raycast origin to target position; hits through walls when toggled
- **Trigger Bot** — auto-fire when crosshair over target, hold-click mode
- **Lock Aim** — keeps same target while key held
- **Prediction** — ballistic trajectory compensation (velocity + gravity)
- **ESP** — chams, name, healthbar, box via sirius.menu/sense
- **Movement** — WalkSpeed, JumpPower, ClickTP
- **Adonis Bypass** — upvalue nuking of Detected/NetworkClient
- **Linoria UI** — keybinds, config save/load, themes

## Loadstring

```lua
loadstring(game:HttpGet("http://192.168.1.105:8765/novus_silent.lua"))()
```
