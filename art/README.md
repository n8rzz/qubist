# Art sources

Source files for generated assets. Godot skips this folder (`.gdignore`).

## App icon

`icon.svg` is taken from the "App icon" artboard in the Qubist designs canvas. To regenerate the PNGs after changing it:

```bash
rsvg-convert -w 1024 -h 1024 art/icon.svg -o assets/icon_1024.png
rsvg-convert -w 256 -h 256 art/icon.svg -o icon.png
```

Both PNGs must stay opaque (no alpha), because the App Store rejects icons with transparency.

## Line-clear stone tumble

`stone_tumble.py` makes `assets/audio/stone_tumble_a.wav` and `stone_tumble_b.wav` (#170): a low thump with a few pebble knocks after it. Each take comes from its own seed, and the game alternates them. To regenerate (needs numpy and scipy):

```bash
python3 art/stone_tumble.py
```
