extends CharacterBody3D

signal landing_approach(amount: float)              # 0..1 about-to-land meter
signal tech_window_open(duration: float)            # when the post-landing tap window opens
signal tech_result(tier: String, quality: float, impulse: float)

@export_category("Movement")
## Normal movement speed when sprint is not held.
@export var speed := 9.0
## Movement speed used while the sprint input is held.
@export var sprint_speed := 13.0
## How quickly the player accelerates while on the ground.
@export var accel_ground := 32.0
## How quickly the player accelerates and changes direction while in the air.
@export var accel_air := 12.0
## How quickly the player slows down on the ground when no movement input is pressed.
@export var friction_ground := 18.0
## How quickly extra earned speed above normal movement speed bleeds away on the ground.
@export var ground_momentum_decay := 5.0
## How quickly extra earned speed above normal movement speed bleeds away in the air.
@export var air_momentum_decay := 2.0
## Maximum horizontal speed the player can reach from sprinting, techs, slides, and momentum chaining.
@export var max_horizontal_speed := 65.0
## Upward velocity applied when the player jumps.
@export var jump_velocity := 7.5
## Maximum downward falling speed.
@export var max_fall_speed := 45.0
## Multiplier applied to upward velocity when jump is released early. Set to 1.0 to disable tap-short-jump.
@export var cut_jump_factor := 0.55 # set to 1.0 to disable tap-short-jump
## Gravity Multiplier
@export var gravity_multiplier := 1.4

@export_category("Slide")
## How long the slide lasts before ending automatically.
@export var slide_duration := 0.85
## Time before landing where a slide input is buffered and starts immediately on touchdown.
@export var slide_buffer_before := 0.12
## Horizontal speeds below this are treated as no meaningful slide momentum. The slide still starts, but it will not move the player.
@export var slide_min_momentum_speed := 0.05
## How much speed the slide loses per second. Lower values preserve momentum longer.
@export var slide_speed_decay := 1.5
## Extra upward velocity used when jumping out of a perfectly timed slide.
@export var slide_jump_up_velocity := 9.0
## Lowest momentum multiplier used when slide-jumping with poor timing.
@export var slide_jump_min_multiplier := 1.0
## Highest momentum multiplier used when slide-jumping with perfect timing.
@export var slide_jump_max_multiplier := 1.25
## Time before the slide ends where the jump is considered perfect.
@export var slide_perfect_window := 0.12
## Larger timing window used to calculate partial slide-jump quality.
@export var slide_good_window := 0.45
## Higher values make bad slide-jump timing weaker and perfect timing more rewarding.
@export var slide_quality_exponent := 1.5
## Time after a slide jump where movement smoothing is reduced so the boost is preserved.
@export var slide_jump_preserve_time := 0.25
## Short time after a slide jump where normal air movement cannot immediately dampen the boost.
@export var slide_jump_lock_time := 0.06
## How far the camera/arms lower while sliding. Negative values make the player feel shorter.
@export var slide_camera_y_offset := -0.75
## How quickly the camera/arms move into and out of slide height.
@export var slide_camera_lerp_speed := 14.0

@export_category("Tap Tech")
## Seconds after landing where pressing jump performs a tech instead of a normal jump.
@export var tech_grace_after := 0.14        # seconds AFTER landing where a tap can tech
## Minimum time between tech inputs to prevent spam.
@export var tech_press_cooldown := 0.10     # anti-spam: minimum time between tech taps
## Minimum downward impact speed required for a landing to allow a tech.
@export var tech_min_impact := 4.0          # minimum downward speed on landing to allow tech
# Tech buffer (tap BEFORE landing to auto-tech on landing)
## Seconds before landing where a jump press can be buffered into an automatic tech.
@export var tech_buffer_before := 0.10      # seconds BEFORE landing where a tap is buffered
## Minimum time between air buffer taps so the player cannot constantly refresh the tech buffer.
@export var tech_buffer_press_cooldown := 0.12 # anti-spam: limits how often air taps can refresh the buffer
## Base horizontal impulse applied by a successful tech.
@export var tech_base_impulse := 10.0       # always applied (scaled by timing quality)
## Extra tech impulse gained from landing impact speed.
@export var tech_impact_impulse := 1.2      # + impact_speed * this (scaled by timing quality)
## Maximum horizontal impulse a tech can apply.
@export var tech_max_impulse := 28.0        # clamp
## Timing quality required for a tech to count as PERFECT.
@export var perfect_threshold := 0.85       # quality >= this is "PERFECT"
## Extra impulse multiplier applied to PERFECT techs.
@export var perfect_bonus := 1.15           # extra impulse for perfect timing
## Controls how strongly timing quality affects tech power. Higher values make perfect timing more important.
@export var quality_exponent := 1.8         # higher = more reward for perfect timing
## Time after a tech where acceleration and friction are reduced to preserve the launch burst.
@export var tech_preserve_time := 0.30      # prevents burst being instantly smoothed away
## Ground acceleration multiplier during the tech preserve window.
@export var preserve_accel_scale := 0.15
## Ground friction multiplier during the tech preserve window.
@export var preserve_friction_scale := 0.10
# NEW: Always add a vertical "bounce" on tech, more if looking up
## Base upward velocity added by every successful tech.
@export var tech_bounce_base := 2.2         # vertical velocity added on every tech (always)
## Extra upward velocity added when the player is looking upward during a tech.
@export var tech_bounce_up_bonus := 3.6     # extra vertical velocity when looking fully up
## How much better tech timing increases the vertical bounce. Set to 0.0 to disable timing-based bounce scaling.
@export var tech_bounce_quality_scale := 0.25 # extra bounce scaling with timing quality (0 = no scaling)

@export_category("Wall Tech")
## Seconds after touching a wall where a wall tech can be performed.
@export var wall_tech_window := 0.12
## Minimum dot product used to determine whether a surface is a wall.
@export var wall_min_verticality := 0.7
## Upward velocity added during a wall tech.
@export var wall_tech_up_velocity := 4.5
## How strongly the wall normal influences the redirect.
@export var wall_tech_normal_strength := 0.85
## How much speed is preserved.
@export var wall_tech_speed_preserve := 1.0
## Short time after wall tech where air steering is reduced so W doesn't instantly cancel the redirect.
@export var wall_tech_input_lock_time := 0.08
## Seconds before wall contact where pressing jump can buffer a wall tech.
@export var wall_tech_buffer_before := 0.10
## Minimum time between wall tech buffer presses so it cannot be spam-refreshed constantly.
@export var wall_tech_buffer_press_cooldown := 0.10
## Tiny freeze after pressing wall tech before the redirect launches.
@export var wall_tech_freeze_time := 0.055

@export_category("Landing Shadow")
## Maximum distance the landing shadow ray checks below the player.
@export var shadow_max_distance := 20.0
## Smallest shadow scale when the player is far from the ground.
@export var shadow_min_scale := 0.35
## Largest shadow scale when the player is close to the ground.
@export var shadow_max_scale := 1.5
## Small offset above the ground to prevent the shadow from flickering into the floor.
@export var shadow_ground_offset := 0.03

@onready var landing_shadow_ray: RayCast3D = $LandingShadowRay
@onready var landing_shadow: MeshInstance3D = $LandingShadow

@export_category("Aim Safety")
## Prevents looking too far downward from weakening or cancelling tech launch direction.
@export var clamp_downward_look := true     # prevents aiming straight down to "kill" the launch
## Lowest allowed Y value for the camera forward direction when downward look clamping is enabled.
@export var min_dir_y := -0.25              # if clamping, dir.y won't go below this

@export_category("Mouse Look")
## Mouse sensitivity for camera rotation.
@export var mouse_sens := 0.0022
## Lowest vertical look angle in degrees.
@export var pitch_min_deg := -70.0
## Highest vertical look angle in degrees.
@export var pitch_max_deg := 70.0

@export_category("Debug")
## Enables debug print messages for controller, landing, buffer, and tech behavior.
@export var debug_tech := true              # TRUE by default so prints show
## Shows useful player movement/debug values on screen.
@export var show_debug_hud := true

@onready var debug_label: Label = $DebugCanvas/DebugLabel

@export_category("Feedback")
## Distance from the ground where the landing approach feedback starts appearing.
@export var approach_show_distance := 2.2   # meters: start showing landing indicator
## Distance from the ground where the landing approach feedback is considered fully active.
@export var approach_full_distance := 0.35  # meters: considered "very close" (meter ~1.0)
@export var base_fov := 75.0
@export var max_speed_fov := 92.0
@export var fov_speed_start := 18.0
@export var fov_speed_full := 65.0
@export var fov_lerp_speed := 10.0
@export var wall_tech_fov_bonus := 8.0
@export var wall_tech_fov_time := 0.12
@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var cam: Camera3D = $YawPivot/PitchPivot/Camera3D

@onready var ground_probe: RayCast3D = $GroundProbe

@export_category("Finger Gun")
## Maximum number of finger-gun shots before the player needs to reload.
@export var finger_gun_max_ammo := 6
## Default arm animation played when the player is not firing, broken, or reloading.
@export var idle_arm_anim := "finger_gun_idle"
## Animation played when the player successfully fires the finger gun.
@export var finger_gun_fire_anim := "finger_gun_fire"
## Animation played when the player tries to fire with no ammo.
@export var finger_gun_broken_anim := "finger_gun_broken"
## Animation played when the player reloads/fixes the finger gun.
@export var finger_gun_fix_anim := "finger_gun_fix"
## Blend time when switching between finger-gun animations.
@export var finger_gun_blend_time := 0.05

@onready var finger_gun_reload_audio_player: AudioStreamPlayer = $FingerGunReloadAudioPlayer
@onready var finger_gun_audio_player: AudioStreamPlayer = $FingerGunAudioPlayer
@onready var arm_rig: Node3D = $YawPivot/PitchPivot/ArmRig
@onready var arms_anim: AnimationPlayer = arm_rig.find_child("AnimationPlayer", true, false) as AnimationPlayer

@export_category("Bullet Impacts")
## Scene spawned on surfaces hit by the finger gun raycast.
@export var bullet_hole_scene: PackedScene
## Maximum distance the finger gun can hit.
@export var finger_gun_range := 100.0
## How far the bullet hole is pushed away from the wall to prevent z-fighting.
@export var bullet_hole_surface_offset := 0.01
## Random rotation applied to each bullet hole so repeated shots look less identical.
@export var bullet_hole_random_rotation := true

var _finger_gun_ammo := 6
var _finger_gun_busy := false
var _finger_gun_reloading := false
var _queued_finger_gun_fire := false
var _queued_finger_gun_reload := false
var _finger_gun_broken_idle := false

var _gravity := 24.0

# Event flags (reliable)
var _jump_pressed_event := false
var _jump_released_event := false
var _slide_pressed_event := false

# Slide state
var _is_sliding := false
var _slide_elapsed := 0.0
var _slide_dir: Vector3 = Vector3.ZERO
var _slide_speed := 0.0
var _standing_yaw_pivot_y := 0.0
var _slide_jump_lock_timer := 0.0
var _slide_buffer_timer := 0.0

# Landing + tech state
var _was_on_floor := false
var _prev_vel_y := 0.0

var _tech_window_timer := 0.0      # counts down after landing
var _tech_press_cd := 0.0          # cooldown so spamming doesn't brute-force
var _last_impact_speed := 0.0      # impact speed from most recent landing

# Wall Tech
var _wall_tech_timer := 0.0
var _last_wall_normal := Vector3.ZERO
var _wall_tech_input_lock_timer := 0.0
var _wall_tech_buffer_timer := 0.0
var _wall_tech_buffer_cd := 0.0
var _wall_tech_freeze_timer := 0.0
var _wall_tech_pending := false
var _wall_tech_stored_velocity := Vector3.ZERO
var _wall_tech_stored_normal := Vector3.ZERO
var _wall_tech_fov_timer := 0.0

# buffer timers
var _tech_buffer_timer := 0.0      # counts down after an air tap (buffered tech)
var _tech_buffer_cd := 0.0         # limits air-tap spam

var _preserve_timer := 0.0         # preserves burst feel briefly
var _approach_smoothed := 0.0      # smoothing for approach meter
var _pre_collision_velocity := Vector3.ZERO

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity")) * gravity_multiplier
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_standing_yaw_pivot_y = yaw_pivot.position.y

	_finger_gun_ammo = finger_gun_max_ammo

	if landing_shadow != null:
		landing_shadow.top_level = true

	if arms_anim == null:
		push_warning("No AnimationPlayer found inside ArmRig.")
	else:
		arms_anim.play(StringName(idle_arm_anim))

		if not arms_anim.animation_finished.is_connected(_on_arms_animation_finished):
			arms_anim.animation_finished.connect(_on_arms_animation_finished)

	if debug_tech:
		print("✅ Controller ready (Tap Tech + Look Direction + Buffer + Bounce)")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		_jump_pressed_event = true

	if event.is_action_released("jump"):
		_jump_released_event = true

	if event.is_action_pressed("slide"):
		_slide_pressed_event = true
		_slide_buffer_timer = slide_buffer_before

	if event.is_action_pressed("attack"):
		_request_finger_gun_fire()

	if event.is_action_pressed("reload"):
		_request_finger_gun_reload()

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

	_tech_buffer_timer = maxf(0.0, _tech_buffer_timer - delta)
	_tech_buffer_cd = maxf(0.0, _tech_buffer_cd - delta)

	_wall_tech_timer = maxf(_wall_tech_timer - delta, 0.0)
	_wall_tech_input_lock_timer = maxf(_wall_tech_input_lock_timer - delta, 0.0)
	_wall_tech_buffer_timer = maxf(_wall_tech_buffer_timer - delta, 0.0)
	_wall_tech_buffer_cd = maxf(_wall_tech_buffer_cd - delta, 0.0)
	_wall_tech_freeze_timer = maxf(_wall_tech_freeze_timer - delta, 0.0)
	_wall_tech_fov_timer = maxf(_wall_tech_fov_timer - delta, 0.0)
	
	_slide_jump_lock_timer = maxf(0.0, _slide_jump_lock_timer - delta)
	_slide_buffer_timer = maxf(0.0, _slide_buffer_timer - delta)

	if _is_sliding:
		_slide_elapsed += delta
	_update_slide_visuals(delta)
	
	_update_landing_approach_feedback()
	
	_update_landing_shadow()

	# Wall-tech hit-stop / aim-stop:
	# Freeze player physics briefly, but mouse look still works because camera input is handled in _unhandled_input().
	if _wall_tech_pending:
		velocity = _wall_tech_stored_velocity

		if _wall_tech_freeze_timer <= 0.0:
			_last_wall_normal = _wall_tech_stored_normal
			_wall_tech_pending = false
			_do_wall_tech()

		_update_debug_hud()

		_jump_pressed_event = false
		_jump_released_event = false
		_slide_pressed_event = false
		return
	
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

	# Start slide while already grounded
	if _has_slide_request() and on_floor and not _is_sliding:
		if _try_start_slide(desired_dir):
			_consume_slide_request()

	# Jump logic:
	# - If we are in the tech window, a jump tap triggers TECH (not a normal jump).
	# - Otherwise, normal jump if grounded.
	# - If in air and falling, a jump tap buffers tech for a short time before landing.
	if _jump_pressed_event:
		if _is_sliding and on_floor:
			_do_slide_jump()
			on_floor = false

		elif on_floor and _tech_window_timer > 0.0 and _tech_press_cd <= 0.0:
			_do_tap_tech()

		elif on_floor:
			velocity.y = jump_velocity

		else:
			if _wall_tech_timer > 0.0:
				_start_wall_tech_freeze()

			else:
				if _wall_tech_buffer_cd <= 0.0:
					_wall_tech_buffer_timer = wall_tech_buffer_before
					_wall_tech_buffer_cd = wall_tech_buffer_press_cooldown

					if debug_tech:
						print("🟦 WALL TECH BUFFERED. buffer=", _wall_tech_buffer_timer)

				if velocity.y < 0.0 and _tech_press_cd <= 0.0 and _tech_buffer_cd <= 0.0:
					_tech_buffer_timer = tech_buffer_before
					_tech_buffer_cd = tech_buffer_press_cooldown

					if debug_tech:
						print("🟨 TECH BUFFERED (air tap). buffer=", _tech_buffer_timer)

		_jump_pressed_event = false
				
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
	
	if _wall_tech_input_lock_timer > 0.0:
		accel *= 0.05
		
	# Preserve burst feel briefly after tech or slide jump
	if _preserve_timer > 0.0:
		accel *= preserve_accel_scale
		if on_floor:
			friction *= preserve_friction_scale

	if _slide_jump_lock_timer > 0.0:
		# Preserve the slide-jump burst briefly so it feels like a real tech.
		pass
	elif _is_sliding and on_floor:
		_slide_speed = maxf(0.0, _slide_speed - slide_speed_decay * delta)

		velocity.x = _slide_dir.x * _slide_speed
		velocity.z = _slide_dir.z * _slide_speed
	else:
		var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
		var horizontal_speed := horizontal_velocity.length()

		if desired_dir.length() > 0.001:
			# Normal movement speed is only the baseline.
			# If the player has earned extra momentum, preserve it briefly, then bleed it back toward normal speed.
			if horizontal_speed <= target_speed:
				var target_vel := desired_dir * target_speed
				velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
				velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)
			else:
				var current_dir := horizontal_velocity.normalized()
				var steer_strength := clampf(accel * delta / horizontal_speed, 0.0, 1.0)
				var new_dir := current_dir.slerp(desired_dir.normalized(), steer_strength).normalized()

				var preserved_speed := horizontal_speed

				if _preserve_timer <= 0.0:
					var decay := ground_momentum_decay if on_floor else air_momentum_decay
					preserved_speed = move_toward(preserved_speed, target_speed, decay * delta)

				velocity.x = new_dir.x * preserved_speed
				velocity.z = new_dir.z * preserved_speed
		else:
			# No input should not kill airborne momentum.
			# Ground friction still slows the player when grounded.
			if on_floor:
				var f := friction * delta
				velocity.x = move_toward(velocity.x, 0.0, f)
				velocity.z = move_toward(velocity.z, 0.0, f)

	_cap_horizontal_speed()

	# Move + landing detect
	_prev_vel_y = velocity.y
	_was_on_floor = on_floor
	_pre_collision_velocity = velocity
	move_and_slide()
	on_floor = is_on_floor()

	if not is_on_floor():
		for i in get_slide_collision_count():
			var collision := get_slide_collision(i)

			if collision == null:
				continue

			var normal := collision.get_normal()

			# Mostly vertical wall?
			if abs(normal.y) < wall_min_verticality:
				_last_wall_normal = normal
				_wall_tech_timer = wall_tech_window

				if _wall_tech_buffer_timer > 0.0:
					_start_wall_tech_freeze()
					_wall_tech_buffer_timer = 0.0

				if debug_tech:
					print("WALL CONTACT")

	var just_landed := (not _was_on_floor) and on_floor

	# Start buffered slide immediately on touchdown.
	if just_landed and _has_slide_request() and not _is_sliding:
		if _try_start_slide(desired_dir):
			_consume_slide_request()

	if _is_sliding and ((not on_floor) or _slide_elapsed >= slide_duration):
		_end_slide()

	# Just landed?
	if just_landed:
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
			
	_update_debug_hud()
	_update_camera_fov(delta)
	
	# Clear one-frame flags
	_jump_pressed_event = false
	_jump_released_event = false
	_slide_pressed_event = false

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
	_cap_horizontal_speed()

	# NEW: Always add a vertical "bounce", more if looking up
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

func _start_wall_tech_freeze() -> void:
	if _wall_tech_pending:
		return

	_wall_tech_pending = true
	_wall_tech_freeze_timer = wall_tech_freeze_time
	_wall_tech_stored_velocity = _pre_collision_velocity
	_wall_tech_stored_normal = _last_wall_normal

	_wall_tech_timer = 0.0
	_wall_tech_buffer_timer = 0.0

	if debug_tech:
		print("🧊 WALL TECH FREEZE time=", wall_tech_freeze_time)

func _do_wall_tech() -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var current_speed := horizontal_velocity.length()

	if current_speed < 0.1:
		return

	var wall_normal := Vector3(_last_wall_normal.x, 0.0, _last_wall_normal.z)

	if wall_normal.length() < 0.001:
		return

	wall_normal = wall_normal.normalized()

	# Use camera direction so the player controls the redirect.
	var cam_fwd := -cam.global_transform.basis.z
	var aim_dir := Vector3(cam_fwd.x, 0.0, cam_fwd.z)

	if aim_dir.length() < 0.001:
		aim_dir = horizontal_velocity.normalized()
	else:
		aim_dir = aim_dir.normalized()

	# If the player aims into the wall, project that aim along the wall instead.
	var into_wall_amount := aim_dir.dot(-wall_normal)

	if into_wall_amount > 0.75:
		# Looking almost directly into the wall.
		# Kick straight backward off the wall.
		aim_dir = wall_normal
	elif into_wall_amount > 0.0:
		# Looking partly into the wall.
		# Slide the aim along the wall instead of letting the player tech into it.
		aim_dir = (aim_dir + wall_normal * into_wall_amount).normalized()

	# Add a small push away from the wall so you don't scrape/stick.
	var redirect_dir := (aim_dir + wall_normal * 0.15).normalized()

	var new_speed := current_speed * wall_tech_speed_preserve

	velocity.x = redirect_dir.x * new_speed
	velocity.z = redirect_dir.z * new_speed
	velocity.y = maxf(velocity.y, 0.0) + wall_tech_up_velocity

	_cap_horizontal_speed()

	_wall_tech_timer = 0.0
	_last_wall_normal = Vector3.ZERO
	_preserve_timer = maxf(_preserve_timer, tech_preserve_time)
	_wall_tech_input_lock_timer = wall_tech_input_lock_time
	_wall_tech_fov_timer = wall_tech_fov_time
	
	if debug_tech:
		print("🟦 WALL TECH speed=", current_speed, " redirect=", redirect_dir, " normal=", wall_normal)

func _cap_horizontal_speed() -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var horizontal_speed := horizontal_velocity.length()

	if horizontal_speed <= max_horizontal_speed:
		return

	var capped_velocity := horizontal_velocity.normalized() * max_horizontal_speed
	velocity.x = capped_velocity.x
	velocity.z = capped_velocity.z

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

func _has_slide_request() -> bool:
	return _slide_pressed_event or _slide_buffer_timer > 0.0

func _consume_slide_request() -> void:
	_slide_pressed_event = false
	_slide_buffer_timer = 0.0

func _try_start_slide(desired_dir: Vector3) -> bool:
	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var current_speed: float = horizontal_velocity.length()

	if horizontal_velocity.length() > slide_min_momentum_speed:
		_slide_dir = horizontal_velocity.normalized()
	elif desired_dir.length() > 0.001:
		_slide_dir = desired_dir.normalized()
	else:
		var yaw_fwd := -yaw_pivot.global_transform.basis.z
		_slide_dir = Vector3(yaw_fwd.x, 0.0, yaw_fwd.z)

		if _slide_dir.length() > 0.001:
			_slide_dir = _slide_dir.normalized()
		else:
			_slide_dir = Vector3.ZERO

	_is_sliding = true
	_slide_elapsed = 0.0
	_slide_speed = current_speed if current_speed > slide_min_momentum_speed else 0.0

	if debug_tech:
		print("Slide started. Preserving speed: ", _slide_speed)

	return true

func _do_slide_jump() -> void:
	if not _is_sliding:
		return

	var quality: float = _get_slide_jump_quality()
	var multiplier: float = lerpf(slide_jump_min_multiplier, slide_jump_max_multiplier, quality)
	var final_speed: float = _slide_speed * multiplier
	var up_velocity: float = lerpf(jump_velocity, slide_jump_up_velocity, quality)
	var tier: String = _get_slide_jump_tier(quality)

	velocity.x = _slide_dir.x * final_speed
	velocity.z = _slide_dir.z * final_speed
	velocity.y = up_velocity
	_cap_horizontal_speed()

	_slide_jump_lock_timer = slide_jump_lock_time
	_preserve_timer = maxf(_preserve_timer, slide_jump_preserve_time)

	_end_slide()

	if debug_tech:
		print("Slide Jump ", tier, " quality=", quality, " multiplier=", multiplier, " final_speed=", final_speed, " up_velocity=", up_velocity)

func _get_slide_jump_quality() -> float:
	if slide_duration <= 0.0:
		return 0.0

	var time_until_slide_end: float = slide_duration - _slide_elapsed

	if time_until_slide_end <= slide_perfect_window:
		return 1.0

	if time_until_slide_end >= slide_good_window:
		return 0.0

	var window_size: float = maxf(slide_good_window - slide_perfect_window, 0.001)
	var raw_quality: float = 1.0 - clampf((time_until_slide_end - slide_perfect_window) / window_size, 0.0, 1.0)

	return pow(raw_quality, slide_quality_exponent)

func _get_slide_jump_tier(quality: float) -> String:
	if quality >= 0.90:
		return "PERFECT"
	elif quality >= 0.65:
		return "GREAT"
	elif quality >= 0.35:
		return "GOOD"

	return "WEAK"

func _end_slide() -> void:
	_is_sliding = false
	_slide_elapsed = 0.0
	_slide_dir = Vector3.ZERO
	_slide_speed = 0.0

func _request_finger_gun_fire() -> void:
	if arms_anim == null:
		return

	# Do not restart the current finger-gun animation.
	# Queue one fire request instead.
	if _finger_gun_busy:
		_queued_finger_gun_fire = true
		return

	_play_finger_gun_fire_or_broken()

func _request_finger_gun_reload() -> void:
	if arms_anim == null:
		return

	# No need to reload if already full.
	if _finger_gun_ammo >= finger_gun_max_ammo:
		return

	# Do not interrupt the current fire/broken animation.
	# Queue reload to happen after it finishes.
	if _finger_gun_busy:
		_queued_finger_gun_reload = true
		_queued_finger_gun_fire = false
		return

	_play_finger_gun_reload()

func _play_finger_gun_fire_or_broken() -> void:
	if arms_anim == null:
		return

	_finger_gun_busy = true

	if _finger_gun_ammo > 0:
		_finger_gun_ammo -= 1

		# If this shot used the last ammo, the fingers should break after the fire animation.
		if _finger_gun_ammo <= 0:
			_finger_gun_broken_idle = true
			_queued_finger_gun_fire = false
		else:
			_finger_gun_broken_idle = false

		arms_anim.play(StringName(finger_gun_fire_anim), finger_gun_blend_time)
		_play_finger_gun_shot_sound()
		_spawn_bullet_impact()

		if debug_tech:
			print("Finger gun fired. Ammo: ", _finger_gun_ammo, "/", finger_gun_max_ammo)
	else:
		_finger_gun_broken_idle = true
		_queued_finger_gun_fire = false
		arms_anim.play(StringName(finger_gun_broken_anim), finger_gun_blend_time)

		if debug_tech:
			print("Finger gun empty.")

func _play_finger_gun_reload() -> void:
	if arms_anim == null:
		return

	_finger_gun_busy = true
	_finger_gun_reloading = true
	_finger_gun_broken_idle = false
	_queued_finger_gun_reload = false

	arms_anim.play(StringName(finger_gun_fix_anim), finger_gun_blend_time)
	_play_finger_gun_reload_sound()

	if debug_tech:
		print("Reloading finger gun.")

func _on_arms_animation_finished(anim_name: StringName) -> void:
	if arms_anim == null:
		return

	if anim_name == StringName(finger_gun_fix_anim):
		_finger_gun_ammo = finger_gun_max_ammo
		_finger_gun_reloading = false
		_finger_gun_busy = false

		if debug_tech:
			print("Finger gun reloaded. Ammo: ", _finger_gun_ammo, "/", finger_gun_max_ammo)

		if _queued_finger_gun_fire:
			_queued_finger_gun_fire = false
			_play_finger_gun_fire_or_broken()
			return

		arms_anim.play(StringName(idle_arm_anim), finger_gun_blend_time)
		return

	if anim_name == StringName(finger_gun_fire_anim) or anim_name == StringName(finger_gun_broken_anim):
		_finger_gun_busy = false

		if _queued_finger_gun_reload:
			_queued_finger_gun_reload = false
			_play_finger_gun_reload()
			return

		if _queued_finger_gun_fire:
			_queued_finger_gun_fire = false
			_play_finger_gun_fire_or_broken()
			return

		if _finger_gun_broken_idle:
			arms_anim.play(StringName(finger_gun_broken_anim), finger_gun_blend_time)
			return

		arms_anim.play(StringName(idle_arm_anim), finger_gun_blend_time)
		
func _play_finger_gun_shot_sound() -> void:
	if finger_gun_audio_player == null:
		return

	finger_gun_audio_player.play()
	
func _play_finger_gun_reload_sound() -> void:
	if finger_gun_reload_audio_player == null:
		return

	finger_gun_reload_audio_player.play()	
	
func _update_landing_shadow() -> void:
	if landing_shadow_ray == null or landing_shadow == null:
		return

	landing_shadow_ray.force_raycast_update()

	if not landing_shadow_ray.is_colliding():
		landing_shadow.visible = false
		return

	landing_shadow.visible = true

	var hit_pos: Vector3 = landing_shadow_ray.get_collision_point()
	var hit_normal: Vector3 = landing_shadow_ray.get_collision_normal()

	var distance_to_ground := global_position.distance_to(hit_pos)
	var distance_percent := clampf(distance_to_ground / shadow_max_distance, 0.0, 1.0)

	# Closer to ground = bigger/more visible.
	var shadow_scale := lerpf(shadow_max_scale, shadow_min_scale, distance_percent)

	landing_shadow.global_position = hit_pos + hit_normal * shadow_ground_offset
	landing_shadow.scale = Vector3(shadow_scale, shadow_scale, shadow_scale)
	# Align the shadow to the floor normal.
	# landing_shadow.look_at(landing_shadow.global_position + hit_normal, Vector3.FORWARD)

func _spawn_bullet_impact() -> void:
	if bullet_hole_scene == null:
		return

	if cam == null:
		return

	var ray_origin := cam.global_position
	var ray_end := ray_origin + (-cam.global_transform.basis.z * finger_gun_range)

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		return

	var hit_position: Vector3 = hit["position"]
	var hit_normal: Vector3 = hit["normal"]

	var bullet_hole := bullet_hole_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(bullet_hole)

	bullet_hole.global_position = hit_position + hit_normal * bullet_hole_surface_offset
	bullet_hole.global_basis = _basis_from_surface_normal(hit_normal)

	if bullet_hole_random_rotation:
		bullet_hole.rotate_object_local(Vector3.FORWARD, randf_range(0.0, TAU))

func _basis_from_surface_normal(normal: Vector3) -> Basis:
	var z := normal.normalized()
	var x := Vector3.UP.cross(z)

	if x.length() < 0.001:
		x = Vector3.RIGHT.cross(z)

	x = x.normalized()
	var y := z.cross(x).normalized()

	return Basis(x, y, z).orthonormalized()
	
func _update_slide_visuals(delta: float) -> void:
	if yaw_pivot == null:
		return

	var target_y := _standing_yaw_pivot_y

	if _is_sliding:
		target_y = _standing_yaw_pivot_y + slide_camera_y_offset

	yaw_pivot.position.y = lerpf(
		yaw_pivot.position.y,
		target_y,
		slide_camera_lerp_speed * delta
	)
	
func _update_camera_fov(delta: float) -> void:
	if cam == null:
		return

	var horizontal_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var speed_t := inverse_lerp(fov_speed_start, fov_speed_full, horizontal_speed)
	speed_t = clampf(speed_t, 0.0, 1.0)

	var target_fov := lerpf(base_fov, max_speed_fov, speed_t)

	if _wall_tech_fov_timer > 0.0:
		var wall_t := _wall_tech_fov_timer / wall_tech_fov_time
		target_fov += wall_tech_fov_bonus * wall_t

	cam.fov = lerpf(cam.fov, target_fov, fov_lerp_speed * delta)
		
func _update_debug_hud() -> void:
	if debug_label == null:
		return

	debug_label.visible = show_debug_hud

	if not show_debug_hud:
		return

	var horizontal_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var total_speed := velocity.length()

	var slide_time_left := 0.0
	if _is_sliding:
		slide_time_left = maxf(0.0, slide_duration - _slide_elapsed)

	debug_label.text = (
		"DEBUG\n"
		+ "--------------------\n"
		+ "Horizontal Speed: " + str(snappedf(horizontal_speed, 0.01)) + "\n"
		+ "Max Horizontal Speed: " + str(max_horizontal_speed) + "\n"
		+ "Total Speed: " + str(snappedf(total_speed, 0.01)) + "\n"
		+ "Velocity: " + str(Vector3(
			snappedf(velocity.x, 0.01),
			snappedf(velocity.y, 0.01),
			snappedf(velocity.z, 0.01)
		)) + "\n"
		+ "\n"
		+ "On Floor: " + str(is_on_floor()) + "\n"
		+ "Sliding: " + str(_is_sliding) + "\n"
		+ "Slide Speed: " + str(snappedf(_slide_speed, 0.01)) + "\n"
		+ "Slide Time Left: " + str(snappedf(slide_time_left, 0.01)) + "\n"
		+ "Slide Buffer: " + str(snappedf(_slide_buffer_timer, 0.01)) + "\n"
		+ "Slide Jump Lock: " + str(snappedf(_slide_jump_lock_timer, 0.01)) + "\n"
		+ "Wall Tech: " + str(_wall_tech_timer > 0.0) + "\n"
		+ "Wall Window: %.2f" % _wall_tech_timer + "\n"
		+ "Wall Freeze: " + str(_wall_tech_pending) + "\n"
		+ "Wall Freeze Timer: %.2f" % _wall_tech_freeze_timer + "\n"
		+ "\n"
		+ "Tech Window: " + str(snappedf(_tech_window_timer, 0.01)) + "\n"
		+ "Tech Buffer: " + str(snappedf(_tech_buffer_timer, 0.01)) + "\n"
		+ "Preserve Timer: " + str(snappedf(_preserve_timer, 0.01)) + "\n"
		+ "Last Impact Speed: " + str(snappedf(_last_impact_speed, 0.01)) + "\n"
		+ "\n"
		+ "Finger Gun Ammo: " + str(_finger_gun_ammo) + " / " + str(finger_gun_max_ammo) + "\n"
		+ "Finger Gun Busy: " + str(_finger_gun_busy) + "\n"
		+ "Finger Gun Broken: " + str(_finger_gun_broken_idle)
	)
