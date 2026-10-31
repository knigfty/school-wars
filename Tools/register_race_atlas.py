"""Register an image-generated race atlas to classic per-frame bounds.
Usage: python Tools/register_race_atlas.py ORIGINAL GENERATED OUTPUT
Requires Pillow. Output: 1280x1920 RGBA, 400 cells of 64x96 pixels.
"""
import sys
from collections import deque
from PIL import Image

def foreground(frame):
    alpha = frame.getchannel('A')
    solid = {(x, y) for y in range(frame.height) for x in range(frame.width) if alpha.getpixel((x, y)) >= 96}
    largest = set()
    while solid:
        start = solid.pop()
        component = {start}
        queue = deque([start])
        while queue:
            x, y = queue.popleft()
            for dx, dy in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
                point = (x+dx,y+dy)
                if point in solid:
                    solid.remove(point)
                    component.add(point)
                    queue.append(point)
        if len(component) > len(largest):
            largest = component
    if len(largest) < 12:
        return None
    mask = Image.new('L', frame.size)
    for point in largest:
        mask.putpixel(point, alpha.getpixel(point))
    frame.putalpha(mask)
    return frame.crop(mask.getbbox())

def register(original_path, generated_path, output_path):
    original = Image.open(original_path).convert('RGBA')
    generated = Image.open(generated_path).convert('RGBA')
    frames = []
    for i in range(400):
        x, y = i % 20, i // 20
        cell = generated.crop((round(x*generated.width/20), round(y*generated.height/20), round((x+1)*generated.width/20), round((y+1)*generated.height/20)))
        frames.append(foreground(cell))
    output = Image.new('RGBA', (1280,1920))
    fallbacks = []
    for i in range(400):
        x, y = i % 20, i // 20
        bounds = original.crop((x*32,y*48,x*32+32,y*48+48)).getchannel('A').getbbox()
        if bounds is None:
            continue
        frame = frames[i]
        if frame is None:
            # Recover a missing frame within the same race, direction and action.
            pattern = i % 25
            lo, hi = (0,10) if pattern < 10 else ((10,13) if pattern < 13 else ((13,16) if pattern < 16 else ((16,21) if pattern < 21 else (21,24))))
            choices = [i-pattern+p for p in range(lo,hi) if frames[i-pattern+p] is not None]
            if not choices:
                raise ValueError('Missing whole action sequence at frame %d' % i)
            source = min(choices,key=lambda j:abs(j-i))
            frame = frames[source]
            fallbacks.append((i,source))
        left, top, right, bottom = (v*2 for v in bounds)
        width = max(1,round((right-left)*0.99))
        height = max(1,round((bottom-top)*0.99))
        frame = frame.resize((width,height), Image.Resampling.LANCZOS)
        # Original centre and foot anchor, with all output inside original bounds.
        px = x*64 + left + (right-left-width)//2
        py = y*96 + bottom-height
        output.alpha_composite(frame,(px,py))
    output.save(output_path,optimize=True)
    print('Registered 400 frames; recovered missing frames:', fallbacks)

if __name__ == '__main__':
    register(*sys.argv[1:])
