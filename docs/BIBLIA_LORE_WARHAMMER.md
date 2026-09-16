# BIBLIA LORE — «Calabozos y Bufones» en el Viejo Mundo (no-oficial)
### Alineación total al universo Warhammer Fantasy + resolución de los dolores de la comunidad
### Panel de Dirección · 2026-09-16 · Fundamentado en foros 2024-2026 (ver §5 Fuentes)

> Tesis: el fan de Fantasy no odia el Viejo Mundo — odia lo que le han hecho con él:
> precios de 300 $, DLCs que bloquean facciones, el setting asesinado en End Times,
> ejércitos Legends abandonados, gachas de shards a 35 $ y partidas que exigen
> tardes enteras. C&B es la respuesta jugable a cada uno de esos dolores.

---

## 1. MATRIZ DOLOR → SOLUCIÓN (cada fila es una promesa de marketing verificable)

| # | Dolor real (voz de la comunidad) | Lo que Warhammer no pudo | Solución C&B (sistema que lo ejecuta) |
|---|---|---|---|
| D1 | *«$300 por Tomb Kings… $230 por 9 wolf goblins»* — tabletop prohibitivo, resin cara, Australia con +40 $ | Un Warhammer barato | **0 € en minis.** Juego completo premium único 4,99–9,99 € (`PRODUCT_BIBLE`). Todo el contenido jugable sin comprar plástico |
| D2 | *«Mitad del roster bloqueado tras DLC; Jugar Khorne/Nurgle/Cathay competitivo cuesta +20-30 €»* — paywall multiplayer TWW3 | Roster completo sin peaje | **Los 4 héroes + los 4 actos incluidos.** DLC solo bandas cosméticas (2,99 €). Nada que afecte al win-rate se vende |
| D3 | *«Shadows of Change: más precio, menos contenido»* — DLC devaluado | DLC que valga su precio | Cada banda DLC = 4 héroes + acto + mecánicas (pólvora, disformidad), nunca 1 lord suelto |
| D4 | *«200+ personajes muertos sin despedida; nada importaba, el ganador estaba decidido»* — End Times | Un final que importe | **Diseño anti-End Times:** el mundo NO se destruye; cada muerte es reversible (reanimar, plegarias) y cada pifia es contenido (kill-cam, disformidad). La derrota es divertida, nunca un retcon |
| D5 | *«Legends sin soporte + Renegade Patch = dos metas»* — fractura de reglas | Un solo juego para todos | **Una regla, un balance, updates indie rápidos.** Los 8 codex del juego existen en datos (`.tres`) con soporte real, no PDFs abandonados |
| D6 | *«$35 = 1/5 de los shards de UN personaje»* — gacha Tacticus | Progresión sin casino | **Cero shards, cero energía, cero autoplay.** Héroes por jugar actos; oro (`gold` en los 4 `.tres`) por jugar, no por pagar |
| D7 | *«Core tax: la infantería paga y no impacta; el monstruo lo hace todo»* — balance ToW | Tropas que importan | 4 héroes, 0 core tax: todos actúan cada ronda, todos deciden. Jefes con fases (`isFurious`, Fase 3) pero matables por táctica, no por billetera |
| D8 | *«No storyline, grind wall, autoplay»* — móvil oficial vacío | Móvil con alma | 4 actos narrados con diálogos satíricos + typewriter, partidas de 3–5 min, autosave por turno (Fase 3): cierras la app y reanudas en el milisegundo |
| D9 | *«Ayuda: ¿qué DLC compro para jugar X?»* — confusión TWW3 | Comprar sin manual | Un botón: campaña completa. Sin ediciones, sin packs cruzados |

---

## 2. CODEX POR CODEX — alineación del bestiario (estado + hoja de ruta)

| Codex oficial | Estado en C&B | Dónde vive (datos) | Dolor que resuelve |
|---|---|---|---|
| Skaven | ✅ Jugable Acto 1 | `goblin_burocrata.tres`, `esqueleto_desmotivado.tres` (reskins Alcantarillas) | D1: ejército de 200 $ gratis |
| Nurgle / Hombres Bestia | ✅ Jugable Acto 2 | `limo_toxico.tres`, `mimeto_archivo.tres`, boss `demonio_auditoria.tres` (Balthazar) | D5: con reglas vivas, no Legends |
| Pielesverdes (O&G) | ✅ Jugable Acto 3 | `goblin_nocturno.tres`, `troll_piedra.tres`, boss `caudillo_orco_negro.tres` | D7: el troll se mata por foco, no por lista |
| Guerreros del Caos | ✅ Jugable Acto 4 | `guerrero_caos.tres`, boss `paladin_elegido_caos.tres` (Malakor) | D4: el Caos pierde si juegas bien |
| Imperio | ✅ Héroes (no tropa) | `kallina.tres` (cazadora), `valtieri.tres` (Aqshy), `beryl_sigmar.tres` (Sigmar) | D2: el Imperio se juega desde el minuto 1 |
| Enanos | ✅ Aliado + DLC | `gotreksson.tres` (Matador); Karak Kadrin es el Acto 3 | D1/D5 |
| Reyes Funerarios | 🔜 Banda DLC 1 | — | D1 directo: «los 300 $ por 2,99 €» (slogan) |
| Condes Vampiro | 🔜 Banda DLC 2 | — | D3: banda completa, no lord suelto |
| Elfos (Altos/Oscuros/Silvanos) | 🔜 Banda DLC 3 | — | D5: sin PDFs abandonados |
| Hombres Lagarto / Ogros / Bretonnia / Mercenarios | 🔜 Temporadas (bucle T) | — | D8: contenido infinito sin gacha |

Regla de sátira (Director Creativo): cada codex entra **caricaturizado desde su propio
dolor** — los Skaven son burócratas del alcantarillado, Balthazar es un auditor de
Hacienda, el Rey Orco hace karaoke. La mofa es del sistema, nunca del jugador.

## 3. ROSTER — los 4 como respuesta a arquetipos que GW dejó cojos

- **Gotreksson (Matador):** el héroe que *quiere morir* y no puede — inversión satírica
  del grimdark donde nadie importa (D4). Mecánica Voto (`combat_rules.gd:106-111`).
- **Kallina (Cazadora):** la profesional competente en un mundo de chiste — el jugador
  se identifica con ella mientras todo arde. DPS honesto, sin RNG cruel.
- **Valtieri (Aqshy):** la magia *peligrosa de verdad* que ToW edulcoró con FAQs:
  aquí la Disfunción existe y es espectáculo (D8), no footnote.
- **Beryl (Sigmar):** la fe que *funciona* — curas reales en un setting donde los
  dioses llevan 10 años decepcionando (D4).

## 4. ESTRATEGIA IP (lectura obligada, no es asesoría legal)

Riesgo declarado: nombres como Skaven, Sigmar, Aqshy o Gotrek son IP de Games Workshop;
el juego, hoy, los usa literalmente. Vías, de menor a mayor riesgo:
- **A. Homenaje con distancia (recomendada):** renombrar a parodia funcional
  («Rata de Clan», «Santa Sigmarita», «Viento Ámbar») manteniendo mecánicas y
  estética. El jugador reconoce; el abogado no denuncia. Coste: 1 sprint de renombrado
  en `.tres` (data-driven: es buscar/reemplazar, no código).
- **B. Parodia explícita:** escudo parcial y frágil; GW litiga igual aunque pierda.
- **C. Licencia oficial:** inviable a esta escala.
Decisión propuesta: lanzar en A, guardar B como marketing («el Warhammer que GW no se
atreve»). La arquitectura data-driven hace que A sea barato: los IDs internos
(`enemy_goblin_burocrata`) ya son nuestros.

## 5. FUENTES (dolores verificados, foros 2024-2026)

Precios ToW/resin/Australia (r/WarhammerOldWorld, r/Warhammer) · Core tax infantería ·
Pérdida de control GW: comps, FAQs y Legends/Renegade Patch (Bell of Lost Souls,
abr–jul 2025; r/theoldworld 2026) · DLC TWW3: Shadows of Change, paywall multiplayer,
confusión de packs (r/totalwar, r/totalwarhammer, PC Gamer 2023) · End Times como
asesinato del setting (r/WarhammerFantasy, r/totalwar) · Tacticus: shards, grind wall,
falta de historia (r/WH40KTacticus, App Store reviews).

*Fin · Panel de Dirección · 2026-09-16 — pendiente: commit a propuesta del usuario.*
