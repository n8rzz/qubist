# Art sources

Source files for generated assets. Godot skips this folder (`.gdignore`).

## App icon

`icon.svg` is taken from the "App icon" artboard in the Qubist designs canvas. To regenerate the PNGs after changing it:

```bash
rsvg-convert -w 1024 -h 1024 art/icon.svg -o assets/icon_1024.png
rsvg-convert -w 256 -h 256 art/icon.svg -o icon.png
```

Both PNGs must stay opaque (no alpha), because the App Store rejects icons with transparency.
