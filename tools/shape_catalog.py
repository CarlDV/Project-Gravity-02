"""Six-panel motion gallery order and captions. Names match the Lua filenames."""

NEW_SHAPES = (
    "Abyssal Jellyfish", "Void Cathedral", "Ouroboros", "Hopf Fibration",
    "Celestial Manta", "Megalodon", "World Tree", "Ragnarok Hammer",
    "Eclipse Scythe", "Aegis Bastion", "Singularity Trident", "Ghost Galleon",
    "Infernal Skull", "Chrono Hourglass", "Storm Gyre",
)

GROUPS = (
    ("Creatures", (
        ("Phoenix Ascendant", "Banking flight, wingbeats and flowing tails"),
        ("Astral Kraken", "Breathing mantle and curling tentacles"),
        ("Abyssal Jellyfish", "Pulsing bell and trailing oral ribbons"),
        ("Celestial Manta", "Rolling wing waves and a streaming tail"),
        ("Megalodon", "Swimming body, swept fins and a beating tail"),
        ("Ouroboros", "An undulating serpent biting its own tail"),
    )),
    ("Monuments", (
        ("Rift Gate", "Twin irises around a twisting wormhole"),
        ("Void Cathedral", "Gothic arches and a counter-rotating halo"),
        ("Aegis Bastion", "A floating shield with flexing winglets"),
        ("Ghost Galleon", "Rocking hull, billowing sails and a wake"),
        ("World Tree", "Twisting roots and a breathing canopy"),
        ("Infernal Skull", "Turning horns and an opening jaw"),
    )),
    ("Relics and storms", (
        ("Ragnarok Hammer", "A turning hammer with orbiting debris"),
        ("Eclipse Scythe", "Sweeping blade, shaft and crescent halo"),
        ("Singularity Trident", "Three prongs, a wrapped grip and orbiting halo"),
        ("Chrono Hourglass", "Circulating sand inside an hourglass cage"),
        ("Storm Gyre", "Braided funnels beneath a turning storm cloud"),
        ("Cosmic Lotus", "Opening petals in counter-rotating layers"),
    )),
    ("Mathematical forms", (
        ("Hopf Fibration", "Linked circles from a Hopf projection"),
        ("Torus Knot", "Even-speed motion around a torus knot"),
        ("Klein Bottle", "A continuous figure-eight immersion"),
        ("Möbius Strip", "Two turns traverse both sides of the strip"),
        ("Hypercube Nexus", "A rotating 5D cube projected into 3D"),
        ("Tesseract", "Nested rotating cubes and connecting edges"),
    )),
    ("Orbital machines", (
        ("Arcane Orrery", "Orbiting rings, arms and a central axis"),
        ("Graviton Engine", "Stacked turbine rings and flowing particles"),
        ("Quantum Core", "A spinning core with surrounding particles"),
        ("Quantum Atoms", "Particles on tilted intersecting orbits"),
        ("Space Station", "A turning station ring and central body"),
        ("Alien Mothership", "A rotating saucer above a downward beam"),
    )),
    ("Sky phenomena", (
        ("Aurora Borealis", "Traveling waves across a broad curtain"),
        ("Black Hole", "Differential rotation in a warped disk"),
        ("Dyson Sphere", "Orbiting debris over a spherical shell"),
        ("Supernova", "Repeated expansion from a central star"),
        ("Meteor Shower", "Falling streams of debris"),
        ("Cosmic Comet", "An orbiting head with a trailing tail"),
    )),
    ("Serpents and ribbons", (
        ("Celestial Ribbon", "Ribbon bodies following a shared path"),
        ("Hollow Worm", "A hollow tube traveling along a curve"),
        ("World Serpent", "A long winding serpent of debris"),
        ("Leviathan Coil", "A coiled body with animated appendages"),
        ("Eldritch Binding", "Winding tendrils around a central column"),
        ("Seraphim", "Turning rings and a feathered wing array"),
    )),
    ("Currents and webs", (
        ("Vortex Funnel", "A widening column of spiraling debris"),
        ("Pulsar Vortex", "Twisting streams through a broad vortex"),
        ("Maelstrom Spire", "Spiral jets around a rising spire"),
        ("Galactic Web", "Rotating nodes joined by a web"),
        ("Fractal Web", "Breathing branches of repeated geometry"),
        ("DNA Helix", "Rotating strands and connecting rungs"),
    )),
    ("Spins and transformations", (
        ("Big Ring Things", "Separated rings rotating at different rates"),
        ("Halo Ring", "Continuous circulation around a tilted halo"),
        ("Spinning Cube", "A rigid cube rotating on its chosen axes"),
        ("Reality Shatter", "Triangular shards burst apart and reform"),
        ("Quantum Entanglement", "Paired particles drift, collapse and release"),
        ("Dense Spin", "Fast circulation inside a dense small ball"),
    )),
    ("Energy abilities", (
        ("Goro Goro no Mi", "Branching lightning follows the cursor"),
        ("Raigo", "An orb launches, expands and returns"),
        ("Light Light no Mi", "Beam heads bounce with persistent trails"),
        ("ROOM Ope Ope no Mi", "A rotating dome with shuffled part slots"),
        ("Twin Core Beam", "Orbiting cores switch into aimed streams"),
        ("Domain Expansion Infinite Void", "Rotating debris throughout a void sphere"),
    )),
    ("Tools and puppets", (
        ("Mech Suit", "Debris follows the walking avatar's pose"),
        ("Platform", "A moving pad follows the avatar"),
        ("Hover Text", "Glyphs hover with a traveling wave"),
        ("Sculptor", "Selected debris follows a scripted drag"),
        ("Shield Wall", "A sweeping wall of orbiting debris"),
        ("Big Bad Broom", "Click extension and a cursor-driven sweep"),
    )),
    ("Launches and impacts", (
        ("Rocket Engine", "A flying engine with streaming exhaust"),
        ("Meteor Hammer", "An orbiting hammer and trailing chain"),
        ("Mochi Mochi no Mi", "An elastic blob stretches behind the core"),
        ("Cursed Technique Red", "The moving core repels nearby debris"),
        ("Point Impact", "Loose debris converges on a moving core"),
        ("Slingshot", "An outer charge collapses toward the core"),
    )),
    ("World probes and review shapes", (
        ("Gods Call", "Loose debris rises at a constant speed"),
        ("Ymir's Flesh", "A breathing envelope fitted to a room"),
        ("Dragons Teeth", "Ground-fitted teeth around the caster"),
        ("Mugen Train", "A moving train of debris carriages"),
        ("Yamata no Orochi", "Multiple heads probe a room and doorway"),
        ("Drop", "Reselect, release and fall onto a fixture floor"),
    )),
)

CAPTIONS = {name: caption for _, entries in GROUPS for name, caption in entries}
VIEWS = {
    "Rift Gate": (48, 18),
    "Celestial Manta": (15, 42), "Megalodon": (65, 15), "Ghost Galleon": (52, 16),
    "Infernal Skull": (8, 8), "Aegis Bastion": (12, 8), "Void Cathedral": (30, 18),
    "Hover Text": (0, 5), "Möbius Strip": (25, 40), "Torus Knot": (25, 40),
    "Hopf Fibration": (20, 32), "Mech Suit": (15, 8), "Platform": (22, 35),
    "Black Hole": (22, 35), "Halo Ring": (22, 35), "Ouroboros": (18, 25),
    "Big Bad Broom": (62, 18), "Twin Core Beam": (50, 22), "Goro Goro no Mi": (62, 18),
}

# Gallery-only control choices, never written back into config.lua. Keep the
# defaults unless a dense/fast form needs a readable demonstration at GIF fps.
PRESETS = {
    "Phoenix Ascendant": {"k18": 90, "k20": 45},
    "Rift Gate": {"k19": 1},
    "Dense Spin": {"k11": 2, "k12": 20},
    "Light Light no Mi": {"k13": 1, "k14": 6},
}
