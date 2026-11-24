class_name VisualAnimator
extends Node

## Visual-only animation channels for a [Base].
##
## Game logic moves elements instantly; this node makes the visuals catch up by
## displacing [member Base.polygon] (and the paired [PointLight2D]) without
## touching the element's position, collision or board index. Each channel is
## independent so tweens never fight: [member slide_offset] for tile-to-tile
## movement, [member hover_offset] for flying/phasing and the lunge, knock and
## tilt channels for later phases.
##
## Created lazily by [method Base.get_visual], never in the editor.

enum Hover {
	NONE,
	FLYING,
	PHASING,
}

## Pixels per second for a normal tile slide, derived from the tile length.
const MOVE_SPEED: float = Helper.LENGTH / 0.09
const MIN_DURATION: float = 0.04
const MAX_DURATION: float = 0.12
## Moves longer than this snap instead of sliding (e.g. teleport pads).
const SNAP_DISTANCE: float = Helper.LENGTH * 1.5

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
var hover_offset: Vector2 = Vector2.ZERO:
	set(v):
		hover_offset = v
		_apply()
var tilt: float = 0.0:
	set(v):
		tilt = v
		_apply()

var _slide_tween: Tween = null
var _hover_tween: Tween = null


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


## Switches the looping idle wobble. Phasing takes priority over flying, as the
## caller decides; [constant Hover.NONE] resets the channel.
func set_hover(mode: Hover) -> void:
	_kill_hover_tween()
	if mode == Hover.NONE:
		hover_offset = Vector2.ZERO
		return
	if not enabled or not _can_play():
		hover_offset = Vector2.ZERO
		return
	_hover_tween = create_tween()
	match mode:
		Hover.FLYING:
			(_hover_tween.tween_property(self, "hover_offset", Vector2(0, -4.0), 0.15)
					.set_ease(Tween.EASE_IN))
			_hover_tween.tween_property(self, "hover_offset", Vector2(0, 4.0), 0.15)
		Hover.PHASING:
			(_hover_tween.tween_property(self, "hover_offset", Vector2(-1, 0), 0.15)
					.set_ease(Tween.EASE_IN))
			_hover_tween.tween_property(self, "hover_offset", Vector2(1, 0), 0.15)
	_hover_tween.set_loops()


func _can_play() -> bool:
	return (is_instance_valid(base)
			and is_instance_valid(base.polygon)
			and base.is_visible_in_tree())


func _apply() -> void:
	if not is_instance_valid(base) or not is_instance_valid(base.polygon):
		return
	base.polygon.position = slide_offset + lunge_offset + knock_offset + hover_offset
	base.polygon.rotation = tilt
	# The light is not parented to the polygon, so it needs the slide itself.
	# Idle and attack offsets intentionally do not move it.
	if is_instance_valid(base.light):
		base.light.position = base.light_base_position + slide_offset


func _kill_slide_tween() -> void:
	if _slide_tween:
		_slide_tween.kill()
		_slide_tween = null


func _kill_hover_tween() -> void:
	if _hover_tween:
		_hover_tween.kill()
		_hover_tween = null
