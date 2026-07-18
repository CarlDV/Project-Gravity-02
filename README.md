# Project Gravity. TEST ENVIRONMENT.

Project Gravity is a Roblox script that grabs unanchored parts and moves them around you in different shapes using physics constraints

## Features
- Grabs unanchored parts automatically
- Has over 30 shapes (like Black Hole or Celestial Ribbon)
- Works on both Desktop and Mobile
- Let's you tweak speed, damping, and other physics live
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
