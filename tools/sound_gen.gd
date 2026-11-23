extends SceneTree

# Synthesised sound effects, ambience and music for src/audio/sound.gd. Not part of the game.
# Run: godot --headless --path . --script tools/sound_gen.gd   (add -- --out=<dir> to write elsewhere)
# Writes art/sfx/<name>.wav (16-bit mono, 22050 Hz). Loops (amb_*, music_*) carry a WAV "smpl" loop so the
# importer loops them by itself. Same seed every run: regenerating gives the same files. The WAVs can be
# replaced by recorded sounds of the same name.

const RATE := 22050
var rng := RandomNumberGenerator.new()
var out_dir := "res://art/sfx"


func _init() -> void:
	rng.seed = 1682
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	build()
	quit()


# --- synthesis --------------------------------------------------------------
func buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


static func attack(i: int) -> float:
	return minf(1.0, i / (0.003 * RATE))


func span(b: PackedFloat32Array, start: float, len: float) -> Vector2i:
	var s := int(start * RATE)
	var n := b.size() - s if len < 0 else mini(b.size() - s, int(len * RATE))
	return Vector2i(s, n)


# wave 0 sine, 1 square, 2 saw, 3 triangle; frequency glides exponentially f0 -> f1; decay = e-folds over the sound
func tone(b: PackedFloat32Array, f0: float, f1: float, vol: float, wave := 0, decay := 5.0, start := 0.0, len := -1.0, vib := 0.0) -> void:
	var r := span(b, start, len)
	var ph := 0.0
	for i in r.y:
		var u := float(i) / r.y
		var f := f0 * pow(f1 / f0, u) * (1.0 + vib * sin(float(i) / RATE * 38.0))
		ph += f / RATE
		var x := ph - floorf(ph)
		var w: float
		match wave:
			1: w = 1.0 if x < 0.5 else -1.0
			2: w = 2.0 * x - 1.0
			3: w = 4.0 * absf(x - 0.5) - 1.0
			_: w = sin(x * TAU)
		b[r.x + i] += w * vol * attack(i) * exp(-decay * u)


# white noise through a one-pole low-pass whose cut-off glides c0 -> c1 Hz; high keeps what the filter removes
func hiss(b: PackedFloat32Array, vol: float, c0: float, c1: float, decay := 5.0, start := 0.0, len := -1.0, high := false) -> void:
	var r := span(b, start, len)
	var lp := 0.0
	for i in r.y:
		var u := float(i) / r.y
		var a := 1.0 - exp(-TAU * c0 * pow(c1 / c0, u) / RATE)
		var w := rng.randf() * 2.0 - 1.0
		lp += a * (w - lp)
		b[r.x + i] += ((w - lp) if high else lp) * vol * attack(i) * exp(-decay * u)


# plucked string (Karplus-Strong)
func pluck(b: PackedFloat32Array, f: float, vol: float, start := 0.0, len := -1.0) -> void:
	var r := span(b, start, len)
	var p := maxi(2, int(RATE / f))
	var ring := PackedFloat32Array()
	ring.resize(p)
	for i in p:
		ring[i] = rng.randf() * 2.0 - 1.0
	for i in r.y:
		var j := i % p
		var v := ring[j]
		ring[j] = 0.497 * (v + ring[(j + 1) % p])
		# short fade at the cut so a clipped note doesn't click
		b[r.x + i] += v * vol * minf(1.0, (r.y - i) / (0.01 * RATE))


# struck metal: inharmonic bell partials
func metal(b: PackedFloat32Array, f: float, vol: float, decay := 6.0, start := 0.0) -> void:
	var ratio := [1.0, 2.76, 5.4, 8.93]
	var amp := [1.0, 0.6, 0.35, 0.2]
	for k in 4:
		tone(b, f * ratio[k], f * ratio[k], vol * amp[k], 0, decay * (1.0 + k * 0.6), start)


static func midi(m: int) -> float:
	return 440.0 * pow(2.0, (m - 69) / 12.0)


# --- writing ------------------------------------------------------------------
func save(name: String, b: PackedFloat32Array, loop := false) -> void:
	var peak := 0.0001
	for x in b:
		peak = maxf(peak, absf(x))
	# loops peak lower: they sit under everything
	var gain := (0.5 if loop else 0.9) / peak
	var pcm := PackedByteArray()
	pcm.resize(b.size() * 2)
	for i in b.size():
		pcm.encode_s16(i * 2, int(tanh(b[i] * gain) * 32000.0))
	var f := FileAccess.open(out_dir.path_join(name + ".wav"), FileAccess.WRITE)
	var smpl := 60 if loop else 0
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + pcm.size() + (8 + smpl if loop else 0))
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)  # PCM
	f.store_16(1)  # mono
	f.store_32(RATE)
	f.store_32(RATE * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(pcm.size())
	f.store_buffer(pcm)
	if loop:
		# one forward loop over the whole sound
		f.store_buffer("smpl".to_ascii_buffer())
		f.store_32(smpl)
		for v in [0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0, 0, 0, 0, b.size() - 1, 0, 0]:
			f.store_32(v)
	f.close()


func make(name: String, sec: float, fill: Callable) -> void:
	var b := buf(sec)
	fill.call(b)
	save(name, b)


# A seamless loop: render a little extra past the end and fold it over the head. Noise beds cross-fade;
# music (wrap) adds the ringing tails of the last notes onto the start, as if the loop had just played.
func make_loop(name: String, sec: float, fill: Callable, wrap := false) -> void:
	var n := int(sec * RATE)
	var fade := RATE * 2 if wrap else RATE / 2
	var b := PackedFloat32Array()
	b.resize(n + fade)
	fill.call(b)
	var o := b.slice(0, n)
	for i in fade:
		var u := float(i) / fade
		o[i] = o[i] + b[n + i] if wrap else o[i] * u + b[n + i] * (1.0 - u)
	save(name, o, true)


# --- music --------------------------------------------------------------------
# Day theme: 84 bpm, eight bars of Am F C G Am F G E, soft triangle pad, sine bass, plucked pentatonic tune.
func day_music(b: PackedFloat32Array) -> void:
	var beat := 60.0 / 84.0
	var chords := [[57, 60, 64], [53, 57, 60], [55, 60, 64], [55, 59, 62], [57, 60, 64], [53, 57, 60], [55, 59, 62], [56, 59, 64]]
	var bass := [45, 41, 48, 43, 45, 41, 43, 40]
	var scale := [69, 72, 74, 76, 79, 81, 84]
	var pick := RandomNumberGenerator.new()
	pick.seed = 5
	for bar in 8:
		var t0 := bar * 4 * beat
		for m in chords[bar]:
			tone(b, midi(m), midi(m), 0.05, 3, 1.2, t0, 4.4 * beat, 0.004)
		tone(b, midi(bass[bar]), midi(bass[bar]), 0.22, 0, 3.0, t0, 1.9 * beat)
		tone(b, midi(bass[bar]), midi(bass[bar]), 0.18, 0, 3.0, t0 + 2 * beat, 1.9 * beat)
		# the tune rests in bars 4 and 8 so the phrase breathes
		if bar % 4 == 3:
			continue
		var step := 3
		for e in 8:
			if pick.randf() < 0.4:
				continue
			step = clampi(step + pick.randi_range(-2, 2), 0, scale.size() - 1)
			pluck(b, midi(scale[step]), 0.16, t0 + e * beat / 2, 0.9)


# Night theme: 96 bpm in D minor, a low drone, ticking eighths, a kick on 1 and 3, an uneasy high line.
func night_music(b: PackedFloat32Array) -> void:
	var beat := 60.0 / 96.0
	var len := 32 * beat
	tone(b, midi(38), midi(38), 0.1, 0, 0.0, 0.0, len)
	tone(b, midi(45), midi(45), 0.04, 3, 0.0, 0.0, len, 0.003)
	var line := [74, 77, 80, 81, 77, 74, 73, 74]
	for bt in 32:
		var t0 := bt * beat
		if bt % 2 == 0:
			tone(b, 110, 40, 0.5, 0, 7.0, t0, 0.25)
		tone(b, midi(50), midi(50), 0.06, 3, 8.0, t0, 0.2)
		tone(b, midi(51 if bt % 8 == 6 else 50), midi(50), 0.04, 3, 8.0, t0 + beat / 2, 0.2)
		hiss(b, 0.05, 7000, 7000, 8.0, t0 + beat / 2, 0.04, true)
	# long notes in bars 3-4 and 7-8
	for i in 8:
		var bar := 2 if i < 4 else 6
		tone(b, midi(line[i]), midi(line[i]), 0.07, 3, 1.5, (bar * 4 + (i % 4) * 2) * beat, 2.2 * beat, 0.008)


# Boss layer: the night theme's length and tempo, a kick on every beat, snare on 2 and 4, a driving low
# ostinato in sixteenths and a stab at each bar.
func boss_music(b: PackedFloat32Array) -> void:
	var beat := 60.0 / 96.0
	var riff := [38, 38, 41, 38, 38, 43, 41, 36]
	for bt in 32:
		var t0 := bt * beat
		tone(b, 120, 40, 0.6, 0, 7.0, t0, 0.22)
		if bt % 2 == 1:
			hiss(b, 0.35, 4500, 1500, 6.0, t0, 0.16)
			tone(b, 210, 150, 0.2, 3, 8.0, t0, 0.1)
		for s in 4:
			var m: int = riff[(bt * 4 + s) % riff.size()]
			tone(b, midi(m), midi(m), 0.09, 2, 6.0, t0 + s * beat / 4, 0.13)
		if bt % 4 == 0:
			for m in [50, 53, 57]:
				tone(b, midi(m), midi(m), 0.06, 2, 4.0, t0, 0.5)


# --- the sounds -------------------------------------------------------------------
func build() -> void:
	# combat
	make("swing", 0.16, func(b): hiss(b, 0.8, 3500, 600, 3.0))
	make("bow", 0.35, func(b): pluck(b, 196, 0.8); hiss(b, 0.3, 5000, 1500, 8.0, 0.0, 0.12, true))
	make("hit", 0.14, func(b): hiss(b, 0.7, 2500, 400, 9.0); tone(b, 150, 55, 0.9, 0, 6.0))
	make("hit_boss", 0.22, func(b): hiss(b, 0.6, 1500, 200, 8.0); tone(b, 90, 35, 1.0, 0, 5.0))
	make("enemy_die", 0.32, func(b): tone(b, 320, 60, 0.6, 1, 4.0); hiss(b, 0.5, 1200, 150, 5.0))
	make("boss_die", 1.4, func(b): tone(b, 120, 30, 0.8, 2, 3.0); hiss(b, 0.7, 900, 60, 3.0); tone(b, 60, 25, 0.8, 0, 2.0))
	make("growl", 0.28, func(b): tone(b, 120, 85, 0.6, 2, 3.0, 0.0, -1.0, 0.06); hiss(b, 0.25, 500, 300, 3.0))
	make("wrecker_atk", 0.35, func(b): tone(b, 80, 50, 0.7, 2, 3.0, 0.0, -1.0, 0.08); tone(b, 70, 40, 0.8, 0, 6.0, 0.18))
	make("spit", 0.2, func(b): hiss(b, 0.6, 900, 2500, 6.0); tone(b, 280, 720, 0.4, 0, 5.0))
	make("boss_roar", 1.3, func(b): tone(b, 75, 48, 0.7, 2, 2.0, 0.0, -1.0, 0.12); tone(b, 112, 70, 0.4, 2, 2.0, 0.0, -1.0, 0.1); hiss(b, 0.5, 700, 250, 2.0))
	make("boss_swing", 0.45, func(b): hiss(b, 0.7, 1800, 250, 3.0); tone(b, 70, 40, 0.6, 2, 3.0))
	make("boss_warn", 0.7, func(b): hiss(b, 0.6, 150, 600, 1.5); tone(b, 45, 70, 0.6, 0, 1.5))
	make("explode", 0.9, func(b): hiss(b, 1.0, 3000, 80, 4.0); tone(b, 70, 30, 1.0, 0, 4.0))
	make("tower_zap", 0.09, func(b): tone(b, 1100, 350, 0.5, 1, 6.0))

	# players
	make("hurt", 0.14, func(b): tone(b, 420, 210, 0.5, 3, 5.0); hiss(b, 0.3, 1500, 400, 9.0))
	make("my_hurt", 0.22, func(b): tone(b, 380, 170, 0.5, 3, 4.0); tone(b, 90, 45, 0.9, 0, 6.0); hiss(b, 0.35, 1800, 300, 8.0))
	make("downed", 0.9, func(b): tone(b, 440, 440, 0.5, 3, 4.0, 0.0, 0.3); tone(b, 370, 370, 0.5, 3, 4.0, 0.25, 0.3); tone(b, 294, 260, 0.5, 3, 3.0, 0.5, 0.4))
	make("death", 1.4, func(b): tone(b, 330, 110, 0.6, 3, 2.5); tone(b, 165, 55, 0.4, 0, 2.5))
	make("revive", 0.7, func(b):
		for i in 4:
			var f: float = [523.0, 659.0, 784.0, 1047.0][i]
			tone(b, f, f, 0.4, 3, 4.0, i * 0.1, 0.3))
	make("flask", 0.4, func(b):
		for i in 4:
			tone(b, 300 + i * 90, 700 + i * 120, 0.4, 0, 6.0, i * 0.08, 0.09))
	make("step", 0.07, func(b): hiss(b, 0.6, 600, 200, 8.0))
	make("pickup", 0.1, func(b): tone(b, 880, 1320, 0.5, 3, 3.0))

	# gathering and building
	make("chop", 0.14, func(b): hiss(b, 0.6, 1400, 300, 8.0); tone(b, 190, 120, 0.8, 3, 7.0))
	make("mine", 0.16, func(b): metal(b, 1250, 0.35, 9.0); hiss(b, 0.4, 6000, 2000, 10.0, 0.0, -1.0, true))
	make("herb", 0.18, func(b): hiss(b, 0.6, 4000, 1500, 4.0, 0.0, -1.0, true))
	make("crumble", 0.45, func(b):
		for i in 5:
			hiss(b, 0.5, 1500, 200, 6.0, i * 0.06, 0.15))
	make("build", 0.5, func(b): tone(b, 110, 60, 0.8, 0, 6.0, 0.0, 0.2); metal(b, 1700, 0.25, 10.0, 0.18); metal(b, 1800, 0.25, 10.0, 0.32))
	make("repair", 0.12, func(b): metal(b, 1900, 0.4, 9.0))
	make("gen_hit", 0.6, func(b): metal(b, 210, 0.5, 5.0); tone(b, 70, 40, 0.7, 0, 6.0))
	make("door_hit", 0.2, func(b): hiss(b, 0.6, 700, 150, 7.0); tone(b, 120, 70, 0.9, 3, 6.0))
	make("chest_open", 0.45, func(b): tone(b, 210, 360, 0.35, 2, 2.0, 0.0, 0.32, 0.04); metal(b, 2300, 0.3, 12.0, 0.33))
	make("craft_done", 0.5, func(b): tone(b, 660, 660, 0.4, 3, 4.0, 0.0, 0.25); tone(b, 990, 990, 0.4, 3, 3.0, 0.12))

	# tactical items
	make("poison", 1.2, func(b):
		var r := RandomNumberGenerator.new()
		r.seed = 3
		for i in 9:
			var f := 180.0 + r.randf() * 320.0
			tone(b, f, f * 1.8, 0.3, 0, 6.0, i * 0.12, 0.08)
		hiss(b, 0.2, 600, 300, 2.0))
	make("heal_zone", 1.0, func(b):
		for i in 4:
			metal(b, [784.0, 988.0, 1175.0, 1568.0][i], 0.18, 5.0, i * 0.08)
		hiss(b, 0.1, 3000, 6000, 3.0, 0.0, -1.0, true))
	make("trap_set", 0.45, func(b): tone(b, 150, 105, 0.4, 2, 3.0, 0.0, -1.0, 0.05); hiss(b, 0.4, 4000, 1200, 5.0, 0.0, -1.0, true))
	make("snare", 0.14, func(b): hiss(b, 0.6, 6000, 2000, 9.0, 0.0, -1.0, true); tone(b, 650, 200, 0.5, 3, 7.0))
	make("haste", 0.4, func(b): hiss(b, 0.5, 500, 5000, 2.0); tone(b, 300, 950, 0.35, 3, 3.0))

	# match flow and UI
	make("start", 1.0, func(b):
		for i in 3:
			var f: float = [392.0, 523.0, 659.0][i]
			tone(b, f, f, 0.4, 3, 3.0, i * 0.12))
	make("dawn", 1.6, func(b):
		for i in 5:
			metal(b, [523.0, 659.0, 784.0, 1047.0, 1319.0][i], 0.25, 4.0, i * 0.14))
	make("dusk_horn", 1.8, func(b): tone(b, 220, 210, 0.4, 2, 1.5, 0.0, -1.0, 0.01); tone(b, 222, 212, 0.4, 2, 1.5); tone(b, 110, 105, 0.3, 0, 1.5))
	make("night_gong", 2.5, func(b): metal(b, 98, 0.7, 2.5); hiss(b, 0.15, 200, 80, 2.0))
	make("win", 2.0, func(b):
		for i in 4:
			var f: float = [523.0, 659.0, 784.0, 1047.0][i]
			tone(b, f, f, 0.35, 1, 3.0, i * 0.18)
		tone(b, 523, 523, 0.3, 3, 2.0, 0.72))
	make("lose", 2.0, func(b):
		for i in 4:
			var f: float = [392.0, 349.0, 311.0, 262.0][i]
			tone(b, f, f * 0.98, 0.4, 3, 2.5, i * 0.3, 0.6))
	make("ui_click", 0.04, func(b): tone(b, 1600, 1200, 0.4, 3, 8.0))
	make("ui_open", 0.12, func(b): tone(b, 700, 700, 0.3, 3, 6.0, 0.0, 0.06); tone(b, 1050, 1050, 0.3, 3, 6.0, 0.05))
	make("ui_close", 0.12, func(b): tone(b, 1050, 1050, 0.3, 3, 6.0, 0.0, 0.06); tone(b, 700, 700, 0.3, 3, 6.0, 0.05))
	make("ping", 0.3, func(b): tone(b, 1046, 1046, 0.4, 0, 5.0))

	# music
	make_loop("music_day", 32 * 60.0 / 84.0, day_music, true)
	make_loop("music_night", 32 * 60.0 / 96.0, night_music, true)
	make_loop("music_boss", 32 * 60.0 / 96.0, boss_music, true)

	# ambience: wind and birds by day; crickets, a low drone and quieter wind by night (8 s loops)
	make_loop("amb_day", 8.0, func(b):
		var wind := PackedFloat32Array()
		wind.resize(b.size())
		hiss(wind, 0.5, 380, 380, 0.0)
		for i in b.size():
			b[i] = wind[i] * (0.55 + 0.45 * sin(float(i) / RATE * TAU / 8.0))
		for s in [0.7, 0.85, 1.0, 3.3, 5.4, 5.55, 5.7, 6.9]:
			tone(b, 2700, 3700, 0.06, 0, 3.0, s, 0.09, 0.05))
	make_loop("amb_night", 8.0, func(b):
		hiss(b, 0.25, 250, 250, 0.0)
		tone(b, 55, 55, 0.05, 0, 0.0)
		tone(b, 82.5, 82.5, 0.03, 0, 0.0)
		for c in 16:
			for k in 3:
				tone(b, 4400, 4400, 0.025, 0, 2.0, c * 0.5 + k * 0.035, 0.025)
		for c in 10:
			for k in 4:
				tone(b, 3900, 3900, 0.018, 0, 2.0, 0.23 + c * 0.8 + k * 0.03, 0.022))
