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
| Floating invisible stick: touch anywhere (outside buttons), that point is the centre; drag left/right turns, **down climbs, up dives** | A/D or arrows turn, S/Down climbs, W/Up dives |
| Quick tap: barrel roll | R |
| **LOOP** (flown for you) | L |
| **VIEW**: overhead → chase → cockpit | C or V |
| **GUN** (hold; ammo counter, 5 s reload when empty) | Space, J or mouse button |
| **MISSILE** (count bar) | M |
| **BOOST** (hold) | Shift |
| **INTEL** (all controls), **II** pause | I, Esc / P |

Tricks: full climb + BOOST held = back flip; full dive + BOOST held (needs
height) = front flip; holding a dive into the ground with BOOST off = eject
(parachute + close-up on the pilot, then a new jet).

Fight: fighters dogfight (they get on your tail and break away when you get on
theirs), interceptors are fast, drones come in swarms, bombers are tanky and a
boss bomber arrives every 5 waves. Keep an enemy ahead until the box turns red
(rising beeps, steady tone when locked), then MISSILE. When an
enemy missile comes, two rings close in around your jet — roll exactly as
they meet to dodge (short slow motion); a MISSILE straight after a dodge fires
three for free. An AI wingman flies with you.

## Settings (pause menu → SETTINGS)

All values persist in `user://save.cfg`. Defaults:

* **Flight** – speed 130, boost x1.8, turn rate 1.25, bank 52°, cruising
  altitude 220, ceiling 3000, ground clearance 14, wingmen 1, crashes on,
  invert off
* **Combat** – cannon 300, missiles 6, reload 5 s, enemy jets 3, dodge slow
  motion 1.3 s
* **Camera** – view chase, view change 1.4 s, overhead turns with the jet
  0.6, chase distance 2.6 jet lengths, chase height 25°
* **World** – time of day day / sunset / night, day-night cycle off, islands
  0.33, clouds 0.45, world seed 7, jet shadow on
* **Look** – glow 0.8, contrast 0.15, darkened corners 0.3, film grain 0.25,
  sprite turn smooth
* **Effects** – thruster flames pixel, afterburner 0.75, wingtip trails on,
  sea spray 1, explosion sparks 0.6, camera shake 1
* **Helpers** – touch buttons auto, Tutorial/Intel buttons on, debug overlay
  off · **Sound** on, volume 0.6

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
