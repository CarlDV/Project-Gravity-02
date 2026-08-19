return {
	x1 = {
		k1 = 2000,
		k2 = Vector3.new(5, 5, 5),
		k3 = Color3.fromRGB(255, 105, 180),
		k4 = math.huge,
		k5 = { "NoAttract", "Character" },
		k6 = "Celestial Ribbon",
		k7 = 4,
		k8 = 0.8,
		k9 = 80,
		k10 = 20,
		k11 = 2,
		k12 = 100,
		k13 = 10,
		k14 = 5,
		k15 = 10,
		k16 = 0.6,
		k17 = 150,
		Targets = {},
		IsLaunching = false,
		Disabled = false,
		TgtActive = false,
		PI_All = false,
		AnchorSelf = false,
		AntiFling = false,
		PreserveCollisions = false,
		PredictiveTracking = true,
		PredictionFactor = 150,
		ShowHUD = true,
		-- load_settings only restores a saved value when a default of the same
		-- type is already here, and reset_config only restores what it snapshotted
		-- from this table. A key the UI writes but this table omits therefore both
		-- forgets itself between sessions and survives "Reset All Settings".
		SimpleMode = false,
		-- Written by the mobile Advanced panel and read by main.lua's setfpscap call.
		-- With no default here load_settings could never restore it -- it only
		-- restores a key that already exists with a matching type -- so the cap
		-- reverted to 60 every launch, and reset_config never snapshotted it either,
		-- so it survived "Reset All Settings". Exactly the failure the note above
		-- describes.
		FPSCap = 60,
		-- The touch substitute for holding Shift in the sculptor. Read by
		-- System_sculptor on the mobile tree; it had no writer and no default at all,
		-- so it was permanently false and a touch user could never deselect a part or
		-- add to a selection.
		SculptorMultiSelect = false,
		Perf_DisableShadows = false,
		Perf_DisablePostFX = false,
		Perf_PotatoMaterials = false,
		Perf_HideParticles = false,
		SlingshotManual = false,
		AggressiveClaim = false,
		["Force Smooth (Lags)"] = false,
		["Realistic Liftoff"] = false,
		Paused = false,
		Damping = 0.5,
		Ki = 0.1,
		MaxSpeed = 500,
		AngularDamping = 0.5,
		VerticalStiffness = 1.0,
		VoidProtection = true,
		UIScale = 1.0,
		-- Key names, not KeyCodes: an EnumItem does not survive the JSON round
		-- trip, and load_settings only restores a value whose type matches the
		-- default. "" is a real value here and means deliberately unbound.
		-- Shapes maps a shape name to a key that switches straight to it.
		Keybinds = {
			Recenter = "E",
			Reset = "Q",
			Pause = "P",
			Disable = "L",
			Shapes = {},
		},
	},
	x2 = {
		["Pulsar Vortex"] = { k11 = 200, k12 = 8, k13 = 10, k14 = 0, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Big Ring Things"] = { k12 = 100, k13 = 10, k14 = 5, k16 = 0.6, k15 = 10, k11 = 2, k17 = 150, k23 = false },
		["Celestial Ribbon"] = { k12 = 0, k13 = 15, k14 = 30, k16 = 0.4, k11 = 1, k17 = 150, k18 = false, k19 = 2, k23 = false },
		["Hollow Worm"] = { k12 = 0, k13 = 15, k14 = 35, k16 = 0.4, k15 = 10, k11 = 15, k17 = 150, k23 = false },
		["Cosmic Comet"] = { k12 = 50, k13 = 20, k14 = 20, k16 = 0.5, k15 = 5, k11 = 5, k17 = 150, k23 = false },
		["Point Impact"] = {},
		["Domain Expansion Infinite Void"] = { k11 = 90, k12 = 0, k13 = 15, k14 = 0, k15 = 0, k16 = 0, k23 = false, k18 = true, k19 = true },
		["Vortex Funnel"] = { k11 = 50, k12 = 300, k13 = 30, k14 = 400, k15 = 5, k16 = 0, k23 = false },
		["Quantum Atoms"] = { k11 = 60, k12 = 0, k13 = 15, k14 = 0, k15 = 3, k16 = 0, k23 = false },
		["Halo Ring"] = { k11 = 40, k12 = 0, k13 = 5, k14 = 80, k15 = 0, k16 = 0, k17 = 50, k23 = false },
		["Slingshot"] = { k11 = 50, k12 = 3, k13 = 100, k14 = 0, k15 = 5, k16 = 0, k17 = 100, k23 = false },
		["Gods Call"] = { k11 = 10, k12 = 0, k13 = 0, k14 = 0, k15 = 0, k16 = 0, k17 = 50, k23 = false },
		["Shield Wall"] = { k11 = 20, k12 = 25, k13 = 20, k14 = 50, k15 = 10, k16 = 0, k17 = 50, k23 = false },
		["Sculptor"] = { k11 = 0, k12 = 0, k13 = 0, k14 = 0, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Torus Knot"] = { k11 = 3, k12 = 2, k13 = 10, k14 = 50, k15 = 20, k16 = 0, k17 = 0, k23 = false },
		["Möbius Strip"] = { k11 = 50, k12 = 20, k13 = 15, k14 = 0, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["DNA Helix"] = { k11 = 20, k12 = 80, k13 = 10, k14 = 50, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Black Hole"] = { k11 = 40, k12 = 100, k13 = 15, k14 = 50, k15 = 5, k16 = 0, k17 = 0, k23 = false },
		["Dense Spin"] = { k11 = 50, k12 = 2 },
		["Tesseract"] = { k11 = 40, k12 = 80, k13 = 10, k14 = 50, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Klein Bottle"] = { k11 = 60, k12 = 20, k13 = 20, k14 = 0, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Space Station"] = { k11 = 80, k12 = 30, k13 = 10, k14 = 150, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Supernova"] = { k11 = 15, k12 = 100, k13 = 25, k14 = 50, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Dyson Sphere"] = { k11 = 150, k12 = 8, k13 = 10, k14 = 0, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Seraphim"] = { k11 = 80, k12 = 4, k13 = 15, k14 = 40, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Alien Mothership"] = { k11 = 120, k12 = 40, k13 = 15, k14 = 200, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Cursed Technique Red"] = { k12 = 100 },
		["ROOM Ope Ope no Mi"] = { k11 = 150, k12 = 2, k13 = 1.5, k14 = 20, k18 = true },
		["Light Light no Mi"] = { k11 = 150, k12 = 400, k13 = 3, k14 = 2, k18 = true },
		["Quantum Core"] = { k11 = 100, k12 = 30, k13 = 40, k14 = 50, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Galactic Web"] = { k11 = 400, k12 = 10, k13 = 5, k14 = 0, k15 = 0, k16 = 0, k17 = 0, k23 = false, k24 = 200 },
		-- k14/k15/k16 carry Div = 10, so the value here is what the shape reads and
		-- the panel shows it ten times larger. Written pre-multiplied these were
		-- ten times too big: 3 displayed as 30 against a 1..20 slider, so the first
		-- time the panel opened UI.lua:1223-1225 clamped it and wrote back 2.
		["Quantum Entanglement"] = { k11 = 50, k12 = 100, k13 = 200, k14 = 0.3, k15 = 0.2, k16 = 0.5 },
		["Meteor Shower"] = { k11 = 500, k12 = 300, k13 = 150, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["World Serpent"] = { k11 = 400, k12 = 100, k13 = 20, k14 = 20, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Aurora Borealis"] = { k11 = 600, k12 = 300, k13 = 15, k14 = 100, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Arcane Orrery"] = { k11 = 120, k12 = 4, k13 = 8, k14 = 200, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Maelstrom Spire"] = { k11 = 30, k12 = 200, k13 = 15, k14 = 6, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Eldritch Binding"] = { k11 = 100, k12 = 200, k13 = 5, k14 = 8, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Graviton Engine"] = { k11 = 4, k12 = 60, k13 = 12, k14 = 200, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Fractal Web"] = { k11 = 40, k12 = 3, k13 = 3, k14 = 5, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Leviathan Coil"] = { k11 = 50, k12 = 15, k13 = 8, k14 = 250, k15 = 0, k16 = 0, k17 = 0, k23 = false },
		["Spinning Cube"] = { k11 = 40, k12 = 200, k13 = false, k14 = false, k15 = true },
		["Twin Core Beam"] = { k11 = 80, k12 = 15, k13 = 150, k14 = 900, k15 = 4, k18 = false },
		-- k18 must stay a string: load_settings only restores a saved value when the
		-- default has the same type, so a number here would silently drop the message.
		["Hover Text"] = { k18 = "HELLO", k11 = 6, k12 = 30, k13 = 15, k14 = 0.8, k15 = 2, k16 = 0, k19 = true },
		-- Every key a shape's Controls touch has to exist here with its final
		-- type: load_settings only restores a saved value when the default has
		-- the same type, so a missing key can never be restored and a boolean
		-- written as a number silently drops. k19..k22, k32, k48, k55, k57 and
		-- k58 are toggles and must stay booleans.
		["Platform"] = {
			k11 = 8, k12 = -3, k13 = 12, k14 = 3, k15 = 0, k16 = 1, k17 = 0, k18 = 1,
			k19 = true, k20 = false, k21 = false, k22 = true,
			k23 = 1.0, k24 = 0, k25 = 0, k26 = 0.6, k27 = 6, k28 = 0,
			k29 = 1.2, k30 = 1.0, k31 = 0, k32 = false, k33 = 1, k34 = 0, k35 = 0.6,
			k36 = 1, k37 = 1, k38 = 0, k39 = 80, k40 = 5, k41 = 6, k42 = 250, k43 = 24,
			k44 = 0, k45 = 100, k46 = 0, k47 = 1, k48 = false, k49 = 60, k50 = 3,
			k51 = 0, k52 = 16, k53 = 0.5, k54 = 0.5, k55 = false, k56 = 60,
			k57 = false, k58 = false, k59 = 0,
		},
		-- k12/k13/k20 are enum pickers rendered as integer sliders (no Dropdown
		-- control exists), k21 is a toggle and must stay a boolean, and k14 carries
		-- Div = 10, so the value stored here is what the shape reads -- the UI
		-- multiplies by Div for display and divides on the way back, so a default
		-- written pre-multiplied would be ten times too big.
		["Rocket Engine"] = {
			k11 = 120, k12 = 1, k13 = 1, k14 = 15, k15 = 10, k16 = 18,
			k17 = 45, k18 = 60, k19 = 10, k20 = 1, k21 = false, k22 = 4,
		},
		-- k14 and k15 are toggles and must stay booleans. k11 carries Div = 10.
		-- k18 (Motion Gain) and k19 (Tilt Track) carry Div = 100, so 1 here is the
		-- 100 the panel shows: the mech mirrors your live pose exactly. They used to
		-- drive a synthetic walk cycle, which is what stopped the suit from tracking
		-- the character.
		["Mech Suit"] = {
			k11 = 2, k12 = 30, k13 = 2, k14 = false, k15 = true, k16 = 1200,
			k17 = 0, k18 = 1, k19 = 1,
		},
		["Big Bad Broom"] = {
			k11 = 60, k12 = 30, k13 = 35, k14 = 25, k15 = 1,
			k16 = 2, k17 = 8, k18 = 10, k19 = 3,
		},
		-- Lag Tree pair. k14 and k16 on Meteor Hammer carry Div = 10, so the
		-- stored 0.8 and 1.2 show as 8 and 12 on the panel (UI.lua:1223-1225).
		["Meteor Hammer"] = {
			k11 = 90, k13 = 60, k14 = 0.8, k15 = 60, k16 = 1.2,
			k17 = 16, k18 = 4, k19 = 55,
		},
		["Mochi Mochi no Mi"] = {
			k11 = 60, k12 = 26, k13 = 45, k14 = 0, k15 = 22,
			k16 = 70, k17 = 62,
		},
		["Ymir's Flesh"] = {
			k13 = 300, k14 = 140, k15 = 110, k16 = 4, k17 = 1,
			k18 = 1, k20 = 40, k21 = 60, k22 = 120,
		}
	},
}
