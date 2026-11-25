class_name VisualAnimator
extends Node

## Visual-only animation channels for a [Base].
##
## Game logic moves elements instantly; this node makes the visuals catch up by
## displacing [member Base.polygon] (and the paired [PointLight2D]) without
## touching the element's position, collision or board index. Each channel is
## independent so tweens never fight: [member slide_offset] for tile-to-tile
## movement, [member idle_offset], [member flying_offset] and
## [member phasing_offset] for hovering, [member lunge_offset] for attack
## lunges, [member knock_offset] for hit recoil, and [member tilt] for the
## attack lean.
##
## Created lazily by [method Base.get_visual], never in the editor.

enum Hover {
	IDLE,
	FLYING,
	PHASING,
}

## Pixels per second for a normal tile slide, derived from the tile length.
const MOVE_SPEED: float = Helper.LENGTH / 0.09
const MIN_DURATION: float = 0.04
const MAX_DURATION: float = 0.12
## Moves longer than this snap instead of sliding (e.g. teleport pads).
const SNAP_DISTANCE: float = Helper.LENGTH * 1.5

## Attack lunge and lean.
const LUNGE_DISTANCE: float = 10.0
const TILT_ANGLE: float = 0.2
const ATTACK_OUT_TIME: float = 0.05
const ATTACK_RETURN_TIME: float = 0.09

## Hit recoil and flash.
const KNOCK_DISTANCE: float = 5.0
const KNOCK_OUT_TIME: float = 0.04
const KNOCK_RETURN_TIME: float = 0.1
## Optional uniform a hit material can expose to fade itself out.
const HIT_AMOUNT_PARAMETER: StringName = &"hit_amount"

## Idle breathing.
const IDLE_RISE: float = 1.5
const IDLE_DURATION: float = 0.9
const IDLE_PERIOD: float = IDLE_DURATION * 2.0
const IDLE_FLYING_RISE: float = 4.0
const HOVER_DURATION: float = 0.15
const PHASING_SWAY: float = 1.0

## Global switch. Turning it off restores instant visuals.
static var enabled: bool = true

var base: Base = null

var slide_offset: Vector2 = Vector2.ZERO:
	set(v):
		slide_offset = v
		_apply()
var lunge_offset: Vector2 = Vector2.ZERO:
	set(v):
		lunge_offset = v
		_apply()
var knock_offset: Vector2 = Vector2.ZERO:
	set(v):
		knock_offset = v
		_apply()
var idle_offset: Vector2 = Vector2.ZERO:
	set(v):
		idle_offset = v
		_apply()
var flying_offset: Vector2 = Vector2.ZERO:
	set(v):
		flying_offset = v
		_apply()
var phasing_offset: Vector2 = Vector2.ZERO:
	set(v):
		phasing_offset = v
		_apply()
var tilt: float = 0.0:
	set(v):
		tilt = v
		_apply()

var _slide_tween: Tween = null
var _attack_tween: Tween = null
var _knock_tween: Tween = null
## One looping tween and enabled flag per [enum Hover] channel, indexed by its
## enum value.
var _hover_tweens: Array[Tween] = [null, null, null]
var _hover_enabled: Array[bool] = [false, false, false]
var _hit_tween: Tween = null
## Shared source, its duplicated per-entity copy and the polygon material that
## was replaced by the flash.
var _hit_source: ShaderMaterial = null
var _hit_material: ShaderMaterial = null
var _saved_material: Material = null
var _hit_active: bool = false


func _ready() -> void:
	if is_instance_valid(base):
		base.visibility_changed.connect(_on_visibility_changed)


## Starts a slide that makes the visual catch up from [param old_world_position]
## to the element's current (already updated) logical position. A second move
## before the first one ends simply continues from the visual's current offset.
func slide_from(old_world_position: Vector2) -> void:
	if not enabled or not _can_play():
		return
	_kill_slide_tween()
	slide_offset += old_world_position - base.position
	var distance: float = slide_offset.length()
	if distance > SNAP_DISTANCE:
		slide_offset = Vector2.ZERO
		return
	var duration: float = clampf(distance / MOVE_SPEED, MIN_DURATION, MAX_DURATION)
	_slide_tween = create_tween()
	(_slide_tween.tween_property(self, "slide_offset", Vector2.ZERO, duration)
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))


## Lunges towards [param direction] and leans into it, then returns to rest.
## Returns immediately; the logic turn is not delayed.
func play_attack(direction: Vector2) -> void:
	if not enabled or not _can_play():
		return
	_kill_attack_tween()
	var lunge: Vector2 = direction.normalized() * LUNGE_DISTANCE
	var lean: float = TILT_ANGLE * (signf(direction.x) if not is_zero_approx(direction.x) else 1.0)
	_attack_tween = create_tween()
	(_attack_tween.tween_property(self, "lunge_offset", lunge, ATTACK_OUT_TIME)
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	(_attack_tween.parallel().tween_property(self, "tilt", lean, ATTACK_OUT_TIME)
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	_attack_tween.tween_property(self, "lunge_offset", Vector2.ZERO, ATTACK_RETURN_TIME)
	_attack_tween.parallel().tween_property(self, "tilt", 0.0, ATTACK_RETURN_TIME)


## Recoils away from [param direction] (the damage source). A zero direction
## only flashes, which is what happens when the source is already gone.
func play_hit(direction: Vector2) -> void:
	if not enabled or not _can_play():
		return
	_kill_knock_tween()
	var knock: Vector2 = direction.normalized() * KNOCK_DISTANCE
	_knock_tween = create_tween()
	(_knock_tween.tween_property(self, "knock_offset", knock, KNOCK_OUT_TIME)
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	_knock_tween.tween_property(self, "knock_offset", Vector2.ZERO, KNOCK_RETURN_TIME)


## Applies [param material] to the polygon for [param duration], then restores
## whatever material was there before. The shared resource is duplicated once
## per entity so parameter tweens never bleed between entities. A second hit
## restarts the timer without overwriting the saved original.
func apply_material(material: ShaderMaterial, duration: float) -> void:
	if not enabled or not material or not _can_play():
		return
	if _hit_material == null or _hit_source != material:
		_hit_source = material
		_hit_material = material.duplicate() as ShaderMaterial
	if not _hit_active:
		_saved_material = base.polygon.material
		_hit_active = true
	base.polygon.material = _hit_material
	if _hit_tween:
		_hit_tween.kill()
		_hit_tween = null
	_hit_tween = create_tween()
	if _has_hit_amount(_hit_material):
		_hit_material.set_shader_parameter(HIT_AMOUNT_PARAMETER, 1.0)
		_hit_tween.tween_method(_set_hit_amount, 1.0, 0.0, duration)
	else:
		_hit_tween.tween_interval(duration)
	_hit_tween.tween_callback(_restore_material)


func _set_hit_amount(value: float) -> void:
	if _hit_material:
		_hit_material.set_shader_parameter(HIT_AMOUNT_PARAMETER, value)


func _has_hit_amount(material: ShaderMaterial) -> bool:
	if not material or not material.shader:
		return false
	for uniform: Dictionary in material.shader.get_shader_uniform_list():
		if String(uniform.get("name", "")) == String(HIT_AMOUNT_PARAMETER):
			return true
	return false


func _restore_material() -> void:
	_hit_tween = null
	if is_instance_valid(base) and is_instance_valid(base.polygon):
		base.polygon.material = _saved_material
	_saved_material = null
	_hit_active = false


## Enables or disables one looping hover channel. Each channel owns its own
## offset and tween, so idle, flying and phasing can run simultaneously.
func set_hover_channel(channel: Hover, _enabled: bool) -> void:
	var _index: int = int(channel)
	if _hover_enabled[_index] == _enabled:
		return
	_hover_enabled[_index] = _enabled
	_kill_hover_tween(_index)
	if not _enabled:
		_set_hover_offset(_index, Vector2.ZERO)
		return
	if not enabled or not is_instance_valid(base) or not is_instance_valid(base.polygon):
		_set_hover_offset(_index, Vector2.ZERO)
		return
	_start_hover(_index)


func _start_hover(channel: int) -> void:
	_kill_hover_tween(channel)
	var _tween: Tween = null
	match channel:
		Hover.IDLE:
			# Every entity starts breathing after a random delay, so a group
			# does not rise and fall in unison.
			_tween = create_tween()
			_tween.tween_interval(randf() * IDLE_PERIOD)
			_tween.tween_callback(_start_idle_loop)
		Hover.FLYING:
			_tween = create_tween()
			(_tween.tween_property(self, "flying_offset",
					Vector2(0, -IDLE_FLYING_RISE), HOVER_DURATION)
					.set_ease(Tween.EASE_IN))
			_tween.tween_property(self, "flying_offset",
					Vector2(0, IDLE_FLYING_RISE), HOVER_DURATION)
			_tween.set_loops()
		Hover.PHASING:
			_tween = create_tween()
			(_tween.tween_property(self, "phasing_offset",
					Vector2(-PHASING_SWAY, 0), HOVER_DURATION)
					.set_ease(Tween.EASE_IN))
			_tween.tween_property(self, "phasing_offset",
					Vector2(PHASING_SWAY, 0), HOVER_DURATION)
			_tween.set_loops()
	_hover_tweens[channel] = _tween
	if _tween and not base.is_visible_in_tree():
		_tween.pause()


func _start_idle_loop() -> void:
	if not _hover_enabled[Hover.IDLE] or not enabled:
		return
	var _tween: Tween = create_tween()
	(_tween.tween_property(self, "idle_offset", Vector2(0, -IDLE_RISE), IDLE_DURATION)
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))
	(_tween.tween_property(self, "idle_offset", Vector2.ZERO, IDLE_DURATION)
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))
	_tween.set_loops()
	_hover_tweens[Hover.IDLE] = _tween
	if not base.is_visible_in_tree():
		_tween.pause()


## Pauses every active hover tween while hidden so fogged-out entities are
## cheap, and resumes them exactly where they left off when visible again.
func _on_visibility_changed() -> void:
	if not is_instance_valid(base):
		return
	var _is_visible: bool = base.is_visible_in_tree()
	for channel: int in _hover_tweens.size():
		if not _hover_enabled[channel]:
			continue
		var _tween: Tween = _hover_tweens[channel]
		if not _is_visible:
			if _tween:
				_tween.pause()
		elif not enabled:
			continue
		elif _tween:
			_tween.play()
		else:
			_start_hover(channel)


func _can_play() -> bool:
	return (is_instance_valid(base)
			and is_instance_valid(base.polygon)
			and base.is_visible_in_tree())


func _apply() -> void:
	if not is_instance_valid(base) or not is_instance_valid(base.polygon):
		return
	base.polygon.position = (slide_offset + lunge_offset + knock_offset
			+ idle_offset + flying_offset + phasing_offset)
	base.polygon.rotation = tilt
	# The light is not parented to the polygon, so it needs the slide itself.
	# Hover and attack offsets intentionally do not move it.
	if is_instance_valid(base.light):
		base.light.position = base.light_base_position + slide_offset


func _kill_slide_tween() -> void:
	if _slide_tween:
		_slide_tween.kill()
		_slide_tween = null


func _kill_attack_tween() -> void:
	if _attack_tween:
		_attack_tween.kill()
		_attack_tween = null


func _kill_knock_tween() -> void:
	if _knock_tween:
		_knock_tween.kill()
		_knock_tween = null


func _kill_hover_tween(channel: int) -> void:
	var _tween: Tween = _hover_tweens[channel]
	if _tween:
		_tween.kill()
	_hover_tweens[channel] = null


func _set_hover_offset(channel: int, value: Vector2) -> void:
	match channel:
		Hover.IDLE:
			idle_offset = value
		Hover.FLYING:
			flying_offset = value
		Hover.PHASING:
			phasing_offset = value
