extends Node

## Gestor de música y efectos sonoros de Calabozos & Bufones.

var music_player: AudioStreamPlayer
var current_track: String = ""

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	music_player.volume_db = -8.0
	add_child(music_player)
	
	if EventBus:
		EventBus.combat_started.connect(func(): play_act_music(1))
		EventBus.state_changed.connect(_on_state_changed)

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

func _on_state_changed(_old_state: int, new_state: int) -> void:
	if new_state == Enums.GameFlowState.MAIN_MENU:
		play_act_music(1)
	elif new_state == Enums.GameFlowState.EXPLORATION:
		play_act_music(1)
