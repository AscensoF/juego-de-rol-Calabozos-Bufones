class_name MockAdsService
extends AdsService

## Implementación simulada de anuncios para pruebas locales y depuración en PC/Editor.

func show_rewarded_ad(placement_id: String, on_reward: Callable, _on_fail: Callable = Callable()) -> void:
	print("[MockAdsService] Mostrando anuncio recompensado simulado para: %s" % placement_id)
	if on_reward.is_valid():
		on_reward.call()

func show_interstitial_ad(placement_id: String, on_closed: Callable = Callable()) -> void:
	print("[MockAdsService] Mostrando anuncio intersticial simulado: %s" % placement_id)
	if on_closed.is_valid():
		on_closed.call()

func is_rewarded_ready() -> bool:
	return true
