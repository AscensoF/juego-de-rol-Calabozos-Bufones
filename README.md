# Calabozos & Bufones (RPG Táctico D20)

*Una aventura de rol táctico, satírica, data-driven y optimizada para dispositivos móviles (iOS y Android) y escritorio.*

---

## 🎯 Visión y Objetivo del Proyecto
El objetivo final de este proyecto es su publicación y lanzamiento comercial completo en:
- **Apple App Store (iOS)**
- **Google Play Store (Android)**
- **PC / Mac (Steam / Desktop)**

El juego ha evolucionado de su prototipo conceptual web original a una arquitectura nativa, robusta y escalable en **Godot Engine 4.x**, con controles táctiles ergonómicos, rendimiento optimizado para batería y renderizado 2.5D de bajo consumo.

---

## ⚔️ Características Principales

- **Combate Táctico por Turnos D20:** Sistema matemático de dados D20 con impactos, críticos (20 natural), pifias (1) y modificadores de atributos.
- **Pathfinding A* y Navegación Dinámica:** Cálculo de rutas óptimas ortogonales sorteando muros y entidades con niebla de guerra (*Fog of War*) suave.
- **Diseño de Interfaz CRPG Clásico (Baldur's Gate / FFVIII / NWN):**
  - *Party Bar* táctil lateral con retratos vivos de héroes y barras de salud reactivas.
  - *Action Bar* ergonómica inferior para ataques básicos, habilidades especiales y mochila.
  - Diálogos cinemáticos satíricos con efecto *Typewriter*.
- **Arquitectura Data-Driven Desacoplada:** Héroes, monstruos, habilidades, consumibles y actos completamente definidos mediante recursos `.tres`.
- **Campaña de 4 Actos Satíricos:**
  1. *Acto 1:* La Taberna del Caos.
  2. *Acto 2:* Las Catacumbas del Despido Procedente.
  3. *Acto 3:* La Biblioteca de los Grimorios Burocráticos.
  4. *Acto 4:* La Confrontación Final con la Sombra del Director.
- **Banda Sonora Original & SFX:** Pistas de audio ambiental `.ogg` por cada acto gestionadas mediante un `AudioManager` global calibrado.
- **Modo DJ (Dungeon Master en Vivo):** Panel interactivo para pintar casillas, invocar monstruos sorpresa y alterar el mapa en tiempo real.

---

## 🛠️ Estructura del Proyecto (Godot 4.x)

```
juego-de-rol-calabozos-bufones/
├── godot/                         # Proyecto nativo de Godot Engine 4.x
│   ├── assets/                    # Sprites, texturas, música (.ogg) y fuentes
│   ├── data/                      # Recursos .tres (Héroes, Enemigos, Habilidades, Ítems, Actos)
│   ├── src/                       # Código fuente modular en GDScript
│   │   ├── combat/                # Reglas D20, comandos de ataque y tiradas
│   │   ├── core/                  # EventBus, GameManager, TacticalGrid, AudioManager
│   │   ├── data_classes/          # Definición de clases de recursos (HeroData, EnemyData...)
│   │   ├── dj_mode/               # Controlador del Modo DJ
│   │   ├── map/                   # GridRenderer (2.5D, antorchas, sombras), TacticalCamera
│   │   ├── state_machine/         # StateMachine (MainMenu, Exploration, Combat, GameOver)
│   │   └── ui/                    # CombatHUDController, DialogueBox, DiceVisualizer
│   └── project.godot              # Configuración del motor, Autoloads y display
└── README.md                      # Documentación del proyecto
```

---

## 📱 Roadmap para Publicación Móvil (App Store / Play Store)

1. [x] **Core Táctico & Reglas D20:** Héroes, habilidades, tiradas e inventario.
2. [x] **Pathfinding A* & Niebla de Guerra:** Movimiento animado e iluminación procedural.
3. [x] **UI/UX Táctil CRPG:** Adaptada a pantallas táctiles y móviles en horizontal (*Landscape*).
4. [x] **Sistema de Diálogos Satíricos:** Motor cinemático con retratos y textos.
5. [ ] **Campaña Completa de 4 Actos:** Creación de recursos y encuentros para Actos 2, 3 y 4.
6. [ ] **Modo DJ Flotante:** Herramienta interactiva de edición en vivo.
7. [ ] **Export Presets & Safe Area:** Configuración para iOS (Xcode / IPA) y Android (Gradle / APK / AAB) con soporte de *notches* e iconos adaptativos.

---

## 👨‍💻 Créditos
- **Diseño, Dirección y Desarrollo:** Miguel (Ascenso Financiero)
- **Motor:** Godot Engine 4.x

