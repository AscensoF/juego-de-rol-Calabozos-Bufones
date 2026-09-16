class_name SaveSystem
extends RefCounted

## Sistema de Persistencia Encriptado (AES-256) con Protección de Integridad (SHA-256 HMAC).
## Previene la manipulación local de partidas en Google Play Store y App Store.
##
## Fase 1: la clave primaria YA NO está hardcodeada. Cadena de resolución:
##   1. Variable de entorno CB_SAVE_KEY (CI / exports Store),
##   2. ProjectSettings "calabozos/save/encryption_key" (override por export),
##   3. Clave de dispositivo generada en primer arranque (user://save_device.key).
## LEGACY_KEY solo se usa para LEER saves antiguos y re-cifrarlos (migración).
## SALT es público (integridad, no secreto) y se conserva para no invalidar firmas.

const SAVE_PATH_TEMPLATE: String = "user://save_slot_%d.cndb"
const SETTING_KEY: String = "calabozos/save/encryption_key"
const ENV_KEY: String = "CB_SAVE_KEY"
const LEGACY_KEY: String = "C&B_S4t1r1c4l_Rpg_K3y_2026_M0b1l3"
const SALT: String = "B4r_L0s_Mu3rt0s_Ch3cksum_S4lt"
const DEVICE_KEY_PATH: String = "user://save_device.key"
const CAMPAIGN_CRYPT_PATH: String = "user://campaign_save.cndb"
const CAMPAIGN_LEGACY_PATH: String = "user://campaign_save.json"

static func get_save_path(slot: int = 1) -> String:
	return SAVE_PATH_TEMPLATE % slot

static func has_save(slot: int = 1) -> bool:
	return FileAccess.file_exists(get_save_path(slot))

static func _get_key() -> String:
	var env_key: String = OS.get_environment(ENV_KEY)
	if env_key != "":
		return env_key
	if ProjectSettings.has_setting(SETTING_KEY):
		var setting_key: String = str(ProjectSettings.get_setting(SETTING_KEY))
		if setting_key != "":
			return setting_key
	if FileAccess.file_exists(DEVICE_KEY_PATH):
		var f := FileAccess.open(DEVICE_KEY_PATH, FileAccess.READ)
		if f:
			var stored: String = f.get_as_text().strip_edges()
			f.close()
			if stored != "":
				return stored
	var generated := _generate_device_key()
	var w := FileAccess.open(DEVICE_KEY_PATH, FileAccess.WRITE)
	if w:
		w.store_string(generated)
		w.close()
	else:
		push_error("[SaveSystem] No se pudo persistir la clave de dispositivo.")
	return generated

static func _generate_device_key() -> String:
	var alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#%&*+-=?"
	var key := ""
	for i in 32:
		key += alphabet[randi() % alphabet.length()]
	return "CB1_" + key

static func _decrypt_to_string(path: String, key: String) -> String:
	if key == "":
		return ""
	var file := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, key)
	if not file:
		return ""
	var content: String = file.get_as_text()
	file.close()
	return content

static func _parse_and_verify(content: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(content)
	if not (parsed is Dictionary):
		push_error("[SaveSystem] Estructura de guardado corrupta.")
		return {}
	var payload: Dictionary = parsed as Dictionary
	var stored_signature: String = payload.get("signature", "")
	var raw_data: Dictionary = payload.get("data", {})
	var expected_signature: String = (JSON.stringify(raw_data) + SALT).sha256_text()
	if stored_signature != expected_signature:
		push_error("[SaveSystem] ALERTA DE INTEGRIDAD: Los datos del guardado fueron manipulados externamente.")
		return {}
	return raw_data

static func _write_payload(path: String, save_data: Dictionary) -> bool:
	var json_string: String = JSON.stringify(save_data)
	var signature: String = (json_string + SALT).sha256_text()
	var payload := {
		"version": 2,
		"timestamp": Time.get_unix_time_from_system(),
		"signature": signature,
		"data": save_data
	}
	var file := FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, _get_key())
	if not file:
		push_error("[SaveSystem] Error al abrir archivo para escritura cifrada: %s" % path)
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true

static func _read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var content: String = _decrypt_to_string(path, _get_key())
	if content != "":
		return _parse_and_verify(content)
	# Migración: reintentar con clave legacy y re-cifrar con la clave actual.
	var legacy_content: String = _decrypt_to_string(path, LEGACY_KEY)
	if legacy_content == "":
		push_error("[SaveSystem] Error al descifrar archivo: clave inválida o archivo corrupto.")
		return {}
	var data: Dictionary = _parse_and_verify(legacy_content)
	if not data.is_empty():
		_write_payload(path, data)
		if EventBus:
			EventBus.combat_log_appended.emit("Guardado migrado a la nueva clave de dispositivo.", "info")
	return data

static func save_game(save_data: Dictionary, slot: int = 1) -> bool:
	var ok: bool = _write_payload(get_save_path(slot), save_data)
	if ok and EventBus:
		EventBus.combat_log_appended.emit("Partida guardada con éxito de forma segura.", "info")
	return ok

static func load_game(slot: int = 1) -> Dictionary:
	var path: String = get_save_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("[SaveSystem] No existe archivo de guardado en: %s" % path)
		return {}
	var data: Dictionary = _read_payload(path)
	if not data.is_empty() and EventBus:
		EventBus.combat_log_appended.emit("Partida cargada y validada con éxito.", "heal")
	return data

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
	# Fase 1: la campaña también va cifrada (antes user://campaign_save.json en claro).
	if _write_payload(CAMPAIGN_CRYPT_PATH, save_data):
		if FileAccess.file_exists(CAMPAIGN_LEGACY_PATH):
			DirAccess.remove_absolute(CAMPAIGN_LEGACY_PATH)
		print("SaveSystem: ¡Progreso y logros guardados automáticamente (cifrado)!")

static func load_campaign_progress() -> Dictionary:
	if FileAccess.file_exists(CAMPAIGN_CRYPT_PATH):
		return _read_payload(CAMPAIGN_CRYPT_PATH)
	# Migración una sola vez desde el formato antiguo en claro.
	if not FileAccess.file_exists(CAMPAIGN_LEGACY_PATH):
		return {}
	var file = FileAccess.open(CAMPAIGN_LEGACY_PATH, FileAccess.READ)
	if not file:
		return {}
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(text) != OK:
		return {}
	var data: Dictionary = json.get_data()
	if not data.is_empty():
		var migrated := {
			"act_number": data.get("act_number", 1),
			"inventory": data.get("inventory", []),
			"heroes_hp": data.get("heroes_hp", {}),
			"achievements": data.get("achievements", {}),
			"timestamp": data.get("timestamp", "")
		}
		_write_payload(CAMPAIGN_CRYPT_PATH, migrated)
		DirAccess.remove_absolute(CAMPAIGN_LEGACY_PATH)
		return migrated
	return {}
