class_name GooglePlayIAPAdapter
extends IAPService

## Adaptador de compras integrado con Google Play Billing API para Android.

var billing: Object = null
var pending_success: Callable
var pending_fail: Callable

func _init() -> void:
	if Engine.has_singleton("GodotGooglePlayBilling"):
		billing = Engine.get_singleton("GodotGooglePlayBilling")
		if billing.has_signal("purchase_consumed"):
			billing.connect("purchase_consumed", _on_purchase_consumed)
		if billing.has_signal("purchase_acknowledgement_successful"):
			billing.connect("purchase_acknowledgement_successful", _on_purchase_acknowledged)
		if billing.has_signal("purchases_updated"):
			billing.connect("purchases_updated", _on_purchases_updated)
		if billing.has_method("start_connection"):
			billing.start_connection()

func purchase_product(product_id: String, on_success: Callable, on_fail: Callable = Callable()) -> void:
	pending_success = on_success
	pending_fail = on_fail

	if billing and billing.has_method("purchase"):
		var response: Dictionary = billing.purchase(product_id)
		if response.get("status", 0) != 0:
			if on_fail.is_valid():
				on_fail.call()
	else:
		# Fallback mock si no se detecta la librería nativa
		if on_success.is_valid():
			on_success.call()

func restore_purchases(on_complete: Callable) -> void:
	if billing and billing.has_method("query_purchases"):
		billing.query_purchases("inapp")
	if on_complete.is_valid():
		on_complete.call()

func _on_purchases_updated(purchases: Array) -> void:
	for p in purchases:
		if p.get("purchase_state", 0) == 1: # COMPRADO
			if pending_success.is_valid():
				pending_success.call()

func _on_purchase_acknowledged(_token: String) -> void:
	pass

func _on_purchase_consumed(_token: String) -> void:
	pass
