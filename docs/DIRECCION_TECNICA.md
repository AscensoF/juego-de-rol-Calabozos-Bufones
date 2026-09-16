# DIRECCIÓN TÉCNICA — «Calabozos y Bufones»
### Panel de Ingeniería de Juegos · Especificación ejecutiva v1.0 · 2026-09-16
### Proyecto: RPG táctico por turnos D20, sátira medieval · Godot 4.x · iOS / Android / Web / PC

> **Nota de contingencia:** el repositorio fuente es accesible y ha sido auditado
> (ramas `main` @ `89b3a59`, Fases 0–2 cerradas, Fase 3 en validación). Este documento
> se fundamenta en la base de código real — rutas y líneas citadas — no en un
> prototipo equivalente. El protocolo de contingencia queda registrado pero inactivo.

**Composición del panel:** Arquitectura de Motores · Sistemas y Economía ·
Arte Técnico y UX · Dirección Creativa y Narrativa.

---

## MÓDULO 1 — ARQUITECTURA TÉCNICA Y ESTRATEGIA MULTIPLATAFORMA

### 1.1 Comparativa Godot 4.x vs Unity 6 (decisión: Godot 4.x, ratificada)

| Eje | Godot 4.x (GDScript, `gl_compatibility`) | Unity 6 (URP) | Veredicto C&B |
|---|---|---|---|
| Huella APK/AAB base | ~15–25 MB (plantilla ARM64 + PCK) | ~25–40 MB (managed + IL2CPP) | Godot: −40 % descarga, crítico en mercados emergentes |
| Carga en frío gama media-baja (p. ej. Snapdragon 680, 4 GB) | Escena 24×18 + 4 OGG: **1,5–2,5 s** estimados | Misma escena URP 2D: 2,5–4 s (warmup shaders) | Godot, y fijar `gl_compatibility` ya aplicado en `project.godot:43` |
| AOT iOS | GDScript interpretado (sin AOT); GDExtension C++ sí compila AOT vía Xcode | IL2CPP = AOT completo, mejor pico de CPU | Unity gana en CPU bruta; irrelevante aquí: la lógica (A* 24×18, D20) cabe en <1 ms/frame en ambos |
| Batería / térmica | Draw inmediato 2D + throttle 16 Hz (Fase 2) ≈ 60 fps sostenidos sin throttling observado en simulación | URP 2D Renderer + batching automático, mayor coste fijo | Godot con presupuestos §1.4; vigilar sustained-performance en iPhone SE |
| Coste / pipeline | 0 €, exportadores integrados, CI con binario headless | Licencia + módulos de plataforma | Godot: equipo indie, 3 targets en paralelo |
| Riesgo | WASM single-thread (elegido Fase 2) −10/−20 % vs threads | WebGL maduro + threads | Aceptado: compatibilidad total (GitHub Pages) > pico |

**Conclusión del Director de Arquitectura:** mantener Godot 4.7 (`project.godot:21`, `features 4.7`).
Ruta de escape solo si el *vertical slice* incumple §1.4 en 2 sprints: migrar
presentación a Unity conservando el dominio (las reglas son portables: D20 + A* + tablas).

### 1.2 Patrón estructural: MVP asistido por eventos (no ECS)

Estado real: `src/core/event_bus.gd:1-39` (39 señales), `game_manager.gd` (orquestador),
`ActLoader` (Fase 1, construcción data-driven), `CombatRules`/`TacticalGrid` (dominio puro
`RefCounted`), comandos (`src/combat/commands/*`: attack/ability/defend/item/move/revive).
Es un **Modelo-Vista-Presentador con EventBus**, correcto para un TRPG por turnos
(<50 entidades, lógica determinista, UI pesada). **ECS puro se rechaza**: overhead de
arqueotipos/sistemas para un conteo de entidades que cabe en arrays, y pérdida de la
legibilidad que hoy permite validar balance con tests headless.

Endurecimientos normativos (Fase 3+):
- Prohibir `get_node_or_null("MainGame/StateMachine")` (usado en
  `combat_hud_controller.gd:320,457`): resolver vía `game_manager` inyectado.
- Toda mutación de combate pasa por `CombatCommand.execute()`; prohibido mutar
  `unit["hp"]` fuera de comandos y de `_check_cell_interaction`
  (`exploration_state.gd:137`, único caso ambiental permitido: trampas/altar).
- `TacticalGrid` y `CombatRules` no referencian nodos ni `EventBus`: verificado.

### 1.3 Capa agnóstica de entrada (táctil / mando / teclado-ratón)

Estado real: `emulate_touch_from_mouse=true`, drag un dedo + pinch-to-zoom
(`tactical_camera.gd`, Fase 2), click izquierdo → `cell_clicked`
(`grid_renderer.gd:114-118`). Carencias: sin gamepad, sin atajos de teclado,
rueda solo en desktop.

Norma: crear `src/core/input_router.gd` que publique intenciones
(`tap_cell`, `drag_map`, `pinch`, `confirm`, `cancel`, `end_turn`) y tres adaptadores
(`touch_adapter`, `gamepad_adapter` con foco por celda + cursor, `desktop_adapter`
con atajos: `Espacio`=fin de turno, `Esc`=cancelar, `Tab`=siguiente héroe).
Los estados (`Exploration/Combat`) consumen solo intenciones. Criterio: conmutar
de táctil a mando sin tocar `combat_state.gd` ni `exploration_state.gd`.

### 1.4 Presupuestos cuantitativos por plataforma

| Recurso | iPhone SE/11 (ref. iOS) | Android gama media (SD680/4 GB) | Web WASM (desktop) | PC/Steam |
|---|---|---|---|---|
| RAM total | ≤ 250 MB | ≤ 200 MB | ≤ 300 MB | ≤ 500 MB |
| VRAM texturas | ≤ 80 MB (ASTC) | ≤ 60 MB (ETC2) | ≤ 120 MB (S3TC) | ≤ 256 MB |
| Polígonos/primitivas 2D por cuadro | ≤ 3.000 | ≤ 2.500 | ≤ 5.000 | ≤ 10.000 |
| Llamadas de dibujado | ≤ 40 | ≤ 35 | ≤ 60 | ≤ 100 |
| Frame p95 | 16,6 ms (60 fps) | 16,6 ms (60 fps) | 16,6 ms | 8,3 ms (120 opcional) |
| Carga en frío | ≤ 3 s | ≤ 4 s | ≤ 5 s (WASM) | ≤ 3 s |
| Batería | −0 % throttling en sesión 20 min | idem, `gl_compatibility` obligatorio | N/A | N/A |

Deuda conocida: `grid_renderer._draw` emite ~432 celdas × hasta 3 rects + tokens +
niebla ≈ 1.500 primitivas/cuadro (dentro de techo, pero sin margen). Migración
normativa a `TileMapLayer` para suelo/muros/niebla antes de la beta externa.

### 1.5 Persistencia unificada (local + nube)

Estado real: `save_system.gd` — AES-256 (`open_encrypted_with_pass`) + firma
SHA-256, clave por cadena ENV → ProjectSettings → clave de dispositivo,
migración legacy, campaign cifrado (Fases 1–2). Formato JSON versionado (`version: 2`).
Integración nube (norma Fase 4): envolver en `CloudSaveFacade` con backend por
plataforma — iCloud (ubiquitous container vía plugin iOS/GDExtension) y
Play Games Services Snapshots (plugin Android) — con resolución de conflictos
*last-writer-wins por turno* (cada payload lleva `timestamp` + `turn_id` a añadir).
Binario puro (MessagePack) solo si el JSON supera 100 KB/slot; hoy un slot ≈ 5–15 KB:
JSON es correcto.

---

## MÓDULO 2 — DISEÑO DE SISTEMAS Y BALANCE MATEMÁTICO

### 2.1 Bucles interconectados (formalización)

**Bucle primario P (minuto a minuto):** Explorar (niebla radio 6,
`exploration_state.gd:12`) → evento de celda (trampa 1d6 / cofre / altar cura
1d8+5 a todo el grupo / librería +15 XP) → contacto (enemigo a distancia ≤ 2,
`exploration_state.gd:192`) → combate (iniciativa 1d20+mod, turnos con mover+actuar,
IA enemiga al héroe más cercano por A*) → botín (XP = Σ `xp_reward`, drops) →
reposición (autosave por turno, Fase 3). Tiempo objetivo por encuentro: 3–5 min
(océano azul declarado en PRODUCT_BIBLE).

**Bucle secundario S (entre encuentros):** hoy existe en forma mínima — inventario
de grupo (`party_inventory`, pociones/bombas/pergaminos), puntos de atributo por
nivel (`starting_attribute_points`, `levelUp` web / pendiente port Godot) y altares
de curación. **Carencia directiva:** no hay campamento. Norma: «Campamento de la
Corte» entre actos — gastar oro (`gold` ya existe en los 4 `.tres` Warhammer) en
herrería (+1 daño arma), capilla (curación total) y juglaría (re-rolls de iniciativa).
Economía de favores: favores de facción por acto que desbloquean consumibles.

**Bucle terciario T (meta):** inexistente. Norma post-lanzamiento: herencias bufas
(modificadores permanentes aleatorios por campaña perdida) y contratos de patrocinio
feudal (temporadas con restricciones mutuas). No entra en P0.

### 2.2 Ecuaciones operativas (notación formal)

**E1 — Coste de XP por nivel** (tabla del prototipo legacy,
`legacy/web/game.js:XP_TABLE = [0,100,300,600,1000,1500,2200,3000,4000,5200,6500]`):
> `XP(n) = 50·n·(n−1) + 100·(n−1)` para n ≥ 2, con tope n=10.
> Comprobación: n=2 → 100 ✓; n=3 → 300 ✓; n=5 → 1000 ✓. Curva cuadrática suave:
> ~4 encuentros/acto para subir de nivel en actos 1–2, ~6 en actos 3–4.
> ⚠️ **Brecha Godot (norma F4):** en el canon el XP hoy es decorativo — se calcula
> (`combat_state.gd:326-330`) y se anuncia, pero `unit_defeated` no tiene ningún
> suscriptor y nadie reparte XP ni sube de nivel. Los campos ya existen
> (`HeroData.level/current_xp/xp_to_next_level`, Fase 1): falta el sistema que los
> mueva. Hasta entonces, E1 es especificación, no comportamiento.

**E2 — Resolución de ataque y mitigación de armadura** (`combat_rules.gd:81-130`):
> `tirada = 1d20; total = tirada + mod_atq; impacto ⟺ (tirada = 20) ∨ (tirada ≠ 1 ∧ total ≥ CA_ef)`
> `CA_ef = CA_base + 2·cobertura + 4·defendiendo + Σ buffs`
> `daño = máx(1, Σ(dados) + bono + mod_atq) × (2 si crítico)`
> La mitigación es **por umbral, no porcentual**: cada +1 CA ≈ −5 % de probabilidad
> de impacto (lineal), con pifia/crítico fijos del 5 %. Cobertura diagonal
> (`has_diagonal_cover`, `tactical_grid.gd:41`) y bendición/maldición ±1 completan el modelo.

**E3 — Botín ponderado por riesgo (Danger Modifier)** (norma; hoy el cofre es
uniforme): `P(item_i) = w_i·(1 + D·r_i) / Σ_j w_j·(1 + D·r_j)`, donde `D` = nivel de
peligro del acto (1–4), `w_i` = peso base por rareza (común 60 / raro 28 / épico 12),
`r_i` = apetito de riesgo del objeto (0 para consumibles, 1 para artefactos malditos).
A D=4, un artefacto épico pasa de ~12 % a ~25 %.

### 2.3 Matriz de arquetipos (roster canon Warhammer, verificado en datos)

| Héroe | PV | CA | Vel | Recurso | Rol / curva | Kit 3 habilidades (Fase 3) |
|---|---|---|---|---|---|---|
| Gotreksson, Matador (GUERRERO) | 18 | 12 | 4 | Furia 4 | Tanque que escala inverso a PV (Voto: +3 daño <50 %, +6 <25 %, `combat_rules.gd:106-111`) | Tajo Gromril 2d6+3 · Furia 2d8+2 · Desafío AoE |
| Kallina, Cazadora (PÍCARO) | 12 | 14 | 5 | Pólvora 3 | DPS a distancia, costes altos | Disparo 1d10+4 · Virote 1d8+3 (alc. 6) · Bomba AoE r2 |
| Valtieri, Aqshy (MAGO) | 10 | 11 | 4 | Vientos 6 | Artillería AoE con riesgo | Llama 2d8+2 r2 (pifia 1) · Dardo 2d6+2 seguro · Vientos 3d6 r3 (pifia 1–2) |
| Beryl, Sigmar (CLÉRIGO) | 14 | 15 | 4 | Fervor 5 | Soporte/frontline | Plegaria cura grupal 2d6+4 · Martillo 1d8+2 · Escudo cura+DEFENDING |

Curvas: héroes lineales por equipo (herrería S) + saltos en nivel 5 (definitivas,
patrón ya usado en el prototipo web); enemigos por acto con `base_hp` 9–22
(tropa) y 28–80 (jefes), verificados `jefe > tropa` en suite Fase 3.

---

## MÓDULO 3 — ECONOMÍA, OBJETOS Y GENERACIÓN DE ENCUENTROS

### 3.1 Taxonomía de inventario (norma formal)

Todo objeto: `{id único, nombre, rareza ∈ {común, raro, épico}, tipo ∈
{consumible, equipo, conjuro}, modificadores numéricos, maldición teatral
(opcional, con coste cómico)}`. Clases de datos ya existentes: `ItemData`
(`range_distance, area_radius, heal_amount`, `item_data.gd:15-17`) e
`ItemDatabase` web. Regla de economía: ningún objeto comprable supera el 15 % del
DPS de una habilidad de coste equivalente (evita pay-to-win y power-creep de tienda).

Seis objetos emblemáticos (4 existentes + 2 directivos):
1. **Poción de Curación** (común, +10 PV): el pan del bufo. Inmediata, sin decides.
2. **Piedra de Afilar** (común, +2 daño siguiente ataque): riesgo-recompensa de tempo.
3. **Bomba de Humo** (raro, teletransporte táctico radio 4): el botón de «¡uy!».
4. **Pergamino de Bola de Fuego** (raro, 2d6 AoE r2, cualquier clase): caos democrático.
5. **Contrato de Patrocinio Feudal** (épico, propuesto): oro por encuentro a cambio de
   una restricción teatral (p. ej. «prohibido curarse en voz alta»: −1 a curas si el
   héroe actuó el turno anterior). Motor del bucle T.
6. **Espejo del Narrador** (épico, maldito): duplica el próximo botín pero invoca una
   «Cláusula Abusiva» (mecánica hoy solo viva en `legacy/web/game.js`; portarla a
   Godot es prerrequisito de este objeto, backlog F5).

### 3.2 Generación de mazmorras: BSP vs salas prefabricadas conexas

Estado real: salas aleatorias + pasillos en L (`rooms/connectRooms`, prototipo) y
tableros fijos por acto en Godot (`BOARD_PRESETS`, `act_loader.gd`). Comparativa:
BSP garantiza partición completa y control de densidad, pero produce pasillos largos
ilegibles en 6″ y encuentros a >10 casillas (fuera del ritmo 3–5 min). **Directriz:
salas prefabricadas conexas** (plantillas 4×3 a 8×5 de factura manual con puntos de
spawn/interés etiquetados) + conector corto + validación de navegabilidad por
`find_path` (toda sala con interés debe ser alcanzable desde el spawn; si no, se
descarta la semilla). Legibilidad móvil primero: máximo 2 salas visibles por pantalla
a zoom 2×, puertas siempre en borde visible, trampas a ≥2 casillas del spawn.

### 3.3 IA de adversarios (estados jerárquicos + mofa)

Estado real: `CombatState._execute_enemy_ai_turn` (héroe más cercano → A* →
golpe) + 9 habilidades especiales absurdas (`ENEMY_SPECIAL_ABILITIES` en legacy;
`special_ability_id` en `EnemyData`). Arquitectura directiva: **máquina jerárquica
de 3 niveles** — Estratega (elige foco: más débil / más ruidoso / el que se burló),
Táctico (reposicionamiento con cobertura, `has_diagonal_cover`), Ejecutante
(golpe o especial con cooldown). Mecánica de **Mofa**: burlarse (nueva acción de
héroe, coste 0, 1/combate) marca al héroe como `taunted-target`; ciertos enemigos
(cultistas, orcos) obtienen +2 ataque contra él pero −2 CA (furia ciega) —
riesgo-recompensa satírico puro y contenido clipeable. Jefes con fases
(plantilla: Rey Orco `isFurious` <50 % PV ya existe; generalizar a `phase_2 at 50 %`,
`phase_3 at 25 %` con cambio de patrón + banner).

---

## MÓDULO 4 — ARTE TÉCNICO, UX RESPONSIVA Y JUICE

### 4.1 Identidad visual e iluminación (decisión)

Estado real: dibujado procedural grimdark (piedra/antorchas/niebla con fundido
0,6 s, `grid_renderer.gd:163-306`) + retratos PNG 1:1. Comparativa: **pixel art de
alta densidad + normales dinámicas** gana para C&B — las antorchas ya son el centro
estético (halo 0.09 alfa/tick), los mapas de normales dan volumen sin huesos ni
rigging, y el atlas cabe en el presupuesto VRAM §1.4. La esqueletal vectorial se
descarta: duplica producción de animación para 13 retratos (4 héroes + 9 enemigos) y rompe la textura
«miniatura de mesa» (`tile_size 48`, `grid_renderer.gd:4`). Contraste diurno:
modo «sol» que sube `COLOR_FLOOR` +0,15 luminancia y baja alfa de niebla a 0,85
(conmutable en ajustes; norma de accesibilidad).

### 4.2 UI responsiva (estado + norma)

Estado real (Fase 2): viewport 1280×720 `canvas_items/expand`, `_apply_safe_area()`
(notch/isla dinámica/home indicator; desktop inalterado), botones ≥42–48 px,
Action Bar inferior + Party Bar lateral (patrón CRPG validado). Matriz de aspectos:
20:9 (barras laterales absorben el exceso), 16:9 (base), 21:9 (extensión lateral,
prohibido estirar: `expand`, nunca `stretch` deformante). Regla 48×48 dp mínimo
universal, foco visible para mando, tamaño de fuente mínimo 11 sp (log) / 13 sp
(acciones). Deuda: migrar suelo/muros/niebla a `TileMapLayer` (§1.4).

### 4.3 Juice parametrizado (game feel)

Existente y medido: sacudida de cámara en crítico 12 / golpe 5 con decaimiento 12/s
(`tactical_camera.gd:20-28`); embestida de ataque 0,12 s salida + 0,18 s retorno
(`grid_renderer.gd:354-363`); textos flotantes 1,2 s a −45 px/s; fundido de niebla
0,6 s; banner de turno 0,15+0,6+0,2 s. **Añadir (norma): hit-stop 70 ms en crítico
y 40 ms en golpe (congelar `Engine.time_scale=0,05`), flash de daño 0,35 s ya
existente, sonido procedural cacheado por tipo (Fase 2), vibración háptica
50 ms en crítico móvil.** Prohibido juice que bloquee input >150 ms fuera del
hit-stop: el ritmo 3–5 min es sagrado.

---

## MÓDULO 5 — PLAN DE PRODUCCIÓN, OPTIMIZACIÓN Y HOJA DE RUTA

### 5.1 Fases (estado real → norma)

| Fase | Alcance | Estado |
|---|---|---|
| F0 Gobernanza | Canon Godot, `legacy/web/`, `.gitignore` de binarios | ✅ `81e75eb` |
| F1 Núcleo data-driven | `ActLoader`, A* nativo, `SaveSystem` sin secreto, roster único | ✅ `3aa1953` |
| F2 Readiness móvil | Presets Web/iOS/Android, SafeArea, 48 px, pinch, SFX cache, retratos | ✅ `89b3a59` |
| F3 P0 jugable | Roster 4×3, canonización de habilidades, autosave por turno | 🟡 En validación (suite `FASE3_ALL_GREEN`, pendiente commit) |
| F4 Vertical slice | Acto 1 completo jugable 3–5 min + Campamento de la Corte (§2.1) | Siguiente |
| F5 Contenido | Actos 2–4, Modo DJ flotante, Mofa (§3.3), `TileMapLayer` | — |
| F6 Optimización/QA | Presupuestos §1.4, plantillas de export en CI, TestFlight interno | — |
| F7 Certificación | Beta externa, App Store / Play / Steam | — |

### 5.2 QA: criterios numéricos de aceptación

- Crashes < 0,1 % sesiones (reporte por plataforma; hoy: 0 crashes en runs headless).
- 60 fps sostenidos p95 en iPhone SE y Snapdragon 680 (20 min sin throttling).
- Carga en frío ≤ §1.4; draws ≤ §1.4 (medir con Monitor tras migrar a `TileMapLayer`).
- Reglas: suites headless en verde (F1: 26/26, F2: 11/11, F3: ~50) + 0 errores en `--import`.
- Contenido: todo `ability.id` con cobertura de ejecución; todo enemigo con `portrait`;
  todo acto con `jefe > tropa` (automatizado en suite F3).

### 5.3 Riesgos y mitigaciones

Bifurcación web/Godot (cerrado F0) · secreto en repo (cerrado F1) · presets sin firma
(abierto: requiere cuentas, fuera del P0) · cobertura de tests solo datos — sin GUT:
los comandos con `EventBus` no compilan en modo `--script` (hallazgo F2); mitigación:
tests de datos + `--import` + runs, y GUT en F4 para escenas con doubles del bus.

---

## CONCLUSIONES Y RECOMENDACIONES OPERATIVAS

1. **No migrar de motor.** Godot 4.7 cubre los 3 targets dentro de presupuesto; la
   deuda real es de contenido y QA, no de silicio.
2. **El combate ya es data-driven de verdad** (F1–F3): balancear es editar `.tres`,
   no código. Protegerlo con la suite F3 en CI desde F4.
3. **El cuello P0 es el Campamento + vertical slice del Acto 1**, no más sistemas.
4. **Mofa y Modo DJ** son el diferenciador viral frente a ports pesados y gachas:
   priorizarlos sobre el cuarto acto.
5. **TestFlight solo tras F4**: pagar y firmar antes sería certificar un juego sin slice.

*Fin del documento · Panel de Dirección Técnica · 2026-09-16*


