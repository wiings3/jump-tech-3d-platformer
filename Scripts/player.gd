extends CharacterBody3D

signal landing_approach(amount: float)              # 0..1 about-to-land meter
signal tech_window_open(duration: float)            # when the post-landing tap window opens
signal tech_result(tier: String, quality: float, impulse: float)

@export_category("Movement")
@export var speed := 9.0
@export var sprint_speed := 13.0
@export var accel_ground := 32.0
@export var accel_air := 12.0
@export var friction_ground := 18.0
@export var jump_velocity := 7.5
@export var max_fall_speed := 45.0
@export var cut_jump_factor := 0.55 # set to 1.0 to disable tap-short-jump

@export_category("Tap Tech")
@export var tech_grace_after := 0.14        # seconds AFTER landing where a tap can tech
@export var tech_press_cooldown := 0.10     # anti-spam: minimum time between tech taps
@export var tech_min_impact := 4.0          # minimum downward speed on landing to allow tech

# Tech buffer (tap BEFORE landing to auto-tech on landing)
@export var tech_buffer_before := 0.10      # seconds BEFORE landing where a tap is buffered
@export var tech_buffer_press_cooldown := 0.12 # anti-spam: limits how often air taps can refresh the buffer

@export var tech_base_impulse := 10.0       # always applied (scaled by timing quality)
@export var tech_impact_impulse := 1.2      # + impact_speed * this (scaled by timing quality)
@export var tech_max_impulse := 28.0        # clamp

@export var perfect_threshold := 0.85       # quality >= this is "PERFECT"
@export var perfect_bonus := 1.15           # extra impulse for perfect timing
@export var quality_exponent := 1.8         # higher = more reward for perfect timing

@export var tech_preserve_time := 0.22      # prevents burst being instantly smoothed away
@export var preserve_accel_scale := 0.20
@export var preserve_friction_scale := 0.25

# NEW: Always add a vertical "bounce" on tech, more if looking up
@export var tech_bounce_base := 2.2         # vertical velocity added on every tech (always)
@export var tech_bounce_up_bonus := 3.6     # extra vertical velocity when looking fully up
@export var tech_bounce_quality_scale := 0.25 # extra bounce scaling with timing quality (0 = no scaling)

@export_category("Aim Safety")
@export var clamp_downward_look := true     # prevents aiming straight down to "kill" the launch
@export var min_dir_y := -0.25              # if clamping, dir.y won't go below this

@export_category("Mouse Look")
@export var mouse_sens := 0.0022
@export var pitch_min_deg := -70.0
@export var pitch_max_deg := 70.0

@export_category("Debug")
@export var debug_tech := true              # TRUE by default so prints show

@export_category("Feedback")
@export var approach_show_distance := 2.2   # meters: start showing landing indicator
@export var approach_full_distance := 0.35  # meters: considered "very close" (meter ~1.0)

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var cam: Camera3D = $YawPivot/PitchPivot/Camera3D

@onready var ground_probe: RayCast3D = $GroundProbe

var _gravity := 24.0

# Event flags (reliable)
var _jump_pressed_event := false
var _jump_released_event := false

# Landing + tech state
var _was_on_floor := false
var _prev_vel_y := 0.0

var _tech_window_timer := 0.0      # counts down after landing
var _tech_press_cd := 0.0          # cooldown so spamming doesn't brute-force
var _last_impact_speed := 0.0      # impact speed from most recent landing

# buffer timers
var _tech_buffer_timer := 0.0      # counts down after an air tap (buffered tech)
var _tech_buffer_cd := 0.0         # limits air-tap spam

var _preserve_timer := 0.0         # preserves burst feel briefly
var _approach_smoothed := 0.0      # smoothing for approach meter

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if debug_tech:
		print("✅ Controller ready (Tap Tech + Look Direction + Buffer + Bounce)")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		_jump_pressed_event = true
	if event.is_action_released("jump"):
		_jump_released_event = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw_pivot.rotate_y(-event.relative.x * mouse_sens)

		var pitch: float = pitch_pivot.rotation.x - float(event.relative.y) * mouse_sens
		pitch = clamp(pitch, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
		pitch_pivot.rotation.x = pitch

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		)

func _physics_process(delta: float) -> void:
	# Timers
	_tech_window_timer = maxf(0.0, _tech_window_timer - delta)
	_tech_press_cd = maxf(0.0, _tech_press_cd - delta)
	_preserve_timer = maxf(0.0, _preserve_timer - delta)

	# buffer timers
	_tech_buffer_timer = maxf(0.0, _tech_buffer_timer - delta)
	_tech_buffer_cd = maxf(0.0, _tech_buffer_cd - delta)

	_update_landing_approach_feedback()

	# Movement input
	var move_input := Vector2.ZERO
	move_input.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	move_input.y = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	if move_input.length() > 1.0:
		move_input = move_input.normalized()

	var yaw_basis := Basis(Vector3.UP, yaw_pivot.rotation.y)
	var desired_dir := yaw_basis * Vector3(move_input.x, 0.0, -move_input.y)
	if desired_dir.length() > 0.001:
		desired_dir = desired_dir.normalized()

	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else speed

	# Floor state BEFORE movement
	var on_floor := is_on_floor()

	# Jump logic:
	# - If we are in the tech window, a jump tap triggers TECH (not a normal jump).
	# - Otherwise, normal jump if grounded.
	# - If in air and falling, a jump tap buffers tech for a short time before landing.
	if _jump_pressed_event:
		if on_floor and _tech_window_timer > 0.0 and _tech_press_cd <= 0.0:
			_do_tap_tech()
			# consume the press so it doesn't also jump
			_jump_pressed_event = false
		elif on_floor:
			velocity.y = jump_velocity
		else:
			# tech buffer (tap in air shortly before landing)
			if velocity.y < 0.0 and _tech_press_cd <= 0.0 and _tech_buffer_cd <= 0.0:
				_tech_buffer_timer = tech_buffer_before
				_tech_buffer_cd = tech_buffer_press_cooldown
				if debug_tech:
					print("🟨 TECH BUFFERED (air tap). buffer=", _tech_buffer_timer)

	# Variable jump (tap = shorter)
	if _jump_released_event and velocity.y > 0.0:
		velocity.y *= cut_jump_factor

	# Gravity
	if not on_floor:
		velocity.y -= _gravity * delta
		velocity.y = maxf(velocity.y, -max_fall_speed)

	# Horizontal movement
	var accel := accel_ground if on_floor else accel_air
	var friction := friction_ground

	# Preserve burst feel briefly after tech
	if on_floor and _preserve_timer > 0.0:
		accel *= preserve_accel_scale
		friction *= preserve_friction_scale

	var target_vel := desired_dir * target_speed
	velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)

	if on_floor and desired_dir.length() < 0.001:
		var f := friction * delta
		velocity.x = move_toward(velocity.x, 0.0, f)
		velocity.z = move_toward(velocity.z, 0.0, f)

	# Move + landing detect
	_prev_vel_y = velocity.y
	_was_on_floor = on_floor
	move_and_slide()
	on_floor = is_on_floor()

	# Just landed?
	if (not _was_on_floor) and on_floor:
		_last_impact_speed = maxf(0.0, -_prev_vel_y)

		# Only allow tech window/tech buffer if the landing had enough impact
		if _last_impact_speed >= tech_min_impact:
			# If the player buffered a tap shortly before landing, tech immediately on landing.
			if _tech_buffer_timer > 0.0 and _tech_press_cd <= 0.0:
				var raw_quality_from_buffer := 0.0
				if tech_buffer_before > 0.0:
					raw_quality_from_buffer = clampf(_tech_buffer_timer / tech_buffer_before, 0.0, 1.0)

				if debug_tech:
					print("🟩 BUFFER TECH TRIGGER on landing. impact=", _last_impact_speed, " buffer_quality=", raw_quality_from_buffer)

				_do_tap_tech(raw_quality_from_buffer)

				# consume timers
				_tech_window_timer = 0.0
				_tech_buffer_timer = 0.0
			else:
				# Normal: open the post-landing tap window
				_tech_window_timer = tech_grace_after

				# signal the HUD that the tap window is open
				emit_signal("tech_window_open", tech_grace_after)

				if debug_tech:
					print("⬛ LANDED impact=", _last_impact_speed, " -> tech window open for ", _tech_window_timer, "s")
		else:
			_tech_window_timer = 0.0
			_tech_buffer_timer = 0.0

	# Clear one-frame flags
	_jump_pressed_event = false
	_jump_released_event = false

func _do_tap_tech(raw_quality_override: float = -1.0) -> void:
	# Anti-spam cooldown
	_tech_press_cd = tech_press_cooldown

	# Timing quality:
	# - If override provided (buffer), use that.
	# - Otherwise use post-landing window timing.
	var raw_quality := 0.0
	if raw_quality_override >= 0.0:
		raw_quality = clampf(raw_quality_override, 0.0, 1.0)
	else:
		raw_quality = clampf(_tech_window_timer / tech_grace_after, 0.0, 1.0)

	var quality := pow(raw_quality, quality_exponent) # rewards tight timing

	var tier := "GOOD"
	if raw_quality >= perfect_threshold:
		tier = "PERFECT"
	elif raw_quality >= 0.60:
		tier = "GREAT"
	elif raw_quality >= 0.30:
		tier = "GOOD"
	else:
		tier = "EARLY"

	# Camera forward (for direction + bounce scaling)
	var cam_fwd := -cam.global_transform.basis.z
	if clamp_downward_look and cam_fwd.y < min_dir_y:
		cam_fwd.y = min_dir_y
	cam_fwd = cam_fwd.normalized()

	# Horizontal direction from where you're looking (ignores pitch for horizontal aim)
	var horiz_dir := Vector3(cam_fwd.x, 0.0, cam_fwd.z)
	if horiz_dir.length() < 0.001:
		# If looking straight up/down, fall back to yaw forward so tech still works
		var yaw_fwd := -yaw_pivot.global_transform.basis.z
		horiz_dir = Vector3(yaw_fwd.x, 0.0, yaw_fwd.z)
	if horiz_dir.length() > 0.001:
		horiz_dir = horiz_dir.normalized()

	# Impulse magnitude (horizontal)
	var impulse := (tech_base_impulse + _last_impact_speed * tech_impact_impulse) * lerpf(0.25, 1.0, quality)
	if tier == "PERFECT":
		impulse *= perfect_bonus
	impulse = clampf(impulse, 0.0, tech_max_impulse)

	# Apply horizontal impulse
	velocity.x += horiz_dir.x * impulse
	velocity.z += horiz_dir.z * impulse

	# NEW: Always add a vertical bounce, more if looking up
	var up_factor := clampf(cam_fwd.y, 0.0, 1.0) # 0 if not looking up, 1 if looking straight up
	var bounce := tech_bounce_base + up_factor * tech_bounce_up_bonus
	bounce *= lerpf(1.0, 1.0 + tech_bounce_quality_scale, quality) # slightly more bounce on better timing
	velocity.y = maxf(velocity.y, 0.0) + bounce

	# Preserve feel briefly so it doesn't get immediately smoothed away
	_preserve_timer = tech_preserve_time

	# Consume the tech window (one tech per landing)
	_tech_window_timer = 0.0

	# signal the HUD what tier you hit + how strong it was
	emit_signal("tech_result", tier, raw_quality, impulse)

	if debug_tech:
		print("🔥 TECH ", tier, " impulse=", impulse, " bounce=", bounce, " quality=", raw_quality, " up_factor=", up_factor)

func _update_landing_approach_feedback() -> void:
	# Only show while falling
	if is_on_floor() or velocity.y >= 0.0 or ground_probe == null:
		_approach_smoothed = lerpf(_approach_smoothed, 0.0, 20.0 * get_physics_process_delta_time())
		emit_signal("landing_approach", _approach_smoothed)
		return

	ground_probe.force_raycast_update()
	if not ground_probe.is_colliding():
		_approach_smoothed = lerpf(_approach_smoothed, 0.0, 20.0 * get_physics_process_delta_time())
		emit_signal("landing_approach", _approach_smoothed)
		return

	var hit_y := ground_probe.get_collision_point().y
	var dist := ground_probe.global_position.y - hit_y  # vertical distance
	if dist <= 0.0:
		_approach_smoothed = lerpf(_approach_smoothed, 0.0, 20.0 * get_physics_process_delta_time())
		emit_signal("landing_approach", _approach_smoothed)
		return

	# Map distance to 0..1 (close = high)
	var t := inverse_lerp(approach_show_distance, approach_full_distance, dist)
	t = clampf(t, 0.0, 1.0)
	t = 1.0 - t

	# Smooth for readability
	_approach_smoothed = lerpf(_approach_smoothed, t, 16.0 * get_physics_process_delta_time())
	emit_signal("landing_approach", _approach_smoothed)
