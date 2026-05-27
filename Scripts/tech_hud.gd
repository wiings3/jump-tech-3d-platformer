extends CanvasLayer

@export var player_path: NodePath

@export_category("Tier SFX")
@export var sfx_early: AudioStream
@export var sfx_good: AudioStream
@export var sfx_great: AudioStream
@export var sfx_perfect: AudioStream
@export var sfx_volume_db := -2.0
@export var sfx_pitch_random := 0.06

@export_category("Lightning FX")
@export var fx_fade_out := 0.20
@export var fx_peak_early := 0.30
@export var fx_peak_good := 0.45
@export var fx_peak_great := 0.65
@export var fx_peak_perfect := 1.2


@onready var approach_label: Label = $Root/ApproachLabel
@onready var approach_bar: ProgressBar = $Root/ApproachBar
@onready var tier_label: Label = $Root/TierLabel
@onready var lightning_fx: ColorRect = $Root/LightningFX
@onready var sfx: AudioStreamPlayer = $SFX

var _tween: Tween
var _fx_tween: Tween
var _fx_mat: ShaderMaterial

func _ready() -> void:
	approach_label.visible = false
	approach_bar.visible = false
	tier_label.text = ""
	tier_label.modulate.a = 0.0

	if sfx:
		sfx.volume_db = sfx_volume_db

	_fx_mat = lightning_fx.material as ShaderMaterial
	if _fx_mat:
		_fx_mat.set_shader_parameter("intensity", 0.0)

	var player := get_node_or_null(player_path)
	if player == null:
		push_error("TechHUD: player_path not set / invalid")
		return

	player.landing_approach.connect(_on_landing_approach)
	player.tech_window_open.connect(_on_tech_window_open)
	player.tech_result.connect(_on_tech_result)

func _on_landing_approach(amount: float) -> void:
	if amount > 0.02:
		approach_label.visible = true
		approach_bar.visible = true
		approach_label.text = "LANDING…"
	else:
		approach_label.visible = false
		approach_bar.visible = false

	approach_bar.value = amount

func _on_tech_window_open(duration: float) -> void:
	approach_label.visible = true
	approach_bar.visible = true
	approach_label.text = "TAP JUMP!"

func _on_tech_result(tier: String, quality: float, impulse: float) -> void:
	# Visual tier label
	tier_label.text = "%s" % tier
	tier_label.scale = Vector2.ONE
	tier_label.modulate.a = 1.0

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(tier_label, "scale", Vector2(1.25, 1.25), 0.06)
	_tween.tween_property(tier_label, "scale", Vector2.ONE, 0.12)
	_tween.tween_interval(0.25)
	_tween.tween_property(tier_label, "modulate:a", 0.0, 0.20)

	# Audio tier SFX
	_play_tier_sfx(tier)

	# Lightning overlay burst
	_trigger_lightning(tier, quality)

func _play_tier_sfx(tier: String) -> void:
	if sfx == null:
		return

	var stream_to_play: AudioStream = null
	match tier:
		"PERFECT":
			stream_to_play = sfx_perfect
		"GREAT":
			stream_to_play = sfx_great
		"GOOD":
			stream_to_play = sfx_good
		"EARLY":
			stream_to_play = sfx_early
		_:
			stream_to_play = sfx_good

	if stream_to_play == null:
		return

	sfx.stream = stream_to_play
	sfx.volume_db = sfx_volume_db
	sfx.pitch_scale = randf_range(1.0 - sfx_pitch_random, 1.0 + sfx_pitch_random) if sfx_pitch_random > 0.0 else 1.0
	sfx.play()

func _trigger_lightning(tier: String, quality: float) -> void:
	if _fx_mat == null:
		return

	var peak := fx_peak_good
	match tier:
		"PERFECT":
			peak = fx_peak_perfect
		"GREAT":
			peak = fx_peak_great
		"GOOD":
			peak = fx_peak_good
		"EARLY":
			peak = fx_peak_early

	# Small quality influence (nice for “tight timing” feel)
	peak *= lerpf(0.9, 1.05, clampf(quality, 0.0, 1.0))

	if _fx_tween and _fx_tween.is_valid():
		_fx_tween.kill()

	# pop fast, fade out smooth
	_fx_mat.set_shader_parameter("intensity", 0.0)
	_fx_tween = create_tween()
	_fx_tween.tween_method(func(v: float): _fx_mat.set_shader_parameter("intensity", v), 0.0, peak, 0.045)
	_fx_tween.tween_method(func(v: float): _fx_mat.set_shader_parameter("intensity", v), peak, 0.0, fx_fade_out)
