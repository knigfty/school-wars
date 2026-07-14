class_name StudentStats
extends Resource

## Shared, data-only configuration for a student unit.
## Runtime state such as current health and targets belongs on unit components.

@export_category("Survivability")
@export_range(1.0, 1000.0, 1.0, "or_greater") var maximum_health: float = 100.0

@export_category("Movement")
@export_range(1.0, 1000.0, 1.0, "or_greater") var movement_speed: float = 180.0
@export_range(1.0, 5000.0, 1.0, "or_greater") var acceleration: float = 1200.0
@export_range(1.0, 5000.0, 1.0, "or_greater") var deceleration: float = 1600.0

@export_category("Combat")
@export_range(0.0, 1000.0, 1.0, "or_greater") var attack_damage: float = 10.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var attack_range: float = 28.0
@export_range(0.01, 20.0, 0.01, "or_greater") var attacks_per_second: float = 1.0

