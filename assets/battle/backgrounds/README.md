# 2D Battle Backgrounds

Put battle background images in this folder, then assign one to the
`Background Texture` property on the root node of `scenes/battle_2d.tscn`.

Recommended:

- Format: PNG or WebP
- Size: 1920x1080 or the same aspect ratio as the project viewport
- Keep important characters and UI space away from the extreme top and bottom
- Leave the battle characters around the horizontal center-left and center-right

The current 2D battle scene stretches the assigned texture to fill the
viewport. If no texture is assigned, it falls back to the procedural
background and arena.
