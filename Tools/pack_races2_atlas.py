"""Pack four image-generated 8x12 pose sheets into the game's 20x20 atlas.

Usage: python Tools/pack_races2_atlas.py HUMAN ORC ELF DEMON OUTPUT
Requires Pillow. Run from any directory; the classic reference is repository-relative.
Each source has four directions, each occupying three rows of eight poses.
Missing poses fail rather than borrowing a different animation frame.
"""

import sys
from pathlib import Path

from PIL import Image

from register_race_atlas import foreground


def pack(sheet_paths, output_path):
    if len(sheet_paths) != 4:
        raise ValueError("Expected Human, Orc, Elf and Demon pose sheets")
    reference_path = Path(__file__).resolve().parents[1] / "Assets/Classic/students.png"
    reference = Image.open(reference_path).convert("RGBA")
    output = Image.new("RGBA", (1280, 1920))
    count = 0
    for race, path in enumerate(sheet_paths):
        sheet = Image.open(path).convert("RGBA")
        for direction in range(4):
            for pose in range(24):
                col, row = pose % 8, direction * 3 + pose // 8
                cell = sheet.crop((
                    round(col * sheet.width / 8), round(row * sheet.height / 12),
                    round((col + 1) * sheet.width / 8), round((row + 1) * sheet.height / 12),
                ))
                sprite = foreground(cell)
                if sprite is None:
                    raise ValueError(f"Missing race {race}, direction {direction}, pose {pose + 1}")
                index = race * 100 + direction * 25 + pose
                x, y = index % 20, index // 20
                bounds = reference.crop((x * 32, y * 48, x * 32 + 32, y * 48 + 48)).getbbox()
                if bounds is None:
                    raise ValueError(f"Unexpected empty reference pose {index}")
                left, top, right, bottom = (v * 2 for v in bounds)
                width = max(1, round((right - left) * 0.99))
                height = max(1, round((bottom - top) * 0.99))
                sprite = sprite.resize((width, height), Image.Resampling.LANCZOS)
                output.alpha_composite(sprite, (
                    x * 64 + left + (right - left - width) // 2,
                    y * 96 + bottom - height,
                ))
                count += 1
    output.save(output_path, optimize=True)
    # Validate the encoded asset, including the death-blink cells and foot anchors.
    encoded = Image.open(output_path).convert("RGBA")
    for index in range(400):
        x, y = index % 20, index // 20
        bounds = encoded.crop((x * 64, y * 96, x * 64 + 64, y * 96 + 96)).getbbox()
        original = reference.crop((x * 32, y * 48, x * 32 + 32, y * 48 + 48)).getbbox()
        if index % 25 == 24:
            if bounds is not None:
                raise ValueError(f"Nontransparent separator {index}")
            continue
        if bounds is None or original is None:
            raise ValueError(f"Empty visible pose {index}")
        envelope = tuple(v * 2 for v in original)
        if not (bounds[0] >= envelope[0] and bounds[1] >= envelope[1]
                and bounds[2] <= envelope[2] and bounds[3] == envelope[3]):
            raise ValueError(f"Pose bounds or foot anchor changed at {index}")
    print(f"Validated {count} visible poses and 16 transparent separators: {output_path}")


if __name__ == "__main__":
    pack(sys.argv[1:-1], sys.argv[-1])
