# LEGACY — Prototipo web congelado (Fase 0)

Fecha: 2026-09-16. Decisión institucional aprobada: **canon único = `godot/`**.

* `index.html / game.js / style.css` movidos aquí desde raíz. No mantener, no fixear.
  Solo referencia histórica. La web futura será export WASM desde `godot/`
  (`export_presets.cfg` preset Web), no este JS.
* Assets sueltos en raíz (`*.png`, `*.ogg`, `Manual...html`) quedan como legacy
  hasta Fase 1. No usar en builds Store.

## Freeze héroes — NO borrar en Fase 0

Divergencia detectada, bloqueante para Fase 1:

* `godot/src/core/game_manager.gd:149-159` carga roster Warhammer
  (PRODUCT_BIBLE canon): `gotreksson.tres, kallina.tres, valtieri.tres, beryl_sigmar.tres`
* `godot/src/state_machine/states/main_menu_state.gd:16-21` carga roster satírico:
  `throg.tres, elowen.tres, grimble.tres, beryl.tres`

Ambos paths están vivos. Por eso **no se elimina ningún `.tres` en Fase 0**.
Fase 1 debe unificar en un solo `ActLoader` + roster canon Warhammer
completando sus 3 habilidades (hoy solo tienen 1, el roster satírico tiene 3).

Retratos compartidos (`throg.png, elowen.png, grimble.png, beryl.png` en
`dialogue_box.gd:124-127, combat_hud_controller.gd:332-335, grid_renderer.gd:144-147`)
siguen válidos para ambos rosters.
