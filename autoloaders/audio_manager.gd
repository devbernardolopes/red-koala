extends Node
## Audio manager. Non-positional sounds use [method play]; [method play_at] plays
## a one-shot at a world position so Godot handles 2D distance attenuation and
## left/right panning relative to the listener.

const MAX_POOL_SIZE: int = 32
## [method play_at] skips sounds farther than this from the listener, in pixels.
const RANGE_PX: float = 1024.0

var _pool: Array[AudioStreamPlayer2D] = []
var _pool_reg: Array[AudioStreamPlayer] = []
var _listener_target: Node2D = null


func _ready() -> void:
	# Pre-create pool of 2D audio players; no owner so they don't save into scenes.
	for _i: int in range(MAX_POOL_SIZE):
		var p := AudioStreamPlayer2D.new()
		p.bus = &"SFX"
		p.name = "AudioPool_%d" % _i
		add_child(p)
		_pool.append(p)
	for _i: int in range(MAX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		p.name = "AudioPoolReg_%d" % _i
		add_child(p)
		_pool_reg.append(p)


func set_listener_target(node: Node2D) -> void:
	_listener_target = node


func play(stream: AudioStream) -> AudioStreamPlayer:
	if stream == null:
		return null
	var p := _find_available_reg()
	if p == null:
		return null
	p.stream = stream
	p.play()
	return p


func play_at(world_px: Vector2, stream: AudioStream) -> AudioStreamPlayer2D:
	if stream == null:
		return null
	if _listener_target == null:
		var listener_nodes := get_tree().get_nodes_in_group("audio_listener")
		if not listener_nodes.is_empty():
			_listener_target = listener_nodes[0] as Node2D
	if not is_instance_valid(_listener_target):
		return null
	if world_px.distance_to(_listener_target.global_position) > RANGE_PX:
		return null
	var p := _find_available()
	if p == null:
		return null
	p.global_position = world_px
	p.stream = stream
	p.play()
	return p


func update_listener() -> void:
	# Listener is handled by an AudioListener2D node near the player; this manager
	# only updates pool positions when sources move.
	pass


func _find_available() -> AudioStreamPlayer2D:
	for p: AudioStreamPlayer2D in _pool:
		if not p.playing:
			return p
	# Fallback: steal a playing one-shot; looping streams are left alone.
	for p: AudioStreamPlayer2D in _pool:
		if p.playing and not _stream_loops(p.stream):
			p.stop()
			return p
	return null


func _find_available_reg() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _pool_reg:
		if not p.playing:
			return p
	for p: AudioStreamPlayer in _pool_reg:
		if p.playing and not _stream_loops(p.stream):
			p.stop()
			return p
	return null


## Looping is a property of the stream, not of the player.
static func _stream_loops(stream: AudioStream) -> bool:
	if stream == null:
		return false
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	if stream is AudioStreamOggVorbis:
		return (stream as AudioStreamOggVorbis).loop
	if stream is AudioStreamMP3:
		return (stream as AudioStreamMP3).loop
	return false
