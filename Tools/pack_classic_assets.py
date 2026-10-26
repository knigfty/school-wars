#!/usr/bin/env python3
"""Pack previously extracted original SWF assets. Requires Pillow for this tool only."""

import argparse
from pathlib import Path
import shutil

from PIL import Image


def pack(directory: Path, output: Path, count: int, columns: int, frame_size: tuple[int, int]) -> None:
    width, height = frame_size
    atlas = Image.new("RGBA", (columns * width, ((count + columns - 1) // columns) * height))
    for index in range(count):
        with Image.open(directory / f"{index + 1}.png") as frame:
            if frame.size != frame_size:
                raise ValueError(f"Unexpected frame size: {directory}/{index + 1}.png: {frame.size}")
            atlas.paste(frame, ((index % columns) * width, (index // columns) * height))
    atlas.save(output, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sprites", type=Path, help="JPEXS sprite export folder")
    parser.add_argument("sounds", type=Path, help="JPEXS WAV-format export folder")
    parser.add_argument("menu_frame", type=Path, help="Fade-free sprite 845 frame 7")
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "Assets" / "Classic")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    pack(args.sprites / "DefineSprite_775", args.output / "students.png", 400, 20, (32, 48))
    pack(args.sprites / "DefineSprite_812_mcMapPatOrg", args.output / "tiles.png", 15, 5, (96, 48))
    with Image.open(args.menu_frame) as image:
        image.crop((5, 15, 645, 280)).save(args.output / "menu.png", optimize=True)
    for index, name in enumerate(["tomove", "select", "punch", "message", "dead", "cancel"], start=1):
        shutil.copyfile(args.sounds / f"{index}_{name}.wav.wav", args.output / f"{name}.wav")


if __name__ == "__main__":
    main()
