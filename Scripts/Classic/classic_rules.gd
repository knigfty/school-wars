class_name ClassicRules
extends RefCounted

## Values recovered from schwar.swf, DefineSprite_862. Time is in 18 Hz ticks.
const TICKS_PER_SECOND: int = 18
const BOARD_SIZE: int = 16
const CELLS_PER_TILE: int = 4
const GRID_SIZE: int = BOARD_SIZE * CELLS_PER_TILE
const TEAM_CAP: int = 12
const TEAM_NAMES: Array[String] = ["Black", "Green", "Yellow", "Purple"]
const COLORS: Array[Color] = [Color("62625b"), Color("00bb00"), Color("b7b500"), Color("b000b5")]
const HEALTH: Array[float] = [20.0, 10.0, 25.0, 15.0]
const PUNCH: Array[float] = [4.0, 2.0, 3.0, 5.0]
const RECRUIT_THRESHOLD: Array[int] = [1500, 500, 1500, 1500]
const CAPTURE_TICKS: int = 300
const HEAL_PER_TICK: float = 0.1
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

enum AreaKind { BASE = 1, RECRUIT = 2, HEAL = 3 }

static func cell_to_world(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * 12.0, (cell.x + cell.y) * 6.0)


static func world_to_cell(world: Vector2) -> Vector2i:
	return Vector2i(floori(world.x / 24.0 + world.y / 12.0), floori(world.y / 12.0 - world.x / 24.0))


static func in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE and cell.y < GRID_SIZE
