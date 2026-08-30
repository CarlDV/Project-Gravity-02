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

## Usage
Just run `main.lua` in your executor. It pulls the rest of the files directly from GitHub

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

---
JUN 25 : 12:12AM GMT+8 (PHT)
