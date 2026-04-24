extends Resource
class_name ThrowableType

@export_group("Explosion Properties")
@export var explosion_radius: float = 2.0
@export var fuse_time: float = 0.0
@export var destroy_voxels: bool = true
@export var explosion_damage: int = 50

@export_group("Visuals")
@export var particle_color: Color = Color(1, 0.5, 0)
@export var particle_emission: Color = Color(1, 0.3, 0)
@export var particle_count: int = 30
@export var particle_size: float = 0.2
@export var particle_lifetime: float = 1.0

@export_group("Effects")
@export var effect_id: String = "default" # e.g., "fire", "blindness", "wind"
@export var effect_intensity: float = 1.0
@export var effect_duration: float = 3.0
