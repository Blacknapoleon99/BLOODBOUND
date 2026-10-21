extends SceneTree
## Renders every BLOODBOUND sound effect and music loop with simple additive/noise synthesis
## and writes them as 16-bit mono WAV files to res://assets/audio/. Deterministic (fixed seed),
## so re-running produces identical files. All audio is original, generated here.
##
## Run: godot_console --headless --path . -s res://tools/generate_audio.gd

const RATE: int = 22050
const OUT_DIR: String = "res://assets/audio/"

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
    _rng.seed = 1666
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
    var count: int = 0
    for id: String in SFX:
        _save(id, call(SFX[id]) as PackedFloat32Array, false)
        count += 1
    _save("music_level", _music_level(), true)
    _save("music_boss", _music_boss(), true)
    print("generated %d sfx + 2 music loops into %s" % [count, OUT_DIR])
    quit()


const SFX: Dictionary = {
    "slash": "_slash", "slash_finisher": "_slash_finisher", "heavy_swing": "_heavy_swing",
    "hit_flesh": "_hit_flesh", "hit_weak": "_hit_weak", "player_hurt": "_player_hurt",
    "dodge": "_dodge", "jump": "_jump", "land": "_land", "death": "_death",
    "card_spear": "_card_spear", "card_shield": "_card_shield", "card_chains": "_card_chains",
    "card_bell": "_card_bell", "card_epitaph": "_card_epitaph", "card_pact": "_card_pact",
    "card_choir": "_card_choir", "card_transfusion": "_card_transfusion", "card_refused": "_card_refused",
    "bishop_roar": "_bishop_roar", "bishop_slam": "_bishop_slam", "lance_whistle": "_lance_whistle",
    "censer_swing": "_censer_swing", "beam_charge": "_beam_charge", "beam_fire": "_beam_fire",
    "summon": "_summon", "archer_draw": "_archer_draw", "arrow_release": "_arrow_release",
    "walls_rise": "_walls_rise", "altar": "_altar", "ui_click": "_ui_click", "victory": "_victory",
    "bone_rain": "_bone_rain", "geyser": "_geyser", "hound_pounce": "_hound_pounce",
    "husk_burst": "_husk_burst", "soldier_lunge": "_soldier_lunge", "equip": "_equip",
}


# --- Building blocks ----------------------------------------------------------------

func _buf(seconds: float) -> PackedFloat32Array:
    var b: PackedFloat32Array = PackedFloat32Array()
    b.resize(int(seconds * RATE))
    return b


func _env(t: float, attack: float, decay: float) -> float:
    if t < attack:
        return t / maxf(attack, 0.0001)
    return exp(-(t - attack) / maxf(decay, 0.0001))


## Noise with a one-pole low-pass whose cutoff sweeps from f0 to f1 (Hz).
func _noise(b: PackedFloat32Array, start: float, seconds: float, gain: float, f0: float, f1: float, attack: float, decay: float) -> void:
    var lp: float = 0.0
    var n: int = int(seconds * RATE)
    var i0: int = int(start * RATE)
    for i in n:
        if i0 + i >= b.size():
            break
        var t: float = float(i) / RATE
        var f: float = lerpf(f0, f1, t / seconds)
        var a: float = clampf(TAU * f / RATE, 0.0, 1.0)
        lp += a * (_rng.randf_range(-1.0, 1.0) - lp)
        b[i0 + i] += lp * gain * _env(t, attack, decay)


## Sine (or a few harmonics) with an exponential pitch glide from f0 to f1.
func _tone(b: PackedFloat32Array, start: float, seconds: float, gain: float, f0: float, f1: float, attack: float, decay: float, harmonics: int = 1) -> void:
    var phase: float = 0.0
    var n: int = int(seconds * RATE)
    var i0: int = int(start * RATE)
    for i in n:
        if i0 + i >= b.size():
            break
        var t: float = float(i) / RATE
        var f: float = f0 * pow(f1 / f0, t / seconds)
        phase += TAU * f / RATE
        var v: float = 0.0
        for h in harmonics:
            v += sin(phase * (h + 1)) / float(h + 1)
        b[i0 + i] += v * gain * _env(t, attack, decay)


func _echo(b: PackedFloat32Array, delay: float, feedback: float) -> void:
    var d: int = int(delay * RATE)
    for i in range(d, b.size()):
        b[i] += b[i - d] * feedback


# --- Player / combat -----------------------------------------------------------------

func _slash() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.18)
    _noise(b, 0.0, 0.18, 0.7, 6000.0, 1500.0, 0.01, 0.05)
    return b


func _slash_finisher() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.3)
    _noise(b, 0.0, 0.3, 0.8, 7000.0, 900.0, 0.015, 0.08)
    _tone(b, 0.02, 0.2, 0.25, 900.0, 300.0, 0.005, 0.06)
    return b


func _heavy_swing() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.45)
    _noise(b, 0.0, 0.45, 0.8, 600.0, 2500.0, 0.2, 0.12)
    return b


func _hit_flesh() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.22)
    _tone(b, 0.0, 0.2, 0.9, 140.0, 55.0, 0.002, 0.06)
    _noise(b, 0.0, 0.12, 0.6, 2500.0, 600.0, 0.001, 0.03)
    return b


func _hit_weak() -> PackedFloat32Array:
    var b: PackedFloat32Array = _hit_flesh()
    b.resize(int(0.6 * RATE))
    _tone(b, 0.0, 0.6, 0.35, 1320.0, 1300.0, 0.002, 0.25, 3)
    _tone(b, 0.0, 0.6, 0.2, 1980.0, 1960.0, 0.002, 0.18)
    return b


func _player_hurt() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.35)
    _tone(b, 0.0, 0.3, 0.9, 110.0, 45.0, 0.003, 0.09)
    _noise(b, 0.0, 0.3, 0.5, 900.0, 300.0, 0.01, 0.08)
    return b


func _dodge() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.25)
    _noise(b, 0.0, 0.25, 0.6, 800.0, 4000.0, 0.05, 0.07)
    return b


func _jump() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.12)
    _noise(b, 0.0, 0.12, 0.35, 1500.0, 3000.0, 0.01, 0.04)
    return b


func _land() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.12)
    _tone(b, 0.0, 0.1, 0.5, 90.0, 50.0, 0.002, 0.03)
    _noise(b, 0.0, 0.06, 0.3, 1200.0, 400.0, 0.001, 0.02)
    return b


func _death() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(1.4)
    _tone(b, 0.0, 1.4, 0.7, 220.0, 55.0, 0.01, 0.5, 3)
    _noise(b, 0.0, 1.0, 0.3, 600.0, 100.0, 0.05, 0.3)
    _echo(b, 0.18, 0.35)
    return b


# --- Cards ------------------------------------------------------------------------------

func _card_spear() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.4)
    _noise(b, 0.0, 0.35, 0.6, 1500.0, 7000.0, 0.02, 0.12)
    _tone(b, 0.0, 0.3, 0.3, 300.0, 1200.0, 0.01, 0.1, 2)
    return b


func _card_shield() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.9)
    for f: float in [392.0, 494.0, 587.0]:
        _tone(b, 0.0, 0.9, 0.22, f, f * 1.01, 0.03, 0.35, 2)
    _echo(b, 0.11, 0.3)
    return b


func _card_chains() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.8)
    for k in 5:
        var t0: float = 0.05 + k * 0.09
        _tone(b, t0, 0.3, 0.25, 1700.0 + k * 230.0, 1650.0 + k * 230.0, 0.001, 0.06, 3)
        _noise(b, t0, 0.05, 0.25, 5000.0, 2000.0, 0.001, 0.015)
    return b


func _card_bell() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(2.2)
    for p: Array in [[220.0, 0.5], [440.0, 0.3], [528.0, 0.22], [660.0, 0.15], [1100.0, 0.08]]:
        _tone(b, 0.0, 2.2, p[1], p[0], p[0] * 0.998, 0.002, 0.8)
    return b


func _card_epitaph() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.5)
    _noise(b, 0.0, 0.2, 0.9, 4000.0, 800.0, 0.001, 0.04)
    _tone(b, 0.0, 0.4, 0.6, 80.0, 40.0, 0.002, 0.12)
    return b


func _card_pact() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.8)
    for t0: float in [0.0, 0.22]:
        _tone(b, t0, 0.2, 0.8, 70.0, 45.0, 0.005, 0.05)
    _tone(b, 0.0, 0.8, 0.15, 330.0, 220.0, 0.2, 0.3)
    return b


func _card_choir() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(1.6)
    for f: float in [261.6, 311.1, 392.0, 523.2]:
        _tone(b, 0.0, 1.6, 0.14, f, f * 1.004, 0.3, 0.6, 2)
        _tone(b, 0.0, 1.6, 0.1, f * 1.006, f * 1.01, 0.35, 0.6)
    return b


func _card_transfusion() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(1.0)
    _tone(b, 0.0, 1.0, 0.3, 300.0, 600.0, 0.4, 0.3, 2)
    _tone(b, 0.0, 1.0, 0.2, 450.0, 900.0, 0.45, 0.3)
    return b


func _card_refused() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.22)
    _tone(b, 0.0, 0.1, 0.35, 140.0, 130.0, 0.002, 0.04, 4)
    _tone(b, 0.11, 0.1, 0.35, 120.0, 110.0, 0.002, 0.04, 4)
    return b


# --- Bishop / enemies / world ---------------------------------------------------------

func _bishop_roar() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(2.2)
    _noise(b, 0.0, 2.2, 0.8, 500.0, 120.0, 0.15, 0.9)
    _tone(b, 0.0, 2.2, 0.6, 90.0, 38.0, 0.2, 0.8, 4)
    _echo(b, 0.25, 0.3)
    return b


func _bishop_slam() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(1.2)
    _tone(b, 0.0, 1.0, 1.0, 70.0, 28.0, 0.002, 0.3)
    _noise(b, 0.0, 0.6, 0.8, 2000.0, 150.0, 0.001, 0.15)
    _echo(b, 0.2, 0.25)
    return b


func _lance_whistle() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(1.2)
    _tone(b, 0.0, 1.2, 0.2, 500.0, 1400.0, 0.4, 0.4)
    _noise(b, 0.0, 1.2, 0.25, 2000.0, 5000.0, 0.4, 0.4)
    return b


func _censer_swing() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(1.6)
    _noise(b, 0.0, 1.6, 0.6, 300.0, 1200.0, 0.6, 0.5)
    for k in 4:
        _tone(b, 0.1 + k * 0.35, 0.25, 0.12, 900.0, 880.0, 0.001, 0.05, 3)
    return b


func _beam_charge() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(1.3)
    _tone(b, 0.0, 1.3, 0.35, 80.0, 640.0, 1.0, 0.3, 3)
    _noise(b, 0.0, 1.3, 0.15, 500.0, 4000.0, 1.0, 0.3)
    return b


func _beam_fire() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(1.6)
    _tone(b, 0.0, 1.6, 0.45, 110.0, 105.0, 0.01, 0.9, 6)
    _noise(b, 0.0, 1.6, 0.4, 3000.0, 1500.0, 0.01, 0.9)
    return b


func _summon() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(1.5)
    _noise(b, 0.0, 1.5, 0.7, 200.0, 60.0, 0.3, 0.6)
    for k in 6:
        _noise(b, 0.2 + k * 0.18, 0.06, 0.35, 3500.0, 1500.0, 0.001, 0.02)
    return b


func _archer_draw() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.8)
    for k in 8:
        _noise(b, k * 0.09, 0.05, 0.2, 2500.0 + k * 150.0, 1800.0, 0.002, 0.02)
    return b


func _arrow_release() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.35)
    _tone(b, 0.0, 0.25, 0.4, 330.0, 290.0, 0.001, 0.07, 3)
    _noise(b, 0.0, 0.3, 0.35, 3000.0, 6000.0, 0.01, 0.08)
    return b


func _walls_rise() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(1.0)
    _noise(b, 0.0, 1.0, 0.8, 250.0, 700.0, 0.05, 0.4)
    _tone(b, 0.0, 0.6, 0.4, 60.0, 45.0, 0.01, 0.25)
    return b


func _altar() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(1.6)
    for p: Array in [[523.2, 0.0], [659.3, 0.12], [784.0, 0.24], [1046.5, 0.36]]:
        _tone(b, p[1], 1.2, 0.18, p[0], p[0], 0.01, 0.4, 2)
    _echo(b, 0.15, 0.3)
    return b


func _ui_click() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.06)
    _tone(b, 0.0, 0.06, 0.3, 1200.0, 900.0, 0.001, 0.015)
    return b


func _victory() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(3.0)
    for p: Array in [[220.0, 0.0], [261.6, 0.0], [329.6, 0.0], [440.0, 0.4], [523.2, 0.4], [659.3, 0.4]]:
        _tone(b, p[1], 2.6, 0.12, p[0], p[0], 0.08, 1.2, 3)
    _echo(b, 0.21, 0.3)
    return b


# --- Music -------------------------------------------------------------------------------

## 24 s ambient drone in A minor: low organ fifths breathing on a slow LFO, a distant bell.
func _bone_rain() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(1.4)
    _noise(b, 0.0, 0.9, 0.3, 4000.0, 800.0, 0.5, 0.3)
    for k in 6:
        _noise(b, 0.75 + k * 0.09, 0.12, 0.5, 2500.0, 900.0, 0.001, 0.06)
    return b


func _geyser() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.9)
    _tone(b, 0.0, 0.5, 0.3, 60.0, 90.0, 0.4, 0.1)
    _noise(b, 0.45, 0.4, 0.8, 300.0, 3000.0, 0.005, 0.25)
    _tone(b, 0.45, 0.3, 0.4, 180.0, 60.0, 0.002, 0.2)
    return b


func _hound_pounce() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.6)
    _tone(b, 0.0, 0.35, 0.4, 220.0, 140.0, 0.01, 0.2, 4)
    _noise(b, 0.0, 0.35, 0.35, 900.0, 2500.0, 0.02, 0.2)
    return b


func _husk_burst() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.8)
    _noise(b, 0.0, 0.7, 0.7, 200.0, 900.0, 0.003, 0.5)
    _tone(b, 0.0, 0.4, 0.35, 90.0, 40.0, 0.003, 0.3)
    _echo(b, 0.12, 0.3)
    return b


func _soldier_lunge() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.7)
    _tone(b, 0.0, 0.5, 0.35, 120.0, 260.0, 0.3, 0.1, 3)
    _noise(b, 0.45, 0.25, 0.5, 1500.0, 600.0, 0.005, 0.15)
    return b


func _equip() -> PackedFloat32Array:
    var b: PackedFloat32Array = _buf(0.5)
    _tone(b, 0.0, 0.35, 0.3, 1200.0, 1150.0, 0.001, 0.25, 4)
    _noise(b, 0.0, 0.1, 0.3, 3000.0, 2000.0, 0.001, 0.05)
    return b


func _music_level() -> PackedFloat32Array:
    var seconds: float = 24.0
    var b: PackedFloat32Array = _buf(seconds)
    var chords: Array = [[55.0, 82.4, 110.0], [43.65, 65.4, 87.3], [49.0, 73.4, 98.0], [41.2, 61.7, 82.4]]
    for c in chords.size():
        var t0: float = c * 6.0
        for f: float in chords[c]:
            _tone(b, t0, 6.4, 0.11, f, f * 1.002, 2.0, 3.0, 4)
    for t0: float in [3.0, 15.0]:
        _tone(b, t0, 4.0, 0.06, 880.0, 878.0, 0.005, 1.5, 3)
    _noise(b, 0.0, seconds, 0.05, 300.0, 300.0, 4.0, 40.0)
    _seam(b, 1.0)
    return _normalize(b, 0.6)


## 16 s boss loop at 120 bpm: kick on the beat, a driving low pulse, minor choir pad.
func _music_boss() -> PackedFloat32Array:
    var seconds: float = 16.0
    var b: PackedFloat32Array = _buf(seconds)
    var beat: float = 0.5
    var roots: Array = [55.0, 43.65, 49.0, 41.2]  # Am F G Em
    for bar in 8:
        var root: float = roots[(bar / 2) % 4]
        for k in 4:
            var t0: float = (bar * 4 + k) * beat
            _tone(b, t0, 0.35, 0.9, 120.0, 40.0, 0.002, 0.08)
            if k % 2 == 1:
                _noise(b, t0, 0.15, 0.25, 6000.0, 3000.0, 0.001, 0.03)
            for h in 2:
                _tone(b, t0 + h * beat * 0.5, beat * 0.45, 0.22, root * 2.0, root * 2.0, 0.005, 0.08, 5)
        if bar % 2 == 0:
            for mult: float in [4.0, 4.76, 6.0]:
                _tone(b, bar * 4 * beat, 4.2, 0.05, root * mult, root * mult * 1.003, 0.6, 1.6, 2)
    _seam(b, 0.25)
    return _normalize(b, 0.7)


## Crossfades the tail into the head so the loop has no click.
func _seam(b: PackedFloat32Array, fade: float) -> void:
    var n: int = int(fade * RATE)
    for i in n:
        var w: float = float(i) / n
        b[i] = b[i] * w + b[b.size() - n + i] * (1.0 - w)
    b.resize(b.size() - n)


func _normalize(b: PackedFloat32Array, peak: float) -> PackedFloat32Array:
    var m: float = 0.0001
    for v: float in b:
        m = maxf(m, absf(v))
    for i in b.size():
        b[i] = b[i] / m * peak
    return b


func _save(id: String, samples: PackedFloat32Array, loop: bool) -> void:
    if not loop:
        samples = _normalize(samples, 0.85)
    var data: PackedByteArray = PackedByteArray()
    data.resize(samples.size() * 2)
    for i in samples.size():
        data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
    var wav: AudioStreamWAV = AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = RATE
    wav.stereo = false
    wav.data = data
    if loop:
        wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
        wav.loop_begin = 0
        wav.loop_end = samples.size()
    var err: Error = wav.save_to_wav(OUT_DIR + id + ".wav")
    if err != OK:
        printerr("failed to save ", id, ": ", err)
