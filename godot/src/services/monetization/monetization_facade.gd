class_name MonetizationFacade
extends RefCounted

## Fachada centralizada (Facade Pattern) para el ecosistema de monetización.
## Oculta la complejidad de Ads e IAP tras una API limpia y declarativa.

static var ads_service: AdsService
static var iap_service: IAPService

static func initialize() -> void:
	if OS.has_feature("mobile"):
		ads_service = AdMobAdapter.new()
		iap_service = GooglePlayIAPAdapter.new()
	else:
		ads_service = MockAdsService.new()
		iap_service = MockIAPService.new()

static func watch_ad_for_revive(on_revive: Callable) -> void:
	if not ads_service:
		initialize()

	if EventBus:
		EventBus.combat_log_appended.emit("[Monetización] Solicitando anuncio recompensado para reanimación...", "info")

	ads_service.show_rewarded_ad("revive_hero_ad", func():
		if EventBus:
			EventBus.combat_log_appended.emit("[Monetización] ¡Recompensa concedida! Héroe reanimado.", "heal")
		if on_revive.is_valid():
			on_revive.call()
	)

static func unlock_full_campaign(on_success: Callable) -> void:
	if not iap_service:
		initialize()

	iap_service.purchase_product("com.calabozos.full_campaign", func():
		if EventBus:
			EventBus.combat_log_appended.emit("[IAP] ¡Campaña completa desbloqueada! Gracias por apoyar el juego.", "heal")
		if on_success.is_valid():
			on_success.call()
	)

static func is_campaign_unlocked() -> bool:
	if not iap_service:
		initialize()
	return iap_service.is_product_purchased("com.calabozos.full_campaign")
