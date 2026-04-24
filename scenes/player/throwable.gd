extends RigidBody3D
class_name Throwable

@export var explode_on_impact: bool = true
@export var explosion_radius: float = 2.0
@export var fuse_time: float = 0.0
@export var destroy_voxels: bool = true
@export var shrapnel_count: int = 20
@export var shrapnel_speed: float = 15

var exploded: bool = false
var last_hit_terrain: NodePath

func _ready():
	if multiplayer.is_server():
		contact_monitor = true
		max_contacts_reported = 1
		body_entered.connect(_on_body_entered)
		
		if fuse_time > 0.0:
			get_tree().create_timer(fuse_time).timeout.connect(_explode)
	else:
		contact_monitor = false

func _physics_process(_delta):
	# Align the football nose (local X-axis) to face its velocity direction every frame.
	# This gives a realistic arc as gravity bends the trajectory.
	if linear_velocity.length() > 0.5:
		var vel_dir = linear_velocity.normalized()
		# Build a basis where the local X-axis points in the direction of travel.
		var up = Vector3.UP
		if abs(vel_dir.dot(up)) > 0.99:
			up = Vector3.FORWARD
		var new_basis = Basis(vel_dir, up.cross(vel_dir).normalized(), vel_dir.cross(up.cross(vel_dir).normalized()))
		# Smoothly blend to avoid snapping
		global_transform.basis = global_transform.basis.slerp(new_basis, 0.3)

func _on_body_entered(body):
	if body is VoxelLodTerrain:
		last_hit_terrain = body.get_path()
		
	if exploded or not multiplayer.is_server():
		return
		
	if explode_on_impact:
		_explode()
		
func _explode():
	if exploded or not multiplayer.is_server():
		return
	exploded = true
	_trigger_explosion()
	sync_explode.rpc()
	
@rpc("call_local", "authority", "reliable")
func sync_explode():
	_spawn_explosion_particles()
	queue_free()

func _trigger_explosion():
	if destroy_voxels:
		var terrain_path = last_hit_terrain
		if terrain_path.is_empty():
			# Try to find the terrain in the tree if we didn't hit it directly
			var terrain = get_tree().root.find_child("VoxelLodTerrain", true, false)
			if terrain:
				terrain_path = terrain.get_path()
		
		# Find a node (like a Player) that can execute the destruction RPC
		_find_player_and_explode(get_tree().root, terrain_path)

func _find_player_and_explode(node: Node, terrain_path: NodePath) -> bool:
	if node.has_method("destroy_voxel_sphere") and node.is_multiplayer_authority():
		node.destroy_voxel_sphere.rpc(terrain_path, global_position, explosion_radius)
		return true
		
	for child in node.get_children():
		if _find_player_and_explode(child, terrain_path):
			return true
	return false

func _spawn_explosion_particles():
	var particles = CPUParticles3D.new()
	get_tree().root.add_child(particles)
	particles.global_position = global_position
	
	# Configure explosion look
	particles.emitting = false
	particles.amount = 30
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 1.0
	
	# Shape
	particles.spread = 180.0
	particles.gravity = Vector3(0, -2, 0)
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 10.0
	
	# Appearance
	var mesh = SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	particles.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.5, 0) # Orange
	mat.emission_enabled = true
	mat.emission = Color(1, 0.3, 0)
	particles.material_override = mat
	
	# Scale curve (shrink over time)
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	particles.scale_amount_curve = curve
	
	particles.emitting = true
	
	# Auto-cleanup
	get_tree().create_timer(1.5).timeout.connect(particles.queue_free)
