# Sprite-stack PNG overrides

Every sprite stack in the game is generated procedurally at startup
(`scripts/sheet_gen.gd`). You can replace any of them with your own pixel art by
dropping a PNG in this folder — no code changes needed.

## File format

`assets/stacks/<name>.png`

* All slices of the object are laid out **side by side, left to right**,
  **bottom slice first** (leftmost = ground level, rightmost = top).
* Every slice is a **square**: its size equals the image height.
  A 160×16 image = 10 slices of 16×16 px.
* The **top of each slice is the FRONT** of the object (nose of a jet, bonnet of
  a car). The game rotates the object so that "up" in the image points along its
  heading.
* Transparent pixels (alpha < 50%) are cut out. Use the palette from
  `scripts/palette.gd` to match the game's look (the post-process snaps colours
  to it anyway).
* 1 pixel = 1 world unit (a street is 16 units wide, a car ~8×14, the player jet
  32×32).

Optional extras:

| File | Meaning |
| --- | --- |
| `<name>_emit.png` | Same layout; any non-black pixel glows (always on, gets bloom). |
| `<name>_<v>.png` | Override for variant `v` only (e.g. `car_2.png` = taxi). Must match the size of `<name>.png`; otherwise `<name>.png` is used for all variants. |

## Names

| name | default size | slices | variants | used for |
| --- | --- | --- | --- | --- |
| `jet` | 32×32 | 9 | 1 | player jet (also its ground shadow) |
| `enemy_jet` | 28×28 | 7 | 1 | enemy fighter |
| `drone` | 18×18 | 4 | 1 | enemy drone |
| `bomber` | 52×52 | 9 | 1 | enemy bomber |
| `aagun` | 14×14 | 7 | 1 | rooftop anti-air gun |
| `car` | 8×14 | 5 | 6 | cars (red, blue, taxi, white, green, police) |
| `bus` | 10×28 | 7 | 2 | bus, truck |
| `train` | 12×44 | 8 | 2 | locomotive, wagon |
| `boat` | 14×34 | 6 | 2 | speedboat, tug |
| `ship` | 30×96 | 10 | 1 | container ship |
| `airliner` | 56×56 | 8 | 1 | parked airliner |
| `tree` | 14×14 | 12 | 3 | round, pine, autumn |
| `bush` | 8×8 | 4 | 2 | bushes |
| `lamp` | 8×8 | 14 | 1 | street lamp (arm points +X) |
| `ac_unit` | 8×8 | 4 | 1 | rooftop AC |
| `water_tank` | 10×10 | 12 | 1 | rooftop water tank |
| `antenna` | 7×7 | 32 | 1 | rooftop antenna |
| `helipad` | 26×26 | 1 | 1 | rooftop helipad |
| `neon_sign` | 24×4 | 12 | 3 | rooftop neon sign |
| `chimney` | 10×10 | 36 | 1 | factory chimney |
| `crane` | 50×50 | 42 | 1 | construction / harbour crane |
| `container` | 8×20 | 8 | 4 | shipping containers |
| `fountain` | 18×18 | 4 | 1 | park fountain |
| `cloud` | 48×48 | 6 | 3 | cloud puffs |

Note: an override always uses square slices; non-square defaults (car, bus…)
must be padded to a square with transparent pixels.

Buildings are *collapsed stacks* (walls whose texture rows are the slices, plus a
roof) built from the facade atlas in `scripts/stack_lib.gd`; they are not
overridable here.
