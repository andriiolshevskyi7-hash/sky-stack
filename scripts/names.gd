class_name BotNames
## Bot nicknames that look like real players' handles.

const WORDS := ["Viper", "Nova", "Kraken", "Ghost", "Falcon", "Raven", "Blaze", "Frost", "Rogue", "Shadow",
	"Titan", "Comet", "Hawk", "Zephyr", "Nitro", "Pixel", "Bandit", "Storm", "Jinx", "Echo", "Maverik",
	"Spectre", "Wolf", "Orbit", "Lynx", "Drift", "Fury", "Onyx", "Talon", "Vortex", "Sky", "Ace", "Bolt"]
const PREFIX := ["x", "Dr", "Mr", "Big", "Lil", "Sir", "The", "Dark", "Iron", "Neo", "Pro", "Ultra", ""]
const SUFFIX := ["", "", "_YT", "TTV", "_pl", "_ua", "_br", "_ru", "_fr", "x", "_live", "_99", "_jr", "oo"]

static var _used := {}


static func make(rng: RandomNumberGenerator) -> String:
	for attempt in 20:
		var w: String = WORDS[rng.randi() % WORDS.size()]
		var n := ""
		match rng.randi() % 8:
			0:
				n = "xX_%s_Xx" % w
			1:
				n = "%s%d" % [w, rng.randi_range(1, 999)]
			2:
				n = "%s%s" % [PREFIX[rng.randi() % PREFIX.size()], w]
			3:
				n = "%s.%s" % [w.to_lower(), ["exe", "gg", "lol", "pro", "fx"][rng.randi() % 5]]
			4:
				n = "%s%s%d" % [w, SUFFIX[rng.randi() % SUFFIX.size()], rng.randi_range(0, 99)]
			5:
				n = "%s_%s" % [w, WORDS[rng.randi() % WORDS.size()]]
			6:
				n = w.to_upper() + str(rng.randi_range(1, 9))
			_:
				n = "%s%s" % [w, SUFFIX[rng.randi() % SUFFIX.size()]]
		if n.length() > 14:
			n = n.substr(0, 14)
		if not _used.has(n):
			_used[n] = true
			return n
	return "Pilot%d" % rng.randi_range(100, 999)


static func reset() -> void:
	_used.clear()
