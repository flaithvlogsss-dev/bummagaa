class_name ProceduralAudio
extends RefCounted
## ProceduralAudio — synthesises every placeholder sound at runtime (no audio files needed).
##
## Purpose: wind, blizzard howl, generator hum, fire, radio static/voice, music drone and all
##   short SFX. Replace any of them by dropping a real file into res://assets/audio/<id>.ogg
##   (or .wav) — AudioManager prefers real files when they exist.
## Public API: make(id) -> AudioStreamWAV (null for unknown ids)

const RATE := 22050
const LOW_RATE := 11025


static func make(id: String) -> AudioStreamWAV:
	match id:
		"wind": return _loop(_wind(6.0, 0.0), LOW_RATE)
		"wind_howl": return _loop(_wind(6.0, 1.0), LOW_RATE)
		"hum": return _loop(_hum(2.0), RATE)
		"room": return _loop(_room(4.0), LOW_RATE)
		"fire_loop": return _loop(_fire(3.0), RATE)
		"static": return _loop(_static(2.0), RATE)
		"radio_voice": return _loop(_voice(4.0), RATE)
		"music_drone": return _loop(_drone(16.0), LOW_RATE)
		"phone_ring": return _loop(_phone(4.0), RATE)
		"heartbeat": return _loop(_heartbeat(1.2), RATE)
		"click": return _one(_blip(0.04, 900.0, 0.4), RATE)
		"deny": return _one(_blip(0.16, 180.0, 0.5), RATE)
		"ui_open": return _one(_sweep(0.08, 500.0, 900.0, 0.25), RATE)
		"ui_close": return _one(_sweep(0.08, 900.0, 500.0, 0.25), RATE)
		"pickup": return _one(_chime([660.0, 990.0], 0.09, 0.35), RATE)
		"quest": return _one(_chime([523.0, 659.0, 784.0], 0.16, 0.35), RATE)
		"tune_lock": return _one(_chime([880.0, 1320.0], 0.07, 0.3), RATE)
		"door": return _one(_thud(0.35, 70.0, 0.7), RATE)
		"knock": return _one(_knocks(), RATE)
		"clunk": return _one(_thud(0.2, 110.0, 0.6), RATE)
		"search": return _one(_noise_burst(0.35, 0.3, 0.25), RATE)
		"rustle": return _one(_noise_burst(0.3, 0.4, 0.2), RATE)
		"paper": return _one(_noise_burst(0.22, 0.8, 0.2), RATE)
		"footstep_snow": return _one(_noise_burst(0.12, 0.15, 0.35), RATE)
		"footstep_hard": return _one(_thud(0.08, 160.0, 0.3), RATE)
		"gunshot": return _one(_gunshot(), RATE)
		"empty_click": return _one(_blip(0.03, 2400.0, 0.4), RATE)
		"reload": return _one(_reload(), RATE)
		"hurt": return _one(_thud(0.25, 90.0, 0.9), RATE)
		"breath": return _one(_noise_burst(0.6, 0.5, 0.12, true), RATE)
		"power_down": return _one(_sweep(1.4, 220.0, 30.0, 0.5), RATE)
		"engine_start": return _one(_engine(), RATE)
		"fire": return _one(_noise_burst(0.5, 0.2, 0.4), RATE)
		"craft": return _one(_hammer(), RATE)
		"stalker_step": return _one(_thud(0.18, 55.0, 0.8), RATE)
		"stalker_scream": return _one(_scream(), RATE)
		"creak": return _one(_creak(), RATE)
		"metal_distant": return _one(_metal(), RATE)
		"eat": return _one(_noise_burst(0.3, 0.6, 0.2), RATE)
	return null


# --- Stream helpers ---------------------------------------------------------------------

static func _to_stream(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = bytes
	return s


static func _loop(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var s := _to_stream(samples, rate)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = samples.size()
	return s


static func _one(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	return _to_stream(samples, rate)


static func _buf(seconds: float, rate: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * rate))
	return b


## Crossfades the tail into the head so noise loops are seamless.
static func _seamless(b: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := b.size()
	fade = mini(fade, n / 4)
	for i in fade:
		var t := float(i) / fade
		b[i] = b[i] * t + b[n - fade + i] * (1.0 - t)
	b.resize(n - fade)
	return b


# --- Loops ---------------------------------------------------------------------------------

static func _wind(seconds: float, howl: float) -> PackedFloat32Array:
	var rate := LOW_RATE
	var b := _buf(seconds + 0.5, rate)
	var brown := 0.0
	var lp := 0.0
	var bp_low := 0.0
	var n := b.size()
	for i in n:
		var t := float(i) / rate
		brown = clampf(brown + randf_range(-0.04, 0.04), -1.0, 1.0) * 0.998
		var gust := 0.55 + 0.3 * sin(TAU * t / seconds * 2.0) + 0.15 * sin(TAU * t / seconds * 5.0 + 1.3)
		var v := brown * gust
		if howl > 0.0:
			var cutoff := 0.05 + 0.04 * sin(TAU * t / seconds * 3.0)
			var white := randf_range(-1.0, 1.0)
			lp += (white - lp) * cutoff
			bp_low += (lp - bp_low) * 0.02
			v = v * 0.7 + (lp - bp_low) * 2.2 * (0.6 + 0.4 * sin(TAU * t / seconds * 4.0))
		b[i] = v * 0.8
	return _seamless(b, int(0.5 * rate))


static func _hum(seconds: float) -> PackedFloat32Array:
	var b := _buf(seconds, RATE)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = 0.3 * sin(TAU * 50.0 * t) + 0.18 * sin(TAU * 100.0 * t) + 0.08 * sin(TAU * 150.0 * t) + randf_range(-0.02, 0.02)
	return b


static func _room(seconds: float) -> PackedFloat32Array:
	var b := _buf(seconds + 0.5, LOW_RATE)
	var brown := 0.0
	for i in b.size():
		brown = clampf(brown + randf_range(-0.02, 0.02), -1.0, 1.0) * 0.999
		b[i] = brown * 0.35
	return _seamless(b, int(0.5 * LOW_RATE))


static func _fire(seconds: float) -> PackedFloat32Array:
	var b := _buf(seconds + 0.3, RATE)
	var lp := 0.0
	for i in b.size():
		lp += (randf_range(-1.0, 1.0) - lp) * 0.05
		var crack := 0.0
		if randf() < 0.0012:
			crack = randf_range(-0.9, 0.9)
		b[i] = lp * 0.35 + crack
	return _seamless(b, int(0.3 * RATE))


static func _static(seconds: float) -> PackedFloat32Array:
	var b := _buf(seconds + 0.2, RATE)
	var hp := 0.0
	for i in b.size():
		var w := randf_range(-1.0, 1.0)
		hp += (w - hp) * 0.6
		b[i] = (w - hp * 0.5) * 0.4
	return _seamless(b, int(0.2 * RATE))


## Voice-like buzz: a pitched saw shaped into syllables.
static func _voice(seconds: float) -> PackedFloat32Array:
	var b := _buf(seconds, RATE)
	var phase := 0.0
	var lp := 0.0
	var syllables: Array[float] = []
	for k in int(seconds * 5.0):
		syllables.append(0.0 if randf() < 0.25 else randf_range(0.5, 1.0))
	for i in b.size():
		var t := float(i) / RATE
		var pitch := 135.0 + 18.0 * sin(TAU * t * 0.7) + 8.0 * sin(TAU * t * 3.1)
		phase = fmod(phase + pitch / RATE, 1.0)
		var saw := phase * 2.0 - 1.0
		lp += (saw - lp) * 0.18
		var syl_pos := t * 5.0
		var idx := int(syl_pos) % syllables.size()
		var env := syllables[idx] * sin(PI * fmod(syl_pos, 1.0))
		b[i] = lp * env * 0.7
	return b


static func _drone(seconds: float) -> PackedFloat32Array:
	var b := _buf(seconds, LOW_RATE)
	var freqs := [55.0, 82.41, 110.0, 110.6, 164.8]
	for i in b.size():
		var t := float(i) / LOW_RATE
		var v := 0.0
		for k in freqs.size():
			var swell := 0.5 + 0.5 * sin(TAU * t / seconds * (k % 2 + 1) + k)
			v += sin(TAU * freqs[k] * t) * swell
		b[i] = v * 0.08
	return b


static func _phone(seconds: float) -> PackedFloat32Array:
	var b := _buf(seconds, RATE)
	for i in b.size():
		var t := float(i) / RATE
		var on := fmod(t, 4.0) < 2.0 and fmod(t, 0.1) < 0.05
		b[i] = (sin(TAU * 440.0 * t) + sin(TAU * 480.0 * t)) * 0.2 if on else 0.0
	return b


static func _heartbeat(seconds: float) -> PackedFloat32Array:
	var b := _buf(seconds, RATE)
	for i in b.size():
		var t := float(i) / RATE
		var v := 0.0
		for beat in [0.0, 0.25]:
			var dt: float = t - float(beat)
			if dt >= 0.0 and dt < 0.15:
				v += sin(TAU * 50.0 * dt) * exp(-dt * 30.0)
		b[i] = v * 0.9
	return b


# --- One-shots -----------------------------------------------------------------------------

static func _blip(seconds: float, freq: float, amp: float) -> PackedFloat32Array:
	var b := _buf(seconds, RATE)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * freq * t) * amp * (1.0 - t / seconds)
	return b


static func _sweep(seconds: float, f0: float, f1: float, amp: float) -> PackedFloat32Array:
	var b := _buf(seconds, RATE)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE / seconds
		phase += lerpf(f0, f1, t) / RATE
		b[i] = sin(TAU * phase) * amp * (1.0 - t) * minf(1.0, t * 20.0)
	return b


static func _chime(notes: Array, note_len: float, amp: float) -> PackedFloat32Array:
	var b := _buf(note_len * notes.size() + 0.3, RATE)
	for k in notes.size():
		var start := int(k * note_len * RATE)
		for i in range(start, b.size()):
			var t := float(i - start) / RATE
			b[i] += sin(TAU * notes[k] * t) * amp * exp(-t * 7.0)
	return b


static func _thud(seconds: float, freq: float, amp: float) -> PackedFloat32Array:
	var b := _buf(seconds, RATE)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.1
		b[i] = (sin(TAU * freq * t * (1.0 - t)) * 0.8 + lp * 0.4) * amp * exp(-t * 14.0)
	return b


static func _knocks() -> PackedFloat32Array:
	var b := _buf(1.2, RATE)
	for beat in [0.0, 0.28, 0.56]:
		var start := int(beat * RATE)
		for i in range(start, mini(b.size(), start + int(0.15 * RATE))):
			var t := float(i - start) / RATE
			b[i] += sin(TAU * 120.0 * t) * exp(-t * 35.0) * 0.9
	return b


static func _noise_burst(seconds: float, brightness: float, amp: float, soft_attack: bool = false) -> PackedFloat32Array:
	var b := _buf(seconds, RATE)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / seconds / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * brightness
		var env := sin(PI * t) if soft_attack else (1.0 - t) * minf(1.0, t * 40.0)
		b[i] = lp * amp * env * 2.0
	return b


static func _gunshot() -> PackedFloat32Array:
	var b := _buf(0.9, RATE)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * (0.9 if t < 0.02 else 0.15)
		b[i] = lp * exp(-t * 8.0) * 1.2 + sin(TAU * 60.0 * t) * exp(-t * 12.0) * 0.6
	return b


static func _reload() -> PackedFloat32Array:
	var b := _buf(0.6, RATE)
	for beat in [0.05, 0.4]:
		var start := int(beat * RATE)
		for i in range(start, mini(b.size(), start + int(0.06 * RATE))):
			var t := float(i - start) / RATE
			b[i] += randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.6 + sin(TAU * 1800.0 * t) * exp(-t * 80.0) * 0.4
	return b


static func _engine() -> PackedFloat32Array:
	var b := _buf(1.6, RATE)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 20.0 + 30.0 * minf(1.0, t / 1.0)
		phase += f / RATE
		var putt: float = 0.5 + 0.5 * signf(sin(TAU * phase))
		b[i] = (putt * 0.5 + randf_range(-0.2, 0.2)) * minf(1.0, t * 3.0) * (1.0 - maxf(0.0, t - 1.2) / 0.4) * 0.6
	return b


static func _hammer() -> PackedFloat32Array:
	var b := _buf(0.9, RATE)
	for beat in [0.0, 0.3, 0.6]:
		var start := int(beat * RATE)
		for i in range(start, mini(b.size(), start + int(0.2 * RATE))):
			var t := float(i - start) / RATE
			b[i] += (sin(TAU * 900.0 * t) * 0.4 + sin(TAU * 1450.0 * t) * 0.25 + randf_range(-0.3, 0.3)) * exp(-t * 25.0)
	return b


static func _scream() -> PackedFloat32Array:
	var b := _buf(1.4, RATE)
	var phase := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 300.0 + 500.0 * sin(PI * t / 1.4) + randf_range(-40.0, 40.0)
		phase += f / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.3
		b[i] = (sin(TAU * phase) * 0.35 + lp * 0.5) * sin(PI * t / 1.4) * 0.8
	return b


static func _creak() -> PackedFloat32Array:
	var b := _buf(0.8, RATE)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		phase += (90.0 + 40.0 * sin(TAU * t * 1.5)) / RATE
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		b[i] = saw * 0.25 * sin(PI * t / 0.8) * (0.5 + 0.5 * sin(TAU * t * 23.0))
	return b


static func _metal() -> PackedFloat32Array:
	var b := _buf(2.0, RATE)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * 311.0 * t) * 0.3 + sin(TAU * 523.0 * t) * 0.2 + sin(TAU * 997.0 * t) * 0.1) * exp(-t * 2.2) * 0.6
	return b
