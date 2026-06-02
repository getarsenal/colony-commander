## Procedural audio (autoload "Audio"). Every sound is synthesised from scratch
## at startup — short oscillator/noise blips for game events plus a gentle
## ambient bed — so the soundscape is entirely our own. Voices are pooled and
## per-sound cooldowns keep busy combat from machine-gunning the same blip.
extends Node

const MIX := 22050
const VOICES := 16

var muted := false

var _streams := {}              # name -> AudioStreamWAV
var _cooldown := {}             # name -> min seconds between plays
var _last := {}                 # name -> last play time
var _players: Array = []
var _next := 0
var _ambient: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

	_streams["click"]   = _wav(_blip(1200.0, 0.045, 0.5, "square"))
	_streams["deny"]    = _wav(_blip(200.0, 0.10, 0.4, "square"))
	_streams["harvest"] = _wav(_slide(680.0, 1040.0, 0.13, 0.5))
	_streams["buy"]     = _wav(_arp([660.0, 880.0, 1320.0], 0.06, 0.45))
	_streams["spit"]    = _wav(_noise(0.06, 0.35, 28.0, 0.6))
	_streams["kill"]    = _wav(_mix(_noise(0.09, 0.5, 22.0, 0.0), _blip(180.0, 0.09, 0.4, "saw")))
	_streams["hill"]    = _wav(_mix(_blip(90.0, 0.20, 0.7, "sine"), _noise(0.16, 0.4, 16.0, 0.0)))
	_streams["boss"]    = _wav(_mix(_slide(320.0, 70.0, 0.55, 0.8, "saw"), _noise(0.5, 0.5, 5.0, 0.0)))
	_streams["victory"] = _wav(_arp([523.0, 659.0, 784.0, 1046.0], 0.12, 0.5))
	_streams["defeat"]  = _wav(_arp([440.0, 392.0, 311.0, 262.0], 0.16, 0.55, "saw"))

	_cooldown = {"kill": 0.05, "spit": 0.07, "hill": 0.11, "harvest": 0.045}

	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "Master"
	_ambient.stream = _wav(_ambient_bed(4.0), true)
	_ambient.volume_db = -18.0
	add_child(_ambient)
	_ambient.play()

## Play a one-shot SFX (respects per-sound cooldown + mute).
func sfx(name: String, vol_db := -6.0, pitch_var := 0.06) -> void:
	if muted or not _streams.has(name):
		return
	var cd: float = _cooldown.get(name, 0.0)
	var now := Time.get_ticks_msec() / 1000.0
	if cd > 0.0 and now - float(_last.get(name, -10.0)) < cd:
		return
	_last[name] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[name]
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()

func set_muted(m: bool) -> void:
	muted = m
	_ambient.volume_db = -80.0 if m else -18.0

# --- synthesis ----------------------------------------------------------------

func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

func _osc(ph: float, wave: String) -> float:
	match wave:
		"square": return 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		"saw": return 2.0 * fmod(ph, 1.0) - 1.0
		"tri": return 4.0 * abs(fmod(ph, 1.0) - 0.5) - 1.0
		_: return sin(ph * TAU)

func _blip(freq: float, dur: float, vol: float, wave := "sine") -> PackedFloat32Array:
	var n := int(dur * MIX)
	var out := PackedFloat32Array(); out.resize(n)
	for i in n:
		var t := float(i) / MIX
		var env: float = exp(-t * 7.0) * clampf(t / 0.004, 0.0, 1.0)
		out[i] = _osc(freq * t, wave) * env * vol
	return out

func _slide(f0: float, f1: float, dur: float, vol: float, wave := "sine") -> PackedFloat32Array:
	var n := int(dur * MIX)
	var out := PackedFloat32Array(); out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / MIX
		var f: float = lerpf(f0, f1, t / dur)
		ph += f / MIX
		var env: float = exp(-t * 4.0) * clampf(t / 0.004, 0.0, 1.0)
		out[i] = _osc(ph, wave) * env * vol
	return out

func _noise(dur: float, vol: float, decay: float, _hp: float) -> PackedFloat32Array:
	var n := int(dur * MIX)
	var out := PackedFloat32Array(); out.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / MIX
		var env := exp(-t * decay)
		var w := randf() * 2.0 - 1.0
		var hp := w - prev   # crude high-pass for a crisper "tss"
		prev = w
		out[i] = hp * env * vol
	return out

func _arp(freqs: Array, note: float, vol: float, wave := "sine") -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f in freqs:
		out.append_array(_blip(f, note, vol, wave))
	return out

func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n: int = max(a.size(), b.size())
	var out := PackedFloat32Array(); out.resize(n)
	for i in n:
		var va: float = a[i] if i < a.size() else 0.0
		var vb: float = b[i] if i < b.size() else 0.0
		out[i] = clampf(va + vb, -1.0, 1.0)
	return out

## A gentle looping pad: a low chord + slow filtered "wind" noise.
func _ambient_bed(dur: float) -> PackedFloat32Array:
	var n := int(dur * MIX)
	var out := PackedFloat32Array(); out.resize(n)
	var chord := [98.0, 147.0, 196.0]   # G2-ish drone
	var lp := 0.0
	for i in n:
		var t := float(i) / MIX
		var s := 0.0
		for f in chord:
			s += sin(f * t * TAU) * 0.12
		# slow tremolo so the loop breathes
		s *= 0.7 + 0.3 * sin(t * 0.5 * TAU)
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * 0.02            # low-pass wind
		s += lp * 0.10
		# fade the seam so the loop is click-free
		var seam: float = minf(1.0, minf(t, dur - t) / 0.05)
		out[i] = s * seam
	return out
