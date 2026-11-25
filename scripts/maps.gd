class_name Maps
## Map definitions: terrain palette, island share, relief type, city size,
## time of day, battle-area size, spawn altitude and landmarks.

enum { FEAT_NONE, FEAT_MESA, FEAT_PEAK }

const LIST := [
	{
		"id": "tropical", "name": "TROPICAL ISLANDS", "seed": 7, "land": 0.33, "feature": FEAT_NONE,
		"city": 1.0, "towns": 1.0, "time": -1.0, "clouds": 0.45, "half": 5600.0, "alt": 360.0,
		"carriers": false, "info": "Islands, a city and bright seas.",
		"pal": {"deepest": Color(0.07, 0.30, 0.66), "deep": Color(0.12, 0.45, 0.85), "shallow": Color(0.25, 0.78, 0.92),
			"sand": Color(0.96, 0.87, 0.62), "sand_wet": Color(0.86, 0.76, 0.52), "grass": Color(0.39, 0.76, 0.31),
			"grass_light": Color(0.55, 0.84, 0.36), "forest": Color(0.22, 0.56, 0.24), "frozen": false},
		"landmarks": [["lighthouse", Vector3(1800, 0, -900)], ["tower", Vector3(0, 0, 0)]],
	},
	{
		"id": "desert", "name": "DESERT CANYON", "seed": 21, "land": 0.86, "feature": FEAT_MESA,
		"city": 0.35, "towns": 0.6, "time": 0.66, "clouds": 0.15, "half": 5600.0, "alt": 420.0,
		"carriers": false, "info": "Mesas and canyons to fly through.",
		"pal": {"deepest": Color(0.10, 0.35, 0.55), "deep": Color(0.16, 0.48, 0.66), "shallow": Color(0.32, 0.66, 0.70),
			"sand": Color(0.93, 0.74, 0.48), "sand_wet": Color(0.80, 0.60, 0.40), "grass": Color(0.88, 0.66, 0.42),
			"grass_light": Color(0.95, 0.78, 0.52), "forest": Color(0.70, 0.46, 0.30), "frozen": false},
		"landmarks": [["needle", Vector3(0, 0, 0)], ["arch", Vector3(-2200, 0, 1400)]],
	},
	{
		"id": "snow", "name": "SNOW MOUNTAINS", "seed": 33, "land": 0.8, "feature": FEAT_PEAK,
		"city": 0.3, "towns": 0.5, "time": 0.31, "clouds": 0.55, "half": 5600.0, "alt": 700.0,
		"carriers": false, "info": "Peaks, valleys and a frozen lake.",
		"pal": {"deepest": Color(0.55, 0.70, 0.82), "deep": Color(0.66, 0.80, 0.90), "shallow": Color(0.78, 0.88, 0.95),
			"sand": Color(0.86, 0.90, 0.95), "sand_wet": Color(0.74, 0.80, 0.88), "grass": Color(0.93, 0.95, 0.98),
			"grass_light": Color(0.98, 0.99, 1.0), "forest": Color(0.26, 0.42, 0.34), "frozen": true},
		"landmarks": [["beacon", Vector3(0, 0, 0)]],
	},
	{
		"id": "night", "name": "NIGHT CITY", "seed": 7, "land": 0.38, "feature": FEAT_NONE,
		"city": 1.7, "towns": 1.4, "time": 0.0, "clouds": 0.35, "half": 5600.0, "alt": 380.0,
		"carriers": false, "info": "Neon skyline and searchlights.",
		"pal": {"deepest": Color(0.07, 0.30, 0.66), "deep": Color(0.12, 0.45, 0.85), "shallow": Color(0.25, 0.78, 0.92),
			"sand": Color(0.96, 0.87, 0.62), "sand_wet": Color(0.86, 0.76, 0.52), "grass": Color(0.39, 0.76, 0.31),
			"grass_light": Color(0.55, 0.84, 0.36), "forest": Color(0.22, 0.56, 0.24), "frozen": false},
		"landmarks": [["tower", Vector3(0, 0, 0)], ["tower", Vector3(1600, 0, 1200)]],
	},
	{
		"id": "ocean", "name": "OCEAN CARRIER", "seed": 55, "land": 0.05, "feature": FEAT_NONE,
		"city": 0.0, "towns": 0.0, "time": 0.5, "clouds": 0.6, "half": 5600.0, "alt": 380.0,
		"carriers": true, "info": "Two carrier fleets on the open ocean.",
		"pal": {"deepest": Color(0.05, 0.24, 0.55), "deep": Color(0.09, 0.36, 0.72), "shallow": Color(0.22, 0.66, 0.86),
			"sand": Color(0.96, 0.87, 0.62), "sand_wet": Color(0.86, 0.76, 0.52), "grass": Color(0.39, 0.70, 0.31),
			"grass_light": Color(0.55, 0.80, 0.36), "forest": Color(0.22, 0.50, 0.24), "frozen": false},
		"landmarks": [],
	},
]


static func by_index(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)]
