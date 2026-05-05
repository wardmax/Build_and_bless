class_name WeaponData extends ItemData

enum WeaponType { HITSCAN, PROJECTILE, GRAVITY }

@export var weapon_type: WeaponType = WeaponType.HITSCAN
@export var weapon_mesh: Mesh
@export var position_offset: Vector3 = Vector3.ZERO
@export var rotation_offset: Vector3 = Vector3.ZERO
@export var damage: int = 20
@export var fire_rate: float = 0.1
@export var is_automatic: bool = true
@export var max_ammo: int = 20
@export var reload_time: float = 2.0
@export var bullet_spread: float = 2.0
@export var recoil_animation: String = "recoil"
