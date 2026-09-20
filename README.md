# Project Gravity.

Project Gravity is a Roblox script that grabs unanchored parts and moves them around you in different shapes using physics constraints

## Features
- Grabs unanchored parts automatically
- Has 74 active shapes, including 15 new formations designed around uneven disaster debris
- Works on both Desktop and Mobile
- Let's you tweak speed, damping, and other physics live
- Formation controls in the Advanced panel: slow down or reverse the shape's clock, mix two
  shapes together, preview a formation with markers before grabbing anything, sort which part
  gets which slot, cap how many parts are held, and filter what may be claimed by size, name,
  tag or distance
- Saves your settings automatically

### New formations

**[Watch every shape move: 13 GIFs, six shapes per GIF](docs/motion/index.md).**
The gallery covers all 74 active shapes plus the four review modules, with scripted
inputs labeled for interactive tools.

![Six creatures in motion](docs/motion/shapes-01.gif)

The 15 additions are **Abyssal Jellyfish, Void Cathedral, Ouroboros, Hopf Fibration,
Celestial Manta, Megalodon, World Tree, Ragnarok Hammer, Eclipse Scythe, Aegis Bastion,
Singularity Trident, Ghost Galleon, Infernal Skull, Chrono Hourglass, and Storm Gyre**.
Find them by name in the desktop or mobile shape selector.

They use compact silhouettes, deterministic part placement, and broad structural
features for Natural Disaster Survival's mixed bricks, beams and wall panels.
**Debris Scale %** starts at 55; reduce it when there is less rubble to fill the shape.
The formation keeps a small shared orbit even when its pattern speed or Formation
Time Scale is zero. The six earlier showcase formations and the improved Torus Knot,
Klein Bottle and Möbius Strip also use this continuous motion.

**[Formation guide, images and math improvements](docs/FORMATIONS.md)** includes the
dense and sparse debris galleries, controls, and the details of Phoenix banking,
complete stacked Rift mouths, even-speed torus links, and continuous surface seams.
The previews show actual module trajectories in a synthetic debris fixture; live
Roblox physics and network ownership still depend on the game session.

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
- `shapes-onreview/`: Four experimental modules, labeled separately in the motion gallery
- `docs/`: Formation guide, debris images, and the complete motion gallery
- `tools/`: Reproducible previews and a Lune adapter for the test suites
- `/mobilever`: The UI and stuff for mobile users ,ex UI

## Shape validation

Use [Lune](https://github.com/lune-org/lune) to run the suites in Luau, including
modules using `continue` and Unicode filenames:

```powershell
lune run tools/test_luau.luau tests/insane_shapes_smoke.lua
lune run tools/test_luau.luau tests/math_curves_smoke.lua
lune run tools/test_luau.luau tests/formation_smoke.lua
```

These cover geometry, control limits, mixed part sizes, timing, continuously moving
frozen poses, late claims, cleanup, topology and desktop/mobile runtime behavior.

Rebuild the motion gallery with Python, Pillow and Lune:

```powershell
python tools/preview_shapes.py --all --parts 384 --frames 72 --duration 6 --output docs/motion
```

Pass `--lune PATH` if Lune is not on PATH. [The gallery index](docs/motion/index.md)
records the demonstration settings and explains the scripted inputs.

---
JUN 25 : 12:12AM GMT+8 (PHT)
