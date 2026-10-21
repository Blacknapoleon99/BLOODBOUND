class_name Audio
extends Node
## Global audio service: `Audio.sfx(&"hit_flesh")`, `Audio.music(&"music_boss")`.
## Sounds are the generated WAVs in res://assets/audio/ (see tools/generate_audio.gd).
## Creates "Music" and "SFX" buses under Master on first use and applies the volume settings.
## A small player pool plays overlapping effects with slight pitch variation.
## `played` counts every effect started, for tests and debugging.
## Variants: if `<id>_2.wav`, `<id>_3.wav`... exist, `sfx(id)` picks one at random (less repetition).
## Voice lines (`voice(id)`) use their own player: one line at a time, an urgent line interrupts.

const DIR: String = "res://assets/audio/"
const POOL_SIZE: int = 14

static var played: Dictionary = {}
static var current_music: StringName = &""
static var _instance: Audio
static var _streams: Dictionary = {}
static var _variants: Dictionary = {}  # id -> Array[AudioStream]
static var voiced: Dictionary = {}  # voice line id -> times started (tests)

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer
var _pending: Array = []  # sounds requested before the node entered the tree


static func instance() -> Audio:
    if is_instance_valid(_instance):
        return _instance
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    if tree == null:
        return null
    _ensure_buses()
    _instance = Audio.new()
    _instance.name = "Audio"
    _instance.process_mode = Node.PROCESS_MODE_ALWAYS
    tree.root.add_child.call_deferred(_instance)
    _instance._build()
    apply_volumes()
    return _instance


static func sfx(id: StringName, pitch_variation: float = 0.06, volume_db: float = 0.0) -> void:
    var audio: Audio = instance()
    if audio == null:
        return
    var takes: Array = _takes(id)
    if takes.is_empty():
        return
    var stream: AudioStream = takes[randi() % takes.size()]
    played[id] = int(played.get(id, 0)) + 1
    if not audio.is_inside_tree():
        audio._pending.append([stream, pitch_variation, volume_db])
        return
    audio._play(stream, pitch_variation, volume_db)


func _play(stream: AudioStream, pitch_variation: float, volume_db: float) -> void:
    var audio: Audio = self
    var player: AudioStreamPlayer = audio._pool[audio._next]
    audio._next = (audio._next + 1) % audio._pool.size()
    player.stream = stream
    player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
    player.volume_db = volume_db
    player.play()


static func music(id: StringName) -> void:
    var audio: Audio = instance()
    if audio == null or current_music == id:
        return
    if id == &"":
        current_music = id
        audio._music_player.stop()
        return
    var stream: AudioStreamWAV = _stream(id) as AudioStreamWAV
    if stream == null:
        return
    current_music = id
    # Loop the whole file (the generator crossfades the seam).
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = int(stream.get_length() * stream.mix_rate)  # frames; import may re-encode
    audio._music_player.stream = stream
    if audio.is_inside_tree():
        audio._music_player.play()  # otherwise _ready starts it


## Plays a voice line unless another is still talking (`urgent` lines interrupt it).
## Returns true if the line started.
static func voice(id: StringName, urgent: bool = false) -> bool:
    var audio: Audio = instance()
    if audio == null or not audio.is_inside_tree():
        return false
    var stream: AudioStream = _stream(id)
    if stream == null:
        return false
    if audio._voice_player.playing and not urgent:
        return false
    audio._voice_player.stream = stream
    audio._voice_player.play()
    voiced[id] = int(voiced.get(id, 0)) + 1
    return true


static func stop_voice() -> void:
    if is_instance_valid(_instance):
        _instance._voice_player.stop()


static func is_voice_playing() -> bool:
    return is_instance_valid(_instance) and _instance._voice_player.playing


static func stop_music() -> void:
    music(&"")


static func apply_volumes() -> void:
    _ensure_buses()
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), _db(GameSettings.music_volume))
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"SFX"), _db(GameSettings.sfx_volume))


static func _db(linear: float) -> float:
    return -80.0 if linear <= 0.001 else linear_to_db(linear)


static func _ensure_buses() -> void:
    for bus: StringName in [&"Music", &"SFX"]:
        if AudioServer.get_bus_index(bus) == -1:
            AudioServer.add_bus()
            var index: int = AudioServer.bus_count - 1
            AudioServer.set_bus_name(index, bus)
            AudioServer.set_bus_send(index, &"Master")


## The base sound plus any numbered variants (`<id>_2` ... `<id>_6`).
static func _takes(id: StringName) -> Array:
    if not _variants.has(id):
        var takes: Array = []
        var base: AudioStream = _stream(id)
        if base != null:
            takes.append(base)
        for n in range(2, 7):
            var extra: AudioStream = _stream(StringName("%s_%d" % [id, n]))
            if extra == null:
                break
            takes.append(extra)
        _variants[id] = takes
    return _variants[id]


static func _stream(id: StringName) -> AudioStream:
    if not _streams.has(id):
        var path: String = DIR + String(id) + ".wav"
        _streams[id] = load(path) if ResourceLoader.exists(path) else null
    return _streams[id]


func _ready() -> void:
    for request: Array in _pending:
        _play(request[0], request[1], request[2])
    _pending.clear()
    if _music_player.stream != null and current_music != &"":
        _music_player.play()


func _exit_tree() -> void:
    # Stop playback and drop references, or the playing stream outlives the tree (leak at exit).
    for player: AudioStreamPlayer in _pool + [_music_player, _voice_player]:
        player.stop()
        player.stream = null
    _streams.clear()
    _variants.clear()
    if _instance == self:
        _instance = null
        current_music = &""


func _build() -> void:
    for i in POOL_SIZE:
        var player: AudioStreamPlayer = AudioStreamPlayer.new()
        player.bus = &"SFX"
        add_child(player)
        _pool.append(player)
    _music_player = AudioStreamPlayer.new()
    _music_player.bus = &"Music"
    _music_player.volume_db = -4.0
    add_child(_music_player)
    _voice_player = AudioStreamPlayer.new()
    _voice_player.bus = &"SFX"
    _voice_player.volume_db = 2.0
    add_child(_voice_player)
