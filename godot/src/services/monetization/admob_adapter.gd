class_name AdMobAdapter
extends AdsService

## Adaptador de producción para el plugin oficial de AdMob en Android e iOS.

var admob_singleton: Object = null
var pending_reward_callback: Callable
var pending_fail_callback: Callable

func _init() -> void:
	if Engine.has_singleton("AdMob"):
		admob_singleton = Engine.get_singleton("AdMob")
		if admob_singleton.has_signal("rewarded_video_rewarded"):
			admob_singleton.connect("rewarded_video_rewarded", _on_rewarded_video_rewarded)
		if admob_singleton.has_signal("rewarded_video_failed_to_load"):
			admob_singleton.connect("rewarded_video_failed_to_load", _on_rewarded_video_failed)

func show_rewarded_ad(_placement_id: String, on_reward: Callable, on_fail: Callable = Callable()) -> void:
	pending_reward_callback = on_reward
	pending_fail_callback = on_fail

	if admob_singleton and admob_singleton.has_method("show_rewarded_video"):
		admob_singleton.show_rewarded_video()
	else:
		# Fallback si no está presente en la plataforma
		if on_reward.is_valid():
			on_reward.call()

func show_interstitial_ad(_placement_id: String, on_closed: Callable = Callable()) -> void:
	if admob_singleton and admob_singleton.has_method("show_interstitial"):
		admob_singleton.show_interstitial()
	if on_closed.is_valid():
		on_closed.call()

func is_rewarded_ready() -> bool:
	if admob_singleton and admob_singleton.has_method("is_rewarded_video_loaded"):
		return admob_singleton.is_rewarded_video_loaded()
	return false

func _on_rewarded_video_rewarded(_currency: String, _amount: int) -> void:
	if pending_reward_callback.is_valid():
		pending_reward_callback.call()

func _on_rewarded_video_failed(_error_code: int) -> void:
	if pending_fail_callback.is_valid():
		pending_fail_callback.call()
