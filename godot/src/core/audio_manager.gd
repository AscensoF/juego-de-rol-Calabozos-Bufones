extends Node

## Gestor de música y efectos sonoros de Calabozos & Bufones.
## Incluye soporte para música de los 4 Actos y generador/reproductor de SFX táctiles.

var music_player: AudioStreamPlayer
var current_track: String = ""
var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS := 6
var next_sfx_idx: int = 0

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	music_player.volume_db = -8.0
	add_child(music_player)
	
	for i in MAX_SFX_PLAYERS:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = -3.0
		add_child(p)
		sfx_players.append(p)

	if EventBus:
		EventBus.combat_started.connect(func(): play_act_music(1))
		EventBus.state_changed.connect(_on_state_changed)
		EventBus.attack_resolved.connect(_on_attack_sfx)
		EventBus.item_used.connect(func(_id, _user): play_sfx("heal"))

	play_act_music(1)

func play_act_music(act_num: int) -> void:
	var track_path := "res://assets/audio/music/act%d.ogg" % act_num
	if current_track == track_path and music_player.playing:
		return
	
	if ResourceLoader.exists(track_path):
		var stream = load(track_path)
		if stream:
			music_player.stream = stream
			music_player.play()
			current_track = track_path

func stop_music() -> void:
	if music_player.playing:
		music_player.stop()
	current_track = ""

func play_sfx(type: String) -> void:
	var player: AudioStreamPlayer = sfx_players[next_sfx_idx]
	next_sfx_idx = (next_sfx_idx + 1) % MAX_SFX_PLAYERS

	var stream = _generate_procedural_sfx(type)
	if stream:
		player.stream = stream
		player.play()

func _on_attack_sfx(_attacker: String, _target: String, _roll: int, _mod: int, _total: int, _ac: int, is_hit: bool, is_crit: bool, fumble: bool, damage: int) -> void:
	if fumble:
		play_sfx("miss")
	elif is_crit:
		play_sfx("crit")
	elif is_hit:
		play_sfx("hit")
	else:
		play_sfx("miss")

func _generate_procedural_sfx(type: String) -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.2
	var freq := 440.0
	var is_noise := false
	
	match type:
		"hit":
			duration = 0.15
			freq = 180.0
		"crit":
			duration = 0.35
			freq = 520.0
		"miss":
			duration = 0.12
			freq = 120.0
			is_noise = true
		"heal":
			duration = 0.3
			freq = 660.0

	var total_samples := int(sample_rate * duration)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2) # 16-bit PCM mono

	for i in total_samples:
		var t := float(i) / float(sample_rate)
		var env := 1.0 - (float(i) / float(total_samples))
		var val := 0.0
		
		if is_noise:
			val = (randf() * 2.0 - 1.0) * env * 0.4
		else:
			val = sin(2.0 * PI * freq * t) * env * 0.5
			if type == "crit":
				val += sin(2.0 * PI * (freq * 1.5) * t) * env * 0.25

		var sample16 := int(clamp(val, -1.0, 1.0) * 32767.0)
		buffer.encode_s16(i * 2, sample16)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = buffer
	return wav

func _on_state_changed(_old_state: int, new_state: int) -> void:
	if new_state == Enums.GameFlowState.MAIN_MENU:
		play_act_music(1)
	elif new_state == Enums.GameFlowState.EXPLORATION:
		play_act_music(1)
