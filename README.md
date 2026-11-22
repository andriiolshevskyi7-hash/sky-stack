# Sky Stack

A 2.5D pixel-art fighter-jet game over an endless procedural city, built with
**Godot 4.3 (GDScript)** for **Android** (landscape, fullscreen immersive).

Everything you see is **sprite stacking**: objects are stacks of flat 2D slices
drawn bottom-to-top — no 3D models and no imported art. All slice sheets,
facades, ground tiles and sounds are generated in code at startup.
No ads, no analytics, no splash — just the game.

## Download & install the APK (from GitHub Actions)

Every push to any branch builds a debug APK.

1. Open the repository on GitHub → **Actions** tab → workflow **Android APK**.
2. Click the latest successful run (green check).
3. Scroll to **Artifacts** and download **sky-stack-debug-apk** (a zip; you must
   be signed in to GitHub). Artifacts are kept for **3 days**.
4. Unzip it → `sky-stack-debug.apk`.
5. Install on the phone:
   * **Directly on the phone:** copy/download the APK to the phone, open it,
     and allow "Install unknown apps" for your browser/file manager when asked.
   * **With adb (USB debugging on):** `adb install -r sky-stack-debug.apk`

The debug build shows an FPS / draw-call overlay (toggle it in the pause menu).
Because every CI run uses a fresh debug keystore, uninstall the previous build
first if Android refuses to update it (`adb uninstall com.skystack.game`).

## Controls

| Touch | Keyboard / mouse (desktop testing) |
| --- | --- |
| Left half: floating joystick | WASD / arrow keys |
| **BOOST** button | Shift (or K) |
| **FIRE** button | Space, J or left mouse button |
| **UP / DOWN** buttons (overhead view only): climb / dive | E / Q (any view) |
| **CAM** button (top right): overhead → chase → cockpit | C |
| **II** button: pause menu | Esc / P |

On the title screen, tap anywhere to start.

Joystick behaviour depends on the view:

* **OVERHEAD** (top-down, north up, jet in the centre): push the stick in the
  direction you want to fly; UP/DOWN buttons change altitude.
* **CHASE** (behind the jet, perspective ground plane to the horizon) and
  **COCKPIT** (first person with canopy, HUD and dashboard): stick left/right
  banks and turns, stick up/down pitches (up = climb; can be inverted in the
  pause menu).

## Gameplay

The world is a bright ocean with islands; the city sits on the main island
(dense downtown, sparser residential, parks, forests and beaches) with small
towns on other islands. You cruise at 125 m, high above the rooftops: **dive
below 75 m and thread between skyscrapers to build a score multiplier (up to
x4)**, but clipping a building or the ground costs health.

Defend the city in waves: enemy jets, drones and bombers attack the buildings
(CITY bar). From wave 4 rooftop anti-air guns join in. High score is saved to
`user://save.cfg`. Pause menu: camera, sprite turn smooth/64 steps,
day/night cycle (off by default — the game starts in full day), pitch
inversion, debug overlay.

## Tech overview

| Feature | Where |
| --- | --- |
| Low-res pixel view (280–400 px tall, integer scale 3–4×, nearest) + bloom | `scripts/pixel_view.gd`, `shaders/post.gdshader` |
| Sprite-stack node, GPU rotation, 64-step angle snapping | `scripts/sprite_stack.gd`, `scripts/stack_batch.gd`, `shaders/stack.gdshader` |
| Procedural slice sheets + PNG overrides | `scripts/sheet_gen.gd`, `scripts/stack_lib.gd`, [`assets/stacks/README.md`](assets/stacks/README.md) |
| Collapsed stacks for tall buildings | `shaders/building.gdshader`, `CityGen._box` |
| Islands heightmap shared by CPU and GPU, infinite terrain shader (ocean, surf, beaches, forest) | `scripts/stack_lib.gd`, `shaders/terrain.gdshader` |
| City on the islands (districts, parks, port, stadiums, forests) | `scripts/city_gen.gd` |
| Threaded chunk streaming, ~4 draw calls per chunk | `scripts/chunk_manager.gd` |
| Perspective camera blending overhead / chase / cockpit, horizon fog, shake, dither fade | `scripts/game_camera.gd`, `shaders/common.gdshaderinc` |
| Pixel-art cockpit (canopy, HUD pitch ladder + heading, radar, attitude, gauges) | `scripts/cockpit.gd` |

The pixel view: the world renders into a `SubViewport` whose height is
280–400 px and whose width follows the screen aspect, chosen so it scales to the
screen by a whole number (Pixel 9 Pro XL 2992×1344 → 748×336 at 4×). The
project stretch mode stays *disabled*: only the world is pixelated, the HUD and
menus are drawn at full resolution on top.

Sprite stacking: each slice is a flat textured quad at its height, rendered by
a perspective camera with a depth buffer — the camera shifts each slice "up the
screen" according to its height and scales stacks by distance, and the depth
test removes all manual sorting. Dynamic stacks draw each slice 2–4 times
between slice heights so no gaps appear when the camera is close. Dynamic stacks are GPU-instanced (`MultiMesh`, one draw call per sheet)
and rotated in the vertex shader; static stacks are baked per chunk.

## Running locally

Open the folder in Godot 4.3 and press Play, or:

```sh
godot --path .                                   # play
godot --headless res://tests/test_runner.tscn    # run the tests
```

## CI

`.github/workflows/android.yml` runs on every push: Godot 4.3 CI image
(`barichello/godot-ci:4.3`) → install export templates → headless tests →
generate a throw-away debug keystore → headless debug export → upload the APK
artifact (retention 3 days). No keystores or secrets are committed.

## Development steps

1. **Step 1** – SpriteStack node, pixel view, chase camera, jet, streamed city
   chunks, CI producing the APK.
2. **Step 2** – infinite city traffic (cars, buses, trains, boats, ships),
   enemies (drones, jets, bombers, rooftop AA guns) and waves, combat, building
   damage/destruction.
3. **Step 3** – day/night cycle (lit windows, street-light pools, neon,
   sweeping searchlights), layered clouds with matching drifting shadows and
   fly-through fog, speed lines, hit flash, chimney smoke, synthesized sound.

### Debug command-line flags (desktop)

`godot --path . -- --play --auto --cam=1 --time=0.0 --wave=4 --shot=out.png --frames=200`
starts a game on autopilot in chase view (0 overhead, 1 chase, 2 cockpit) at
midnight on wave 4 and saves a screenshot after 200 frames.
