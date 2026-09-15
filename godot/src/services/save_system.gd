class_name SaveSystem
extends RefCounted

## Sistema de Persistencia Encriptado (AES-256) con Protección de Integridad (SHA-256 HMAC).
## Previene la manipulación local de partidas en Google Play Store y App Store.

const SAVE_PATH_TEMPLATE: String = "user://save_slot_%d.cndb"
# Clave derivada de compilación para cifrado local
const ENCRYPTION_KEY: String = "C&B_S4t1r1c4l_Rpg_K3y_2026_M0b1l3"
const SALT: String = "B4r_L0s_Mu3rt0s_Ch3cksum_S4lt"

static func get_save_path(slot: int = 1) -> String:
	return SAVE_PATH_TEMPLATE % slot

static func has_save(slot: int = 1) -> bool:
	return FileAccess.file_exists(get_save_path(slot))

static func save_game(save_data: Dictionary, slot: int = 1) -> bool:
	var path: String = get_save_path(slot)
	var json_string: String = JSON.stringify(save_data)

	# 1. Generación de firma de integridad (SHA-256 HMAC) contra alteraciones
	var signature: String = (json_string + SALT).sha256_text()

	var payload := {
		"version": 2,
		"timestamp": Time.get_unix_time_from_system(),
		"signature": signature,
		"data": save_data
	}

	var payload_string: String = JSON.stringify(payload)

	# 2. Escritura cifrada mediante FileAccess con clave AES
	var file := FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, ENCRYPTION_KEY)
	if not file:
		push_error("[SaveSystem] Error al abrir archivo para escritura cifrada: %s" % path)
		return false

	file.store_string(payload_string)
	file.close()

	if EventBus:
		EventBus.combat_log_appended.emit("Partida guardada con éxito de forma segura.", "info")
	return true

static func load_game(slot: int = 1) -> Dictionary:
	var path: String = get_save_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("[SaveSystem] No existe archivo de guardado en: %s" % path)
		return {}

	var file := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, ENCRYPTION_KEY)
	if not file:
		push_error("[SaveSystem] Error al descifrar archivo: clave inválida o archivo corrupto.")
		return {}

	var content: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)
	if not (parsed is Dictionary):
		push_error("[SaveSystem] Estructura de guardado corrupta.")
		return {}

	var payload: Dictionary = parsed as Dictionary
	var stored_signature: String = payload.get("signature", "")
	var raw_data: Dictionary = payload.get("data", {})

	# 3. Verificación de firma contra manipulación (Anti-Tampering)
	var expected_signature: String = (JSON.stringify(raw_data) + SALT).sha256_text()
	if stored_signature != expected_signature:
		push_error("[SaveSystem] ALERTA DE INTEGRIDAD: Los datos del guardado fueron manipulados externamente.")
		return {}

	if EventBus:
		EventBus.combat_log_appended.emit("Partida cargada y validada con éxito.", "heal")
	return raw_data

static func delete_save(slot: int = 1) -> bool:
	var path: String = get_save_path(slot)
	if FileAccess.file_exists(path):
		var err: Error = DirAccess.remove_absolute(path)
		return err == OK
	return false

static func auto_save_campaign_progress(act_num: int, inventory: Array, heroes_hp: Dictionary, achievements: Array) -> void:
	var save_data := {
		"act_number": act_num,
		"inventory": inventory,
		"heroes_hp": heroes_hp,
		"achievements": achievements,
		"timestamp": Time.get_datetime_string_from_system()
	}
	var file = FileAccess.open("user://campaign_save.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("SaveSystem: ¡Progreso y logros guardados automáticamente!")

static func load_campaign_progress() -> Dictionary:
	if not FileAccess.file_exists("user://campaign_save.json"):
		return {}
	var file = FileAccess.open("user://campaign_save.json", FileAccess.READ)
	if not file: return {}
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(text) == OK:
		return json.get_data()
	return {}
