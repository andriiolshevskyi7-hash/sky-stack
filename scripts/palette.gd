class_name Pal
## Shared limited retro palette (32 colours). Every procedurally generated
## sprite uses these colours, and the post-process snaps the final low-res
## image back onto them.

const HEX := [
	"0a0a14", "1a1c2c", "2a2f4e", "3b4a74", "4d6a9e", "6a9fd8", "a6d4f2", "f4f4f4",
	"c2c3c7", "8b8d96", "5f606b", "3a3a44", "5a3a2e", "8a5a3c", "c0864f", "e8c99b",
	"2d4a2a", "3f7a3a", "6fae4a", "b6d96a", "ffe066", "ffb43c", "f2772e", "c8402e",
	"8a2238", "ff5fa2", "b44cd6", "43e0d8", "2a8fbd", "1d5f8a", "ffd9a8", "6b2c5a",
]

const BLACK := 0
const NAVY_D := 1
const NAVY := 2
const BLUE_GRAY := 3
const STEEL := 4
const SKY := 5
const PALE := 6
const WHITE := 7
const LGRAY := 8
const GRAY := 9
const DGRAY := 10
const CHAR := 11
const BROWN_D := 12
const BROWN := 13
const TAN := 14
const BEIGE := 15
const GREEN_D := 16
const GREEN := 17
const GREEN_L := 18
const LIME := 19
const YELLOW := 20
const AMBER := 21
const ORANGE := 22
const RED := 23
const RED_D := 24
const PINK := 25
const PURPLE := 26
const CYAN := 27
const OCEAN := 28
const DEEP := 29
const WARM := 30
const PLUM := 31

static var _cols: Array[Color] = []


static func c(i: int) -> Color:
	if _cols.is_empty():
		for h in HEX:
			_cols.append(Color.html(h))
	return _cols[i]


## Palette as a 32x1 texture (for the post-process quantiser).
static func make_texture() -> ImageTexture:
	var img := Image.create(HEX.size(), 1, false, Image.FORMAT_RGBA8)
	for i in HEX.size():
		img.set_pixel(i, 0, c(i))
	return ImageTexture.create_from_image(img)
