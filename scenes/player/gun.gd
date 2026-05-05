extends Node3D

@onready var mesh_instance = $ak48

func set_weapon_data(data: WeaponData):
	if data and data.weapon_mesh:
		mesh_instance.mesh = data.weapon_mesh
		mesh_instance.position = data.position_offset
		mesh_instance.rotation_degrees = data.rotation_offset
