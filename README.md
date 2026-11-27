# Sky Stack

A 2.5D pixel-art fighter-jet game over an endless procedural city, built with
**Godot 4.3 (GDScript)** for **Android** (landscape, fullscreen immersive).

Everything you see is **sprite stacking**: objects are stacks of flat 2D slices
drawn bottom-to-top — no 3D models and no imported art. All slice sheets,
facades, ground tiles and sounds are generated in code at startup.
No ads, no analytics, no splash — just the game.

## Modes and maps

Fully offline: every other pilot is a bot flying the same planes with the same
flight model and weapons (skill ROOKIE → ACE, roles, team tactics).

**Modes:** TEAM DOGFIGHT (4v4 by default, 2–8 per team in settings), BASE
STRIKE (destroy the enemy airfield, AA guns, radar, bunkers, hangars), CITY
DEFENCE (endless waves), DUEL (1v1). Flow: PLAY → mode → map → lobby →
3-2-1 → battle → results (K/A/D, damage, MVP, XP and coins).

**Maps** (each with its own palette, relief, clouds and time of day):

| Map | Look |
|---|---|
| Tropical Islands | islands, the city, bright sea (time of day from settings) |
| Desert Canyon | layered sandstone mesas and buttes, canyons to fly through, oases, late afternoon |
| Snow Mountains | terraced granite peaks up to ~560 m with snow tops, pine valleys, frozen lake, morning |
| Night City | bigger neon skyline, neon street light, 9 sweeping searchlights |
| Ocean Carrier | open ocean, two carrier battle groups (carrier, AA, island radar, destroyers, frigates) |

The battle area is 11.2 km across and drawn as a red dashed line on the ground and
on the minimap. Near the edge you see RETURN TO BATTLE AREA, and after 4 s
outside the plane turns back on its own. Bots respect the edge too. Landmarks
(Sky Tower, Lighthouse, The Needle, Stone Arch, Beacon) show as yellow diamonds
on the minimap.

## Hangar and progression

**HANGAR** (title menu) holds the aircraft tree, made of original planes with
invented names. There are 3 branches with 4 tiers each, and every plane has
its own outline, painted in code:

| Tier | Light fighters | Heavy fighters | Attackers |
|---|---|---|---|
| 1 | WREN LF-1 (straight wing) | BASTION HF-1 (twin tail) | MATTOCK AT-1 (straight wing, pods) |
| 2 | VIREO LF-2 (swept) | RAMPART HF-2 (sharp sweep) | HALBERD AT-2 |
| 3 | SKYLARK LF-3 (delta + canards) | WARDEN HF-3 (big delta) | ANVIL AT-3 (twin boom) |
| 4 | ZEPHYR LF-4 (forward swept) | MONOLITH HF-4 (V-tail) | MAUL AT-4 (delta + canards) |

* Buy a plane with coins once your rank allows it and you own the tier
  before it.
* Each plane has 5 upgrades with 5 levels each: engine, armor, guns,
  missiles (more missiles, faster lock-on) and flares (more flares per
  sortie). Flares are released by hand: double tap.
* Skins: Factory, Arctic, Desert camo, Jungle camo, Midnight, Tiger and Ace
  gold. They unlock by rank, by kills or with coins, and you see them in
  battle. You can also set a tail number.
* The red team always flies the AGGRESSOR scheme.
* Ranks: Bronze III → Silver → Gold → Platinum → Diamond I → Ace. Bots in a
  match are matched to your rank, and their plane tier follows their skill.

## Missions, achievements, profile

The main menu shows your selected plane (in its skin) parked in a hangar as
a 3D background with a slow cinematic camera (`scripts/menu_stage.gd`; the
backdrop is swappable: `hangar` or `runway`). PLAY, HANGAR (skins live in
the hangar), MISSIONS, PROFILE and SETTINGS run down the left, rank and
coins along the top, the plane's name and class bottom right. A red dot
means something is ready (a reward to claim, a plane you can buy, a skin
that unlocked). Background music (calm in the menus, driving in battle) is
synthesised in code (`scripts/music.gd`) and cached after the first start.

* **Daily missions**: 3 per day, refreshed at local midnight. Each gives coins
  and XP, and you get one free reroll per day.
* **Weekly challenges**: 3 bigger goals per week (from Monday) with bigger
  rewards.
* **Achievements**: 26 achievements, each with bronze, silver and gold tiers
  (kills, wins, dodges, flare saves, loops, ground targets, carriers,
  missile and cannon kills, aces, MVP, streaks, each mode, each map, each
  plane branch). Every tier gives coins and XP. A toast pops up in battle
  and the results screen lists them. Bronze of ACE HUNTER unlocks the
  TIGER skin.
* **Profile**: editable name, rank badge, battles, wins, win rate, K/D,
  accuracy, favourite plane, best streak, time played, MVPs and achievement
  progress.

Everything is saved locally (`user://profile.json`) through the Profile
storage interface.

## UI style

Every UI element is pixel art: menus, lobby, results, hangar, skins,
missions, profile, settings, pause, INTEL and the battle HUD.

* **Font:** Tiny5, a pixel font with Latin and Ukrainian Cyrillic, under the
  SIL Open Font License (see `assets/fonts/`). It is drawn with no
  antialiasing, at sizes that are multiples of 8 px, with wide letter
  spacing.
* **Panels and buttons:** dark navy with a 1–2 px light border and sharp
  corners. A selected item is a white fill with dark text. Primary actions
  are orange (#F0580E).
* **Animation:** buttons bounce when pressed, screens slide in, the coin
  counter ticks, and RANK UP flashes on the results screen.

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
Three control options (Settings → Controls): **Aim + joystick** (default),
**Aim + swipe** and **Classic stick**.

**Aim (War Thunder style)**. Two reticles are on screen in the
chase and cockpit views: the small winged **nose** cross (where the plane
points, with a gun-lead diamond on the nearest enemy ahead) and the **aim**
circle (where you want to fly; an arrow on the screen edge when it is off
screen). The aim lives on the full sphere around the plane (up, down,
behind, straight below or above, over the top) and the chase camera follows
it freely. An instructor flies true 3D maneuvers so the nose chases the aim
with the real flight model, the way a pilot would: roll the lift vector onto
the aim, then pull (roll and G build up with inertia, energy is lost and
gained for real). Aim right: bank and turn; aim down: roll inverted and pull
through (split-S, ending lower the other way); aim up and back: half loop
and roll upright (Immelmann); aim behind: keeps turning. Only safety limits:
it eases the pull when slow, keeps a dive within the altitude left, and
pulls up with a PULL UP warning when the flight path would hit the ground, a
building or a mountain. Skilled bots fly the same maneuvers (split-S,
Immelmann, high yo-yo).

With **Aim + joystick** a floating joystick appears under the left thumb and
keeps moving the aim circle while held: a small deflection moves it slowly
for gunnery, full deflection fast for hard turns (small dead zone, speed in
Settings). Hold it to one side and the plane keeps turning (the circle stays
at most ~50° ahead of the nose); release and the circle stops where it is.
With **Aim + swipe** the left half is a trackpad instead.

**Classic stick** – an invisible floating stick on the left side.

| Touch | Keyboard / mouse (desktop testing) |
| --- | --- |
| **Left half** (aim + joystick): hold the floating joystick to keep the aim circle moving; (aim + swipe): drag like a trackpad. The circle stays where you leave it | mouse moves the aim; arrows / WASD |
| **Left half** (stick): floating stick, drag left/right to **bank and turn**, down to **pull**, up to push | A/D or arrows bank, S/Down pull, W/Up push |
| **Right side free area**: drag to look around the plane / the cockpit; it returns when you let go | hold Q / E, middle mouse drag |
| **Right edge**: THROTTLE lever. Drag it up or down and it stays where you leave it; the orange top zone is the **afterburner** (it overheats, then has to cool) | T / G throttle, Shift afterburner, mouse wheel |
| **Double tap** anywhere free (not on buttons): release **flares** (limited, counter in the HUD; also with a second finger while steering) | R |
| FIRE icon (hold; ammo counter, reload when empty) | Space, J or mouse button |
| MISSILE icon (count, reload ring) | M |
| LOOP icon (flown for you; it can stall at the top if you start slow) | L |
| Eye icon: chase ↔ cockpit; **II** pause; INTEL lists all controls | C or V, Esc / P, I |

Vibration on hits, lock-on, stall and crash (Settings → HELPERS).

Flight: real energy model (climbing and hard turns cost speed, diving gains
it, stall when slow and pulling hard, grey-out above about 8 G) with a light
flight assist. Hitting anything is fatal and the pilot ejects (2.6 s
cinematic, tap to skip).

Fight: fighters dogfight (they get on your tail and break away when you get on
theirs), interceptors are fast, drones come in swarms, bombers are tanky and a
boss bomber arrives every 5 waves. Keep an enemy ahead until the box turns red
(rising beeps, steady tone when locked), then MISSILE. An AI wingman flies
with you.

Missile defence: an incoming missile sounds a warning that beeps faster as it
closes, and a red arrow shows where it comes from. Missiles burn their motor
for 2.6 s and then coast, losing speed to drag and climbing; their turn is
limited by G and their seeker sees only ~55° off their path. So:

* **Flares** (double tap) decoy a missile with a chance that depends on
  timing (best 1–2.6 s before impact) and aspect (best when it comes from
  behind), plus a bonus while pulling hard.
* **Hard maneuvers**: turn across its path so it has to out-turn you; it
  bleeds energy, and past its seeker limit or below ~170 m/s it is beaten
  (EVADED).

## Sound

Everything is synthesised in code (`scripts/sfx.gd`, `scripts/sound_scape.gd`):

* **Engine**: core rumble + turbine whine; the RPM spools up and down behind
  the throttle and sets pitch and level; the afterburner roar fades in with
  the flame
* **Wind** grows with speed squared, with buffeting under high G and in a
  stall; a two-tone **stall horn** sounds while stalling
* **Pilot**: breathing that quickens and deepens with G, a straining grunt
  above ~6.5 G (cockpit view)
* **Weapons**: cannon burst loop with a tail, missile launch whoosh, seeker
  growl while locking (rising as it locks) and a steady lock tone; incoming
  missile warning
* **Explosions and other planes** are attenuated and delayed by distance;
  far blasts switch to a muffled rumble; planes flashing past make a
  Doppler whoosh
* **Cockpit vs outside**: in the cockpit the outside sounds are low-passed
  and quieter, the whine, instruments and the pilot louder; outside, the
  burner and wind are louder. A hard limiter keeps the mix from clipping.

## Settings (pause menu → SETTINGS)

The player's page has only: language, graphics quality (low / medium /
high), sound volume, music volume, controls (aim + joystick / aim + swipe /
classic stick), aim speed, swipe sensitivity,
invert climb / dive, stick indicator,
vibration, and RESET TO DEFAULTS. Every detailed tuning value below is on the
DEBUG SETTINGS page, which exists only in debug builds.

All values persist in `user://save.cfg`. Defaults:

* **Flight** – speed 130, boost x1.8, turn rate 1.25, bank 52°, cruising
  altitude 220, ceiling 3000, ground clearance 14, wingmen 1, crashes on,
  invert off
* **Combat** – cannon 300, missiles 6, reload 5 s, enemy jets 3
* **Camera** – view chase (VIEW toggles chase ↔ cockpit), view change 1.4 s,
  chase distance 0.7 jet lengths (close behind), chase height 25°
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
| Pixel view (HD voxel: ~720 px tall on high, 540 medium, 400 low; integer scale, nearest) + bloom | `scripts/pixel_view.gd`, `shaders/post.gdshader` |
| Sprite-stack node, GPU rotation, 64-step angle snapping | `scripts/sprite_stack.gd`, `scripts/stack_batch.gd`, `shaders/stack.gdshader` |
| Procedural slice sheets + PNG overrides | `scripts/sheet_gen.gd`, `scripts/stack_lib.gd`, [`assets/stacks/README.md`](assets/stacks/README.md) |
| Collapsed stacks for tall buildings | `shaders/building.gdshader`, `CityGen._box` |
| Islands heightmap shared by CPU and GPU, infinite terrain shader (ocean, surf, beaches, forest) | `scripts/stack_lib.gd`, `shaders/terrain.gdshader` |
| City on the islands (districts, parks, port, stadiums, forests) | `scripts/city_gen.gd` |
| Threaded chunk streaming, ~4 draw calls per chunk | `scripts/chunk_manager.gd` |
| Perspective camera blending chase / cockpit, shake, dither fade | `scripts/game_camera.gd` |
| Physical sky: single-scattering atmosphere (Rayleigh, Mie, ozone) on a small game planet — blue day, orange / pink / violet dawn and dusk, horizon dips and curves at altitude, far sea below it; moon, twinkling stars, Milky Way; CPU twin for the haze colours and sunlight tint | `shaders/sky.gdshader`, `scripts/atmo.gd`, `scripts/daynight.gd` |
| Volumetric clouds you can fly through: one full-screen ray-marched cumulus layer (flat bases, rounded tops, 3D billow erosion), lit by the physical sun (pink at dusk), silver lining, dark bases; writes the cloud front's depth so planes in front stay visible and planes inside are hidden; white-out inside; shadows on the ground from the same coverage field; god rays; a plane deep in a cloud breaks lock-on and loses missiles; bots hide in clouds. Classic sprite puffs on low quality | `shaders/cloud_vol.gdshader`, `scripts/clouds.gd`, `shaders/post.gdshader` |
| Speed and manoeuvre effects: vapour cone around the fuselage near top speed, vapour sheets over the wings in hard pulls (rolling 3D noise, sun-lit), soft wingtip vortices that brighten with G, engine contrails above ~2 km that spread and break up over 18 s, heat haze behind the nozzles (post distortion) | `scripts/vapor.gd`, `shaders/vapor.gdshader`, `scripts/trails.gd`, `scripts/contrails.gd`, `shaders/ribbon.gdshader` |
| Water: wave normals (two swells + three octaves of drifting ripples, calmer in the distance and the shallows), Fresnel reflection of the physical sky (a small sky table refreshed by DayNight) and of the clouds above, the sun's glittering path (dimmed in cloud and plane shadows), the moon's path at night; mirrored reflections of planes, ships and boats (depth-correct, rippling); surf rolling in and breaking into lacy foam on the beaches; Kelvin wakes behind ships and boats; spray mist and a wake line under planes skimming the sea | `shaders/common.gdshaderinc`, `shaders/terrain.gdshader`, `shaders/stack_mirror.gdshader`, `scripts/wakes.gd`, `shaders/wake.gdshader`, `scripts/daynight.gd` |
| Aerial perspective: exponential height haze coloured like the sky in that direction (horizon / far surface / towards the sun); thin air up high | `shaders/common.gdshaderinc` (`fogged`) |
| 3D cockpit: low-poly tub (angled consoles, sloped panel under an overhanging glareshield, canopy bows, HUD posts + combiner, keypad, stick between the knees, throttle lever, seat) in its own low-res viewport composited by the post shader; pixel-art textures drawn live into a canvas atlas (radar, colour attitude, moving map, engine page, panoramic page, lit keys, warning lights); sun + ambient + night instrument glow; head look and head motion with G / turbulence | `scripts/cockpit3d.gd`, `scripts/cockpit_art.gd`, `shaders/cockpit.gdshader` |
| HUD symbology clipped to the projected combiner, helmet target markers | `scripts/cockpit.gd` |

The pixel view: the world renders into a `SubViewport` whose height follows
the graphics quality (HD voxel on high: up to 720 px, medium 540, low 400 —
the classic look) and whose width follows the screen aspect, chosen so it
scales to the screen by a whole number (Pixel 9 Pro XL 2992×1344 → 1496×672
at 2× on high, 748×336 at 4× on low). The project stretch mode stays
*disabled*: only the world is pixelated, the HUD and menus are drawn at full
resolution on top; the cockpit HUD is drawn at a matching UI scale so it keeps
its size and gets sharper.

**HD voxel.** Every model is twice as fine as the classic art:
- planes are 128×128 px × 32 slices (the art parameters stay on the 64 grid
  and are scaled at build time, so panel lines, rivets and edges come out
  one voxel thin, with round missiles, tanks and bombs);
- props, vehicles, ships and trees are painted by `Painter` at 2 texels per art
  pixel (smooth polygons, ellipses and lines) plus a detail pass (bevels at
  material boundaries, edge rims, grain);
- facades and roofs (window frames, mullions, sills, bonded brick, sheet
  ribs) and ground tiles (asphalt grain and cracks, slab joints, grass,
  ripples, rails) are painted at 2–4× too.

The atlases are cached in `user://cache` (first start ~3 s, later ~0.3 s).

Sprite stacking: each slice is a flat textured quad at its height, rendered by
a perspective camera with a depth buffer — the camera shifts each slice "up the
screen" according to its height and scales stacks by distance, and the depth
test removes all manual sorting. Dynamic stacks draw each slice 2–4 times
between slice heights so no gaps appear when the camera is close. Dynamic stacks are GPU-instanced (`MultiMesh`, one draw call per sheet)
and rotated in the vertex shader; static stacks are baked per chunk.

Planes (`scripts/plane_art.gd`) are voxel models, 128×128 px × 32
slices (HD), built from parametric parts: shaped fuselage stations, bubble canopy
with frame bows and the pilot's helmet, wings with dihedral, panel lines,
rivets, flaps, roundels and nav lights, canards, fins with rudders and a
strobe, intakes with lips and dark ducts, nacelles, booms, nozzles with petals
and a glowing core, pylons with missiles / tanks / bombs / rocket pods, gun
ports, stencils, exhaust soot and weathering. The slices store *material
indices*; the stack shader colours them from a palette (row = skin × class),
so every skin costs one palette row instead of a texture. The atlas is
cached in `user://cache` after the first start.

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
`--map=N` (0 tropical, 1 desert, 2 snow, 3 night, 4 ocean) switches map,
`--mode=N` (1 dogfight, 2 base strike, 3 duel) starts a team match, and
`--at=x,z[,y]` moves the jet, `--plane=i[,skin]` flies plane i without
touching the profile, `--gallery[=skin]` shows all 12 planes up close
(`--gallery=-1` one skin each, `--gview=x,y,z` camera offset).
