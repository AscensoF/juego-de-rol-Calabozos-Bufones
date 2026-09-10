class_name Enums

enum GameFlowState {
	MAIN_MENU,
	EXPLORATION,
	COMBAT,
	DJ_MODE,
	GAME_OVER
}

enum CellType {
	FLOOR = 0,
	WALL = 1,
	DOOR = 2,
	TRAP = 3,
	CHEST = 4,
	ALTAR = 5,
	BOOKSHELF = 6
}

enum Attribute {
	STRENGTH = 0,
	DEXTERITY = 1,
	INTELLIGENCE = 2,
	CONSTITUTION = 3
}

enum ActionType {
	ATTACK = 0,
	SPELL = 1,
	ITEM = 2,
	MOVE = 3,
	END_TURN = 4
}

enum EnemyKind {
	GOBLIN_BUROCRATA = 0,
	ESQUELETO_DESMOTIVADO = 1,
	ORCO_CHISTOSO = 2,
	MIMICO_EXISTENCIAL = 3,
	LIMO_NOSTALGIA = 4,
	REY_ORCO_KARAOKE = 5
}

enum HeroClass {
	GUERRERO = 0,
	MAGO = 1,
	PICARO = 2,
	CLERIGO = 3
}

