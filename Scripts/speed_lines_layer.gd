extends CanvasLayer

@export var player_path: NodePath
@export var motion_lines_rect: ColorRect

@export_category("Motion Lines")
@export var speed_start := 14.0
@export var speed_full := 28.0
@export var max_line_alpha := 0.8
@export var min_clip_position := 0.16
@export var max_clip_position := 0.34
@export var min_speed_scale := 10.0
@export var max_speed_scale := 28.0
@export var line_density := 0.02
@export var fade_in_speed := 10.0
@export var fade_out_speed := 8.0

var _player: CharacterBody3D
var _line_alpha := 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody3D

	if motion_lines_rect != null:
		motion_lines_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_shader_values(0.0, min_speed_scale, max_clip_position)


func _process(delta: float) -> void:
	if _player == null or motion_lines_rect == null:
		return

	var horizontal_velocity := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	var horizontal_speed := horizontal_velocity.length()

	var speed_percent := inverse_lerp(speed_start, speed_full, horizontal_speed)
	speed_percent = clampf(speed_percent, 0.0, 1.0)

	var target_alpha := speed_percent * max_line_alpha
	var target_speed_scale := lerpf(min_speed_scale, max_speed_scale, speed_percent)

	# Lower clip position means lines come closer to the center at high speed.
	var target_clip_position := lerpf(max_clip_position, min_clip_position, speed_percent)

	var lerp_speed := fade_in_speed if target_alpha > _line_alpha else fade_out_speed
	_line_alpha = lerpf(_line_alpha, target_alpha, lerp_speed * delta)

	_set_shader_values(_line_alpha, target_speed_scale, target_clip_position)


func _set_shader_values(alpha: float, speed_scale: float, clip_position: float) -> void:
	var mat := motion_lines_rect.material as ShaderMaterial

	if mat == null:
		return

	mat.set_shader_parameter("line_alpha", alpha)
	mat.set_shader_parameter("speedScale", speed_scale)
	mat.set_shader_parameter("clipPosition", clip_position)
	mat.set_shader_parameter("line_density", line_density)
