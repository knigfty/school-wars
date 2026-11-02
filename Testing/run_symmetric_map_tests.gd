extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var counts: Dictionary = {}
	var layouts: Dictionary = {}
	for mode: int in 3:
		for seed_value: int in 40:
			var sim := ClassicSimulation.new()
			sim.medieval = true
			sim.difficulty = mode
			sim.setup(0, seed_value, true)
			counts[sim.areas.size()] = true
			layouts[JSON.stringify(sim.areas).sha256_text()] = true
			_check(sim.areas.size() >= 20 and sim.areas.size() <= 32 and (sim.areas.size() - 4) % 4 == 0, "Random tile totals consist of complete four-way groups")
			var distance_profiles: Array = []
			for base: Vector2i in sim.bases:
				var profile: Dictionary = {}
				for area: Dictionary in sim.areas:
					if area.kind == ClassicRules.AreaKind.BASE:
						continue
					var distance: int = absi(base.x - area.tile.x) + absi(base.y - area.tile.y)
					var key := Vector2i(area.kind, distance)
					profile[key] = int(profile.get(key, 0)) + 1
				distance_profiles.append(profile)
			for profile: Dictionary in distance_profiles:
				_check(profile == distance_profiles[0], "Every race has identical distances to each objective kind")
			for area: Dictionary in sim.areas:
				for reflected: Vector2i in [Vector2i(15 - area.tile.x, area.tile.y), Vector2i(area.tile.x, 15 - area.tile.y), Vector2i(15 - area.tile.x, 15 - area.tile.y)]:
					_check(sim.area_at.has(reflected) and sim.areas[sim.area_at[reflected]].kind == area.kind, "All quadrants mirror both placement and tile type")
				for direction: Vector2i in ClassicRules.DIRECTIONS:
					_check(not sim.area_at.has(area.tile + direction), "Objectives retain the existing non-adjacency rule across seams and near bases")
				_check(area.owner == (-1 if area.kind != ClassicRules.AreaKind.BASE else sim.bases.find(area.tile)), "Neutral ownership and race bases are correct")
			var replay := ClassicSimulation.new()
			replay.medieval = true
			replay.difficulty = mode
			replay.setup(0, seed_value, true)
			_check(sim.areas == replay.areas and sim.bases == replay.bases, "Same spectator seed reproduces the layout and base assignment")
			for race: int in 4:
				_check(sim.get_count(race) == 3, "All armies retain their initial population")
	_check(counts.size() > 1 and layouts.size() > 1, "Spectator counts and layouts remain randomized")
	var golden: Dictionary = {1: "e1dd0dffd6219c28df5eef0631664cbfd7403233f659cd6358a234d264fca3e6", 123: "8ae855584cb9a5a8828af968f32a26af8a17060a2b49d2f63c0c838bba258261", 12345: "7c439bcdc2a2bfcf526e2528af9f35ff0faded0a8f80d27fc29b0d2b9f30a941"}
	for seed_value: int in golden:
		var sim := ClassicSimulation.new()
		sim.medieval = true
		sim.setup(0, seed_value)
		_check(JSON.stringify(sim.areas).sha256_text() == golden[seed_value], "Player-controlled map generation remains unchanged")
	print("Symmetric spectator map tests: %d failure(s)" % failures)
	quit(1 if failures else 0)
