class_name Wingmen
extends Node3D
## AI wingmen: fly in formation off the player's wing and break off to gun
## down enemies that come close.

var count := 1
var jet: Jet
var enemies: Enemies
var combat: Combat
var batch: StackBatch
var pos: Array[Vector3] = []
var yaw := PackedFloat32Array()
var roll := PackedFloat32Array()
var fire_cd := PackedFloat32Array()
var target: Array = []


func _ready() -> void:
	batch = StackBatch.new().setup("jet", 4)
	add_child(batch)


func reset() -> void:
	pos.clear()
	yaw.clear()
	roll.clear()
	fire_cd.clear()
	target.clear()
	for i in count:
		pos.append(_slot(i))
		yaw.append(jet.yaw)
		roll.append(0.0)
		fire_cd.append(0.0)
		target.append(null)


func _slot(i: int) -> Vector3:
	var side := 1.0 if i % 2 == 0 else -1.0
	var row := float(i / 2 + 1)
	return jet.position + jet.right() * side * 48.0 * row - jet.forward() * 40.0 * row + Vector3(0, 6, 0)


func _process(delta: float) -> void:
	batch.begin()
	if jet == null or not jet.alive:
		batch.end()
		return
	if pos.size() != count:
		reset()
	for i in count:
		var p := pos[i]
		var goal := _slot(i)
		var t: Object = target[i]
		if t == null or not t.active:
			t = null
			for e in enemies.pool:
				if e.active and e.type != Enemies.AAGUN and e.pos.distance_to(p) < 420.0:
					t = e
					break
			target[i] = t
		if t != null:
			goal = t.pos
		var to := goal - p
		var desired := atan2(-to.x, -to.z)
		var diff := wrapf(desired - yaw[i], -PI, PI)
		var rate := clampf(diff * 3.0, -1.6, 1.6)
		yaw[i] = wrapf(yaw[i] + rate * delta, -PI, PI)
		roll[i] = lerpf(roll[i], rate * 0.5, 1.0 - exp(-delta * 5.0))
		var dist := to.length()
		var spd := jet.speed * (1.25 if dist > 60.0 or t != null else 0.9)
		var f := Vector3(-sin(yaw[i]), 0.0, -cos(yaw[i]))
		p += f * spd * delta
		p.y = lerpf(p.y, goal.y, 1.0 - exp(-delta * 1.5))
		if t == null and dist < 25.0:
			p = p.lerp(goal, 1.0 - exp(-delta * 2.0))
			yaw[i] = lerp_angle(yaw[i], jet.yaw, 1.0 - exp(-delta * 3.0))
		pos[i] = p
		fire_cd[i] -= delta
		if t != null and dist < 300.0 and absf(diff) < 0.2 and fire_cd[i] <= 0.0:
			fire_cd[i] = 0.12
			combat.player_shoot(p + f * 16.0, (t.pos - p).normalized(), spd)
		batch.push_basis(p, Basis.from_euler(Vector3(0.0, yaw[i], roll[i])), 0, Color(0.85, 0.95, 1.1), 0.0)
	batch.end()
