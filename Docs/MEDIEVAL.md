# Medieval Wars variant

School Wars stays at `/`. Its animated Extras button opens `/v2`. The `/v2` and `/v2/` routes serve the same Godot Web export and choose the medieval skin from the browser pathname. A return button opens School Wars. No simulation rules are forked.

Teams map in order: Black -> Humans, Green -> Orcs, Yellow -> Elves, Purple -> Demons. Colours, stats, population bonuses, recruitment, map, movement and combat are shared. Only the menu, display names and character atlas change. Original School Wars assets and attribution remain in the classic version. No GAMEDESIGN title is displayed on the medieval menu.

Assets: `Assets/Medieval/menu.jpg` and `Assets/Medieval/students.png`. The atlas keeps the 640x960 layout, 20 columns x 20 rows, with 32x48 cells. The same atlas supplies portraits and all in-game animations. The Extras pulse respects the browser reduced-motion preference. No Godot scene wiring is required; export with the existing Web preset.

Artwork was generated with the built-in image generation tool. Background prompt: wide illustrated dark fantasy medieval warfare; castle battlements, armies, human warrior, green orcs, golden elves and violet demons, dusk and embers, central negative space, no text or logos. Atlas edit prompt: preserve the original 400 animation slots and foot anchors; replace the four 100-frame colour groups with dark-armoured humans, green orcs, golden elves and purple horned demons; transparent background, retain walk/sit/punch/death poses and original directions. The generated atlas was normalized to the existing cell dimensions and palette-compressed for browser loading.

Validation: Godot import and complete Classic tests, plus medieval shell checks for title, race order, sprite binding and starting each race with the unchanged simulation.

## HD sprite and recruitment HUD update

The active medieval atlas is `Assets/Medieval/students_hd.webp`, 1280x1920 with 64x96 frames (twice the original width and height). A higher-detail image-generation redraw was normalized into the existing 400 slots; transparent death blink frames are preserved. Both portraits and board rendering derive source frame size from the texture dimensions while keeping world-space character size, hitboxes and animation timing unchanged. Medieval rendering uses linear sampling; classic sprites remain unchanged.

The bottom-right HUD shows the exact requested mouse tips, with the recruitment progress bar above and minimap above that. The progress bar reads actual per-team recruitment progress/threshold; owned recruitment tiles and the Green/Orc threshold naturally affect fill speed. Capacity-full and blocked-base labels explain why a recruitment cycle may not produce a unit. No recruitment rules have changed.

HD art prompt: clearer high-resolution remaster of the original medieval atlas, preserving all 400 slots, poses, directions and race colour blocks; improve armor edges, faces, elf ears, orc tusks and demon horns; transparent background. Built-in image generation was used, followed by atlas normalization and WebP encoding.
