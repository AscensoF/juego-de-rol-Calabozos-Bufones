# 📖 BIBLIA DE PRODUCTO & ARQUITECTURA ESTRATÉGICA (PRODUCT BIBLE)
## PROYECTO: "WARHAMMER FANTASY: TACTICAL OLD WORLD" (C&B EVOLUTION)
**Target:** Apple App Store (iOS), Google Play Store (Android) & Steam (PC/Mac)  
**Motor:** Godot Engine 4.x (Mobile-First Architecture)

---

## 🎯 1. VISIÓN DE PRODUCTO & OPORTUNIDAD DISRUPTIVA

### El Dolor del Mercado (*Market Pain Point*)
1. **Gachas Predatorios F2P:** Llenos de pay-to-win, autoplay y microtransacciones abusivas. El jugador core los rechaza.
2. **Ports Pesados de PC:** Interfaces minúsculas no adaptadas a pantallas táctiles, partidas interminables de 45 minutos y drenaje excesivo de batería.

### La Propuesta de Valor (Océano Azul)
**"El combate táctico visceral de Darkest Dungeon y Warhammer Quest en partidas de 3 a 5 minutos para tu móvil."**
- **Micro-Táctico Móvil:** Cámaras tácticas compactas (24x18 casillas) donde cada decisión importa.
- **Auto-Guardado por Turno:** Cero fricción. Si cierras la app o te llaman, la partida se reanuda en el milisegundo exacto.
- **Mecánica Viral de Pifias y Corrupción:** Las pifias de disformidad, explosiones de pólvora y frenesí berserker generan momentos únicos altamente compartibles en TikTok, Shorts, Twitch y Reddit.
- **Modo DJ / Creador Comunitario:** Contenido infinito generado por la comunidad mediante mapas compartibles.

---

## 💰 2. MODELO DE MONETIZACIÓN & UNIT ECONOMICS

| Plataforma | Modelo | Precio / Estrategia |
| :--- | :--- | :--- |
| **Móvil (iOS / Android)** | **Freemium Ético (Free-to-Try)** | - Acto 1 (Alcantarillas de Altdorf) 100% Gratis.<br>- Desbloqueo de Campaña Completa (Actos 2, 3, 4 + Modo DJ): **4,99€ - 9,99€** compra única.<br>- Bandas Temáticas / DLCs cosméticos: **2,99€** por banda (Inquisición, Ogros, Nurgle). |
| **Escritorio (Steam/Mac)** | **Premium B2P** | - **14,99€ - 19,99€** con todos los actos incluidos + DLCs cosméticos. |

---

## 🛡️ 3. CORE GAMEPLAY & PILARES DE DISEÑO (WARHAMMER RULES)

### A. La Compañía Aventurera (Los 4 Héroes)
1. **Gotreksson (Matador Enano):** Tanque Berserker. Inmune a psicología. A menor HP, mayor penetración y daño crítico.
2. **Kallina von Halstadt (Cazadora de Brujas):** DPS a distancia con pistola de pólvora (requiere recarga) y estoque bendito.
3. **Valtieri de Aqshy (Hechicero Brillante):** Daño en área con Vientos de la Magia. Riesgo de Disfunción de la Disformidad en pifias (1 natural).
4. **Hermana Beryl de Sigmar (Sacerdotisa Guerrera):** Soporte en primera línea. Plegarias de curación, disipación de pánico y martillo sagrado.

### B. Los 4 Actos de Campaña
1. **Acto I:** *Las Alcantarillas de Altdorf* (Skavens y Rata Ogro Boss).
2. **Acto II:** *El Bosque de las Sombras* (Hombres Bestia y Caudillo Gor).
3. **Acto III:** *Las Ruinas Enanas de Karak Kadrin* (Goblins Nocturnos, Fanáticos y Trolls).
4. **Acto IV:** *La Fortaleza de la Disformidad* (Guerreros del Caos y Paladín Elegido).

---

## ⚙️ 4. ARQUITECTURA TÉCNICA (GODOT 4.X)

- **Capa de Dominio:** 100% Data-Driven desacoplada en recursos `.tres` (`HeroData`, `EnemyData`, `AbilityData`, `ItemData`, `ActData`).
- **Capa de Comunicación:** `EventBus` reactivo centralizado (`event_bus.gd`).
- **Navegación & Grid:** Algoritmo A* determinista en `tactical_grid.gd` con renderizado procedural 2.5D en `grid_renderer.gd`.
- **UI/UX CRPG:** Ergonomía táctil inspirada en *Baldur's Gate / FFVIII* con *Party Bar* lateral y *Action Bar* inferior.
- **Audio:** `AudioManager` Autoload global con pistas `.ogg` balanceadas.

---

## 🚀 5. ROADMAP DE PRODUCCIÓN
1. [x] Core Táctico, Pathfinding A*, Inventario y UI CRPG.
2. [x] Documentación y Biblia de Producto en GitHub.
3. [ ] **Fase 1:** Transformación completa de Héroes y Enemigos al Lore de Warhammer Fantasy.
4. [ ] **Fase 2:** Sistema de Pólvora (Recarga), Vientos de la Magia y Pifias de Disformidad.
5. [ ] **Fase 3:** Sistema de Progresión (Herrería y Subida de Nivel de Héroes).
6. [ ] **Fase 4:** Modo DJ Flotante y presets de exportación móvil (iOS / Android).

