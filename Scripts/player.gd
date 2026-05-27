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
## Upward velocity applied when the player jumps.
@export var jump_velocity := 7.5
## Maximum downward falling speed.
@export var max_fall_speed := 45.0
## Multiplier applied to upward velocity when jump is released early. Set to 1.0 to disable tap-short-jump.
@export var cut_jump_factor := 0.55 # set to 1.0 to disable tap-short-jump

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
@export var tech_preserve_time := 0.22      # prevents burst being instantly smoothed away
## Ground acceleration multiplier during the tech preserve window.
@export var preserve_accel_scale := 0.20
## Ground friction multiplier during the tech preserve window.
@export var preserve_friction_scale := 0.25
# NEW: Always add a vertical "bounce" on tech, more if looking up
## Base upward velocity added by every successful tech.
@export var tech_bounce_base := 2.2         # vertical velocity added on every tech (always)
## Extra upward velocity added when the player is looking upward during a tech.
@export var tech_bounce_up_bonus := 3.6     # extra vertical velocity when looking fully up
## How much better tech timing increases the vertical bounce. Set to 0.0 to disable timing-based bounce scaling.
@export var tech_bounce_quality_scale := 0.25 # extra bounce scaling with timing quality (0 = no scaling)

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

@export_category("Feedback")
## Distance from the ground where the landing approach feedback starts appearing.
@export var approach_show_distance := 2.2   # meters: start showing landing indicator
## Distance from the ground where the landing approach feedback is considered fully active.
@export var approach_full_distance := 0.35  # meters: considered "very close" (meter ~1.0)

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
			else Input.MOUSE_MODE_CAPTURED
		)

func _physics_process(delta: float) -> void:
	# Timers
	_tech_window_timer = maxf(0.0, _tech_window_timer - delta)
	_tech_press_cd = maxf(0.0, _tech_press_cd - delta)
	_preserve_timer = maxf(0.0, _preserve_timer - delta)

	_tech_buffer_timer = maxf(0.0, _tech_buffer_timer - delta)
	_tech_buffer_cd = maxf(0.0, _tech_buffer_cd - delta)

	_update_landing_approach_feedback()
	
	_update_landing_shadow()
	
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
