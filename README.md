# Project Gravity.

Project Gravity is a Roblox script that grabs unanchored parts and moves them around you in different shapes using physics constraints

## Features
- Grabs unanchored parts automatically
- Has over 50 shapes (like Black Hole or Celestial Ribbon)
- Works on both Desktop and Mobile
- Let's you tweak speed, damping, and other physics live
- Formation controls in the Advanced panel: slow down or reverse the shape's clock, mix two
  shapes together, preview a formation with markers before grabbing anything, sort which part
  gets which slot, cap how many parts are held, and filter what may be claimed by size, name,
  tag or distance
- Saves your settings automatically

### New formations

| Shape | What it does |
| --- | --- |
| Astral Kraken | A breathing mantle with eight curling, tapered tentacles and raised eyes. |
| Phoenix Ascendant | Sweeping feathered wings, a crowned head, and five flowing tail streamers. |
| Cosmic Lotus | Layers of pointed petals bloom around a floating core and rotate in opposite directions. |
| Rift Gate | Two rotating irises connected by a twisting, breathing wormhole. |
| Reality Shatter | Twenty triangular shards burst apart, tumble, and reform around a central core. |
| Hypercube Nexus | A rotating five-dimensional cube projects 80 connected edges into nested, pulsing cages. |

Find them by name in the shape selector on desktop or mobile. Each has controls for
size, motion and its defining features. Try Formation Preview in the Advanced panel;
several hundred held parts bring out the feathers, petals and shard surfaces. Setting
a shape's speed to zero holds its current pose; Formation Time Scale also supports
freezing and reversing these animations. They work with Shape Blend and slot ordering.

## Usage
Just run `main.lua` in your executor. It pulls the rest of the files directly from GitHub

The **PROJECT GRAVITY AI** button launches [Project UAI](https://github.com/CarlDV/ProjectUAI) on demand.

### Controls
- **E**: Start script (grabs parts)
- **Q**: Stop script (drops parts)
- **P**: Pause parts
- **L**: Disable constraints entirely
- **Left Click**: Hold the anchor to move the center around with your mouse

## Directory
- `main.lua`: The loader
- `System.lua`: Runs the physics math and loops
- `config.lua`: Default settings and shape variables
- `UI.lua` / `UI_elements.lua`: The UI stuff
- `shapes/`: The math for how each shape is positioned
- `/mobilever`: The UI and stuff for mobile users ,ex UI

## Shape validation

Run `luajit tests/insane_shapes_smoke.lua` from the repository root to check the six
new formations. It checks geometry, control limits, preview slots, animation timing,
late claims and cleanup using the local Roblox math stubs.

---
JUN 25 : 12:12AM GMT+8 (PHT)
