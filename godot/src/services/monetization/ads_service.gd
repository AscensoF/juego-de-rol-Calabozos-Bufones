class_name AdsService
extends RefCounted

## Interfaz base (Adapter Contract) para servicios de publicidad en dispositivos móviles.

func show_rewarded_ad(_placement_id: String, _on_reward: Callable, _on_fail: Callable = Callable()) -> void:
	pass

func show_interstitial_ad(_placement_id: String, _on_closed: Callable = Callable()) -> void:
	pass

func is_rewarded_ready() -> bool:
	return false
