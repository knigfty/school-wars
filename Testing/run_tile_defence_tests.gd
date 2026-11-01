extends SceneTree
var failures: int = 0
func _initialize() -> void:
 call_deferred("_run")
func _check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func _run() -> void:
 for mode: int in 3:
  for player_controlled: bool in [false, true]:
   var sim: ClassicSimulation = ClassicSimulation.new()
   sim.medieval = true
   sim.difficulty = mode
   sim.setup(0 if player_controlled else 3, 1234)
   sim.ai_enabled = false
   sim.ticks = 100
   for unit: ClassicStudent in sim.students:
    unit.state = ClassicStudent.State.UNUSED
   sim.occupancy.clear()
   sim.areas.clear()
   sim.area_at.clear()
   sim._add_area(Vector2i(5, 5), ClassicRules.AreaKind.RECRUIT, -1)
   var group: Array[ClassicStudent] = []
   for id: int in 4:
    var unit: ClassicStudent = sim.students[id]
    sim._initialize_student(unit, 0, Vector2i(20 + id % 2, 20 + id / 2))
    unit.state = ClassicStudent.State.SIT
    unit.ai_spawn_wait = false
    group.append(unit)
   var weak: ClassicStudent = sim.students[10]
   sim._initialize_student(weak, 1, Vector2i(22, 22))
   weak.health = 1
   var strong: ClassicStudent = sim.students[11]
   sim._initialize_student(strong, 1, Vector2i(23, 22))
   strong.health = 100
   for unit: ClassicStudent in group:
    sim.designate_order(unit, Vector2i(5, 5))
    sim._update_tile_order(unit)
    _check(unit.target_id == weak.id, "All assigned units share a same-tile target")
    _check(not sim._may_engage(unit, strong) or sim._tile_order_allows(unit, strong.cell), "Capture combat stays on assigned tile")
   sim.occupancy.erase(weak.cell)
   sim.occupancy.erase(strong.cell)
   weak.state = ClassicStudent.State.UNUSED
   strong.state = ClassicStudent.State.UNUSED
   for unit: ClassicStudent in group:
    sim._update_tile_order(unit)
    _check(unit.state == ClassicStudent.State.STAND and unit.tile_clear_at == 118, "Cleared tile starts a one-second standing interval")
   sim.ticks = 117
   for unit: ClassicStudent in group:
    sim._update_tile_order(unit)
    _check(unit.state == ClassicStudent.State.STAND, "Units do not sit before one second")
   sim._capture_areas()
   _check(sim.areas[0].progress[0] == 0, "Standing interval adds no capture progress")
   sim.ticks = 118
   for unit: ClassicStudent in group:
    sim._update_tile_order(unit)
    _check(unit.state == ClassicStudent.State.SIT, "Units sit exactly after one clear second")
   sim._capture_areas()
   _check(sim.areas[0].progress[0] > 0, "Sitting group begins capture")
   sim.areas[0].owner = 0
   for unit: ClassicStudent in group:
    sim._update_tile_order(unit)
    _check(Vector2i(unit.cell.x / 4, unit.cell.y / 4) == Vector2i(5, 5) and unit.state == ClassicStudent.State.SIT, "Captured tile remains held")
   sim._initialize_student(weak, 1, Vector2i(24, 20))
   weak.health = 100
   for unit: ClassicStudent in group:
    sim._update_tile_order(unit)
    _check(unit.tile_guard_target == weak.id, "Enemy one movement cell beside tile activates shared defence")
    _check(not sim._tile_order_allows(unit, Vector2i(28, 20)), "Defence cannot pursue two tiles away")
   var defender: ClassicStudent = group[0]
   sim.occupancy.erase(defender.cell)
   defender.cell = Vector2i(25, 20)
   sim.occupancy[defender.cell] = defender.id
   sim.occupancy.erase(weak.cell)
   weak.cell = Vector2i(28, 20)
   sim.occupancy[weak.cell] = weak.id
   sim._update_tile_order(defender)
   _check(defender.returning_to_tile and defender.target_id == -1 and defender.designated_tile == Vector2i(5, 5), "Out-of-zone target forces return to defending tile")
   var other: ClassicStudent = group[1]
   sim.occupancy.erase(other.cell)
   other.cell = Vector2i(25, 21)
   sim.occupancy[other.cell] = other.id
   weak.state = ClassicStudent.State.DEAD
   sim._update_tile_order(other)
   _check(other.returning_to_tile and other.target_id == -1, "Target death also forces return")
 print("Tile defence tests: %d failure(s)" % failures)
 quit(1 if failures else 0)
