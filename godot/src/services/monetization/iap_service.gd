class_name IAPService
extends RefCounted

## Interfaz base (Adapter Contract) para Compras Integradas (Google Play Billing / Apple StoreKit).

func purchase_product(_product_id: String, _on_success: Callable, _on_fail: Callable = Callable()) -> void:
	pass

func restore_purchases(_on_complete: Callable) -> void:
	pass

func is_product_purchased(_product_id: String) -> bool:
	return false
