class_name Tutorial
extends Node
## Guided flight that teaches every move, one step at a time.

var game: Node
var step := -1
var _t := 0.0
var _ref := 0.0
var _seen := false

const STEPS := [
	"Drag LEFT or RIGHT to turn",
	"Drag DOWN to climb",
	"Drag UP to dive",
	"TAP the screen to barrel roll",
	"Press LOOP",
	"Hold GUN to fire the cannon",
	"Keep the drone ahead until the box turns RED, then MISSILE",
	"Incoming missile! ROLL as the two rings meet",
	"Tutorial complete - defend the city!",
]


func active() -> bool:
	return step >= 0


func text() -> String:
	return STEPS[step] if active() and step < STEPS.size() else ""


func start() -> void:
	step = 0
	_begin()


func stop() -> void:
	step = -1


func _begin() -> void:
	_t = 0.0
	_seen = false
	var jet: Jet = game.jet
	match step:
		0:
			_ref = 0.0
		1, 2:
			_ref = jet.position.y
		5:
			_ref = jet.ammo
		6:
			game.enemies.clear()
			var p: Vector3 = jet.position + jet.forward() * 260.0
			game.enemies.spawn(Enemies.DRONE, p)
			_ref = game.kills
		7:
			_ref = game.missiles.dodges
			game.missiles.fire_enemy(jet.position - jet.forward() * 260.0 + Vector3(0, 20, 0))
	Sfx.play("ui")


func _next() -> void:
	step += 1
	Sfx.play("clear", -6.0)
	if step >= STEPS.size():
		stop()
		game.end_tutorial()
		return
	_begin()


func process(delta: float) -> void:
	if not active() or step >= STEPS.size():
		return
	_t += delta
	var jet: Jet = game.jet
	var done := false
	match step:
		0:
			_ref += absf(jet.turn_rate) * delta
			done = _ref > 1.6
		1:
			done = jet.position.y > _ref + 40.0
		2:
			done = jet.position.y < _ref - 40.0
		3:
			_seen = _seen or jet.man == Jet.M_ROLL
			done = _seen and jet.man == Jet.M_NONE
		4:
			_seen = _seen or jet.man == Jet.M_LOOP
			done = _seen and jet.man == Jet.M_NONE
		5:
			done = jet.ammo <= _ref - 20.0 or jet.reloading > 0.0
		6:
			done = game.kills > _ref
			if not done and game.enemies.count_active() == 0 and _t > 2.0:
				_begin()
		7:
			done = game.missiles.dodges > _ref
			if not done and _t > 6.0:
				_begin()
		8:
			done = _t > 3.0
	if done:
		_next()
