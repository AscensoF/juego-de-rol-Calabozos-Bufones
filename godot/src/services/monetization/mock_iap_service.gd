class_name MockIAPService
extends IAPService

## Simulación de compras dentro de la aplicación para testing y pruebas unitarias.

var purchased_products: Dictionary = {}

func purchase_product(product_id: String, on_success: Callable, _on_fail: Callable = Callable()) -> void:
	print("[MockIAP] Compra simulada exitosa para producto: %s" % product_id)
	purchased_products[product_id] = true
	if on_success.is_valid():
		on_success.call()

func restore_purchases(on_complete: Callable) -> void:
	print("[MockIAP] Restauración de compras simulada completada.")
	if on_complete.is_valid():
		on_complete.call()

func is_product_purchased(product_id: String) -> bool:
	return purchased_products.get(product_id, false)
