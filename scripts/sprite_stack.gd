class_name SpriteStack
extends Node3D
## Reusable sprite-stack node. Draws `sheet` (N flat slices, bottom to top) at
## this node's position. Yaw comes from the node's global Y rotation and is
## applied on the GPU (optionally snapped to 64 steps, see pause menu).
## All SpriteStacks of the same sheet share ONE instanced draw call.

@export var sheet := "jet"
@export var variant := 0
@export var tint := Color.WHITE
@export var stack_scale := 1.0
## Sideways shear of upper slices, gives a cheap banking look.
var bank := 0.0
## 0..1 white hit flash.
var flash := 0.0

var _batch: StackBatch
var _slot := -1


func _enter_tree() -> void:
	var host: Node = get_tree().get_first_node_in_group("stack_world")
	if host == null:
		host = get_parent()
	_batch = StackBatch.shared(sheet, host)
	_slot = _batch.alloc()


func _exit_tree() -> void:
	if _batch != null and is_instance_valid(_batch):
		_batch.release(_slot)
	_slot = -1


func _process(_delta: float) -> void:
	if _slot < 0:
		return
	var vis := is_visible_in_tree()
	_batch.set_slot(_slot, global_position, global_rotation.y, variant, tint, bank, flash, stack_scale if vis else 0.0)
