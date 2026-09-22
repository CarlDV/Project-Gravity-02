"""Render the changed shapes with Python, Pillow and the standalone Luau CLI.

python tools/preview_updates.py --luau PATH_TO_LUAU
Only the pure Pillow renderer is reused from preview_shapes; sampling uses Luau.
"""

import argparse
import json
import math
from pathlib import Path
import subprocess
import sys
from types import SimpleNamespace

from PIL import Image, ImageSequence
from preview_shapes import CAPTIONS, render

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    parser.add_argument("--parts", type=int, default=512)
    parser.add_argument("--frames", type=int, default=96)
    parser.add_argument("--cell", type=int, default=480)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/plugins")
    parser.add_argument("--scene", choices=("all", "creatures", "release"), default="all")
    args = parser.parse_args()
    if args.parts < 1 or not 2 <= args.frames <= 360:
        parser.error("use at least one part and 2..360 frames")
    CAPTIONS.update({
        "Phoenix Ascendant": "Head leads, body bends, feathers and tail follow",
        "Megalodon": "Banked patrol, vertical swoops and a trailing spine",
        "Black Hole v2": "Demo: 60 pull speed, 70 force, then Regrab",
        "Drop": "Gather, hold, then fall under gravity (archive)",
    })
    for kind, duration in (("creatures", 12), ("release", 6)):
        if args.scene != "all" and args.scene != kind:
            continue
        sampled = subprocess.run(
            [sys.executable, str(ROOT / "tools/test_luau.py"), "--luau", args.luau,
             "tools/sample_updates.lua", kind, str(args.parts), str(args.frames)],
            cwd=ROOT, capture_output=True, text=True, encoding="utf-8", check=True,
        )
        data = json.loads(sampled.stdout)
        for name, series in data.items():
            assert len(series["frames"]) == args.frames, name
            assert all(len(frame) == args.parts for frame in series["frames"]), name
            assert all(math.isfinite(v) for frame in series["frames"] for p in frame for v in p), name
        options = SimpleNamespace(cell=args.cell, frames=args.frames, duration=duration, time=0, mode="debris")
        path = args.output / f"{kind}-motion.gif"
        images = render(list(data), data, options, path,
                        "Creature flight paths" if kind == "creatures" else "Gather, release and recover")
        with Image.open(path) as clip:
            assert clip.n_frames == args.frames
            assert sum(frame.info["duration"] for frame in ImageSequence.Iterator(clip)) == duration * 1000
        sheet = Image.new("RGB", (images[0].width * 2, images[0].height * 2))
        for i, frame in enumerate((0, args.frames // 3, args.frames * 2 // 3, args.frames - 1)):
            sheet.paste(images[frame], ((i % 2) * images[0].width, (i // 2) * images[0].height))
        sheet.save(args.output / f"{kind}-contact.png")
        print(f"Verified {len(data)} shapes, {args.parts} parts each, {args.frames} frames, {duration} s playback.")


if __name__ == "__main__":
    main()
