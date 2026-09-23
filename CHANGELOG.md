# Changelog

## September 23, 2026 - Black Hole v2 motion

- Replace the spiral-to-core position blend with a continuous inward orbit that tightens into a filled sphere without reversing direction or crossing through the center.
- Spin the settled sphere about a fixed upright axis at 720 degrees per second by default. Ease radius and inlet tilt changes, preserve capture progress during speed changes, and keep an optional accretion ring.
- Add opt-in frame tracking on desktop and mobile so fast orbits hold their geometry through velocity constraints while respecting speed limits. Cache the settled core's shared rotation for large part counts.
- Verify spherical volume, capture continuity, release/regrab behavior and actual commanded motion at 30, 60 and 144 Hz in offline fixtures.

## September 23, 2026 — Project UAI controls

- Connect both desktop and mobile PROJECT UAI buttons to the current Gravity context, enabling native engine, shape, targeting, and plugin tools in UAI 1.6.0.
- Publish `_GRAVITY_CONTEXT` after successful initialization so UAI can discover an already-running Gravity session. Unload clears only that session's own handle; reloads expose the new context.
- Complete native desktop/mobile control hooks for Part Control, core and shape keybindings, favorites, interface and visual performance settings, FPS, core color, ignore tags, manual Slingshot actions, and settings reset. Expose a session ID for stable external part references.
- Add mobile shape-switch and keybinding parity, including conflict checks, runtime rebinding, shape shortcuts, and cleanup while retaining existing mobile input action names.
- Share native settings effects and reset behavior through `RuntimeControls.lua`. Reset restores world visuals, frame cap, HUD, scale, hotkeys and late-registered plugin defaults while preserving live settings-table references.
- Refresh Part Control sliders and toggles without replaying callbacks or rebuilding a control during selection changes. Preserve native collision priorities for free physics, shape requests and ride mode when changing collision settings.
- Guard external part assignments after shape-loading yields. Release All also clears unselected ride/physics overrides without a pin/manual/shape mode.
