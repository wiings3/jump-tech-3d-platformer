extends Node3D

@export var lifetime := 7.0
@export var fade_time := 1.0

@onready var visual: MeshInstance3D = $Visual

var _mat: StandardMaterial3D


func _ready() -> void:
	_setup_unique_material()
	_start_lifetime()


func _setup_unique_material() -> void:
	if visual == null:
		return

	var original_mat := visual.get_active_material(0)

	if original_mat is StandardMaterial3D:
		_mat = original_mat.duplicate() as StandardMaterial3D
	else:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(0.02, 0.02, 0.02, 1.0)

	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	visual.material_override = _mat


func _start_lifetime() -> void:
	await get_tree().create_timer(lifetime).timeout

	if _mat == null:
		queue_free()
		return

	var tween := create_tween()
	tween.tween_property(_mat, "albedo_color:a", 0.0, fade_time)
	tween.finished.connect(queue_free)
