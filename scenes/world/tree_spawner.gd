extends Node3D

@export var tree_scene: PackedScene = preload("res://scenes/world/tree.tscn")
@export var tree_count: int = 150
@export var spawn_radius: float = 300.0    # Max distance from origin in X/Z
@export var raycast_height: float = 200.0  # Height to cast rays from
@export var min_y: float = 0.0             # Don't place trees below water level
@export var seed_value: int = 42

# Paths to all available tree meshes
const TREE_MESH_PATHS: Array[String] = [
	"res://asssets/Models/Tree Meshes/tree1.obj",
	"res://asssets/Models/Tree Meshes/tree2.obj",
	"res://asssets/Models/Tree Meshes/tree3.obj",
]

var _tree_meshes: Array[ArrayMesh] = []

func _ready():
	_preload_meshes()
	await get_tree().create_timer(2.0).timeout
	_spawn_trees()

func _preload_meshes():
	for path in TREE_MESH_PATHS:
		var mesh = load(path)
		if mesh:
			_tree_meshes.append(mesh)
	if _tree_meshes.is_empty():
		push_warning("TreeSpawner: No tree meshes could be loaded from Tree Meshes folder.")

func _spawn_trees():
	if _tree_meshes.is_empty():
		return

	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value

	var space_state = get_world_3d().direct_space_state
	var spawned := 0
	var attempts := 0
	var max_attempts := tree_count * 10

	while spawned < tree_count and attempts < max_attempts:
		attempts += 1

		var x = rng.randf_range(-spawn_radius, spawn_radius)
		var z = rng.randf_range(-spawn_radius, spawn_radius)

		var ray_from = Vector3(x, raycast_height, z)
		var ray_to   = Vector3(x, -raycast_height, z)

		var query = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		query.collide_with_areas = false
		query.collide_with_bodies = true

		var result = space_state.intersect_ray(query)
		if result.is_empty():
			continue

		var hit_pos: Vector3 = result.position
		var hit_normal: Vector3 = result.normal

		if hit_pos.y < min_y:
			continue
		if hit_normal.y < 0.7:   # Skip slopes steeper than ~46°
			continue

		var tree = tree_scene.instantiate()
		get_parent().add_child(tree)
		tree.global_position = hit_pos

		# Random Y rotation for variety
		tree.rotation = Vector3(0, rng.randf_range(0.0, TAU), 0)

		# Swap in a random mesh on the MeshInstance3D child
		var mesh_instance = tree.get_node_or_null("MeshInstance3D")
		if mesh_instance:
			var chosen_mesh = _tree_meshes[rng.randi_range(0, _tree_meshes.size() - 1)]
			mesh_instance.mesh = chosen_mesh

		spawned += 1

	print("TreeSpawner: placed %d trees (%d attempts)" % [spawned, attempts])
