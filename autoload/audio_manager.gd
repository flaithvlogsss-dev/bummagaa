extends Node
## AudioManager — buses, pooled SFX players and looping ambient layers.
##
## Purpose: every sound goes through here. Categories are audio buses
##   (Music, Ambient, SFX, Dialogue, Radio, Body) with volumes from Settings. "Body" carries the
##   player's own breathing and coughing: it follows the SFX volume but is never muffled.
##   Sounds are procedural placeholders unless res://assets/audio/<id>.ogg/.wav exists.
## Dependencies: Settings, ProceduralAudio.
## Public API: play_sfx(id, pos, volume_db, pitch), play_ui(id), set_layer(layer, stream_id,
##   volume, bus), stop_layer(layer), set_muffled(bool), set_visor(bool), get_stream(id)
## Signals: none. Save Data: none (volumes live in Settings).

const BUSES: Array[String] = ["Music", "Ambient", "SFX", "Dialogue", "Radio", "Body"]
## Buses heard "through the visor" when the gas mask is on.
const VISOR_BUSES: Array[String] = ["Ambient", "SFX"]
const SFX_POOL := 10
const SFX3D_POOL := 8
const ASSET_DIR := "res://assets/audio"

var _streams: Dictionary = {}
var _sfx: Array[AudioStreamPlayer] = []
var _sfx3d: Array[AudioStreamPlayer3D] = []
var _next_sfx: int = 0
var _next_sfx3d: int = 0
## layer name -> {"player": AudioStreamPlayer, "target": float, "stream": String}
var _layers: Dictionary = {}
var _lowpass_index: int = -1
## bus name -> effect index of the visor low-pass
var _visor_fx: Dictionary = {}
## Headless runs (tests, CI) have no mixer thread: streams are still synthesised, never played.
var _silent: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	_setup_buses()
	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx.append(p)
	for i in SFX3D_POOL:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.unit_size = 6.0
		p3.max_distance = 45.0
		add_child(p3)
		_sfx3d.append(p3)
	Settings.settings_changed.connect(_apply_volumes)
	_apply_volumes()
	Consequences.register("sound", func(v, _c): play_sfx(str(v)))


func _setup_buses() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	var amb := AudioServer.get_bus_index("Ambient")
	var lowpass := AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = 900.0
	AudioServer.add_bus_effect(amb, lowpass)
	_lowpass_index = AudioServer.get_bus_effect_count(amb) - 1
	AudioServer.set_bus_effect_enabled(amb, _lowpass_index, false)
	for bus_name in VISOR_BUSES:
		var idx := AudioServer.get_bus_index(bus_name)
		var visor := AudioEffectLowPassFilter.new()
		visor.cutoff_hz = 2300.0
		visor.resonance = 0.8
		AudioServer.add_bus_effect(idx, visor)
		_visor_fx[bus_name] = AudioServer.get_bus_effect_count(idx) - 1
		AudioServer.set_bus_effect_enabled(idx, _visor_fx[bus_name], false)


func _apply_volumes() -> void:
	for bus_name in Settings.volumes.keys():
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			var lin: float = Settings.volumes[bus_name]
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(lin, 0.0001)))
			AudioServer.set_bus_mute(idx, lin <= 0.001)
	var body := AudioServer.get_bus_index("Body")
	if body >= 0:
		var sfx: float = Settings.volumes.get("SFX", 0.8)
		AudioServer.set_bus_volume_db(body, linear_to_db(maxf(sfx, 0.0001)))
		AudioServer.set_bus_mute(body, sfx <= 0.001)


## Indoors the wind is heard through walls.
func set_muffled(value: bool) -> void:
	var amb := AudioServer.get_bus_index("Ambient")
	if amb >= 0 and _lowpass_index >= 0:
		AudioServer.set_bus_effect_enabled(amb, _lowpass_index, value)


## Through a gas mask the world sounds dull and far away.
func set_visor(value: bool) -> void:
	for bus_name in _visor_fx.keys():
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			AudioServer.set_bus_effect_enabled(idx, _visor_fx[bus_name], value)


func is_silent() -> bool:
	return _silent


func get_stream(id: String) -> AudioStream:
	if id.is_empty():
		return null
	if _streams.has(id):
		return _streams[id]
	var stream: AudioStream = null
	for ext in ["ogg", "wav"]:
		var path := ASSET_DIR.path_join("%s.%s" % [id, ext])
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream == null:
		stream = ProceduralAudio.make(id)
	if stream == null:
		push_warning("AudioManager: unknown sound '%s'" % id)
	_streams[id] = stream
	return stream


## position = null plays a 2D sound, a Vector3 plays positionally.
func play_sfx(id: String, position: Variant = null, volume_db: float = 0.0, pitch: float = 1.0, bus: String = "SFX") -> void:
	var stream := get_stream(id)
	if stream == null or _silent:
		return
	if position is Vector3:
		var p3 := _sfx3d[_next_sfx3d]
		_next_sfx3d = (_next_sfx3d + 1) % _sfx3d.size()
		p3.stream = stream
		p3.global_position = position
		p3.volume_db = volume_db
		p3.pitch_scale = pitch
		p3.bus = bus
		p3.play()
		return
	var p := _sfx[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	p.play()


func play_ui(id: String) -> void:
	play_sfx(id, null, -4.0)


## Looping layer faded towards `volume` (linear 0..1).
func set_layer(layer: String, stream_id: String, volume: float, bus: String = "Ambient", pitch: float = 1.0) -> void:
	var entry: Dictionary = _layers.get(layer, {})
	if entry.is_empty():
		var p := AudioStreamPlayer.new()
		p.bus = bus
		p.volume_db = -60.0
		add_child(p)
		entry = {"player": p, "target": 0.0, "stream": ""}
		_layers[layer] = entry
	var player: AudioStreamPlayer = entry.player
	if _silent:
		get_stream(stream_id)
		entry.target = clampf(volume, 0.0, 1.5)
		return
	if entry.stream != stream_id:
		entry.stream = stream_id
		player.stream = get_stream(stream_id)
		player.play()
	player.bus = bus
	player.pitch_scale = pitch
	entry.target = clampf(volume, 0.0, 1.5)
	if not player.playing and player.stream:
		player.play()


func stop_layer(layer: String) -> void:
	if _layers.has(layer):
		_layers[layer].target = 0.0


func stop_all_layers() -> void:
	for layer in _layers.keys():
		_layers[layer].target = 0.0


func get_layer_player(layer: String) -> AudioStreamPlayer:
	return _layers.get(layer, {}).get("player", null)


func _process(delta: float) -> void:
	for layer in _layers.keys():
		var entry: Dictionary = _layers[layer]
		var player: AudioStreamPlayer = entry.player
		var current := db_to_linear(player.volume_db)
		var target: float = entry.target
		var next := move_toward(current, target, delta * 0.8)
		player.volume_db = linear_to_db(maxf(next, 0.0001))
		if next <= 0.001 and target <= 0.0 and player.playing:
			player.stop()
			entry.stream = ""


## Stops everything (call a couple of frames before quitting so the mixer releases playbacks).
func shutdown() -> void:
	_exit_tree()


func _exit_tree() -> void:
	# Stop playbacks so no stream outlives the audio server at shutdown.
	for p in _sfx:
		p.stop()
		p.stream = null
	for p3 in _sfx3d:
		p3.stop()
		p3.stream = null
	for layer in _layers.keys():
		var player: AudioStreamPlayer = _layers[layer].player
		player.stop()
		player.stream = null
	_streams.clear()
