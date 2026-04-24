extends RigidBody3D
class_name Throwable

@export var type_data: ThrowableType

@export_group("Overrides (Used if type_data is null)")
@export var explode_on_impact: bool = true
@export var explosion_radius: float = 2.0
@export var fuse_time: float = 0.0
@export var destroy_voxels: bool = true
@export var shrapnel_count: int = 20
@export var shrapnel_speed: float = 15

var exploded: bool = false
var last_hit_terrain: NodePath

func _ready():
	# Use type_data properties if available
	if type_data:
		explosion_radius = type_data.explosion_radius
		fuse_time = type_data.fuse_time
		destroy_voxels = type_data.destroy_voxels
		shrapnel_count = type_data.particle_count
		
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
	if linear_velocity.length() > 0.5:
		var vel_dir = linear_velocity.normalized()
		var up = Vector3.UP
		if abs(vel_dir.dot(up)) > 0.99:
			up = Vector3.FORWARD
		var new_basis = Basis(vel_dir, up.cross(vel_dir).normalized(), vel_dir.cross(up.cross(vel_dir).normalized()))
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
	
	# Server-side logic
	_trigger_explosion()
	_apply_custom_effects()
	
	sync_explode.rpc()
	
@rpc("call_local", "authority", "reliable")
func sync_explode():
	_spawn_explosion_particles()
	# Optional: play sound here
	queue_free()

func _trigger_explosion():
	if destroy_voxels:
		var terrain_path = last_hit_terrain
		if terrain_path.is_empty():
			var terrain = get_tree().root.find_child("VoxelLodTerrain", true, false)
			if terrain:
				terrain_path = terrain.get_path()
		
		_find_player_and_explode(get_tree().root, terrain_path)

func _apply_custom_effects():
	if not type_data:
		return
		
	# MODULAR EFFECTS: Add logic here based on type_data.effect_id
	match type_data.effect_id:
		"default":
			pass
		"fire":
			# TODO: Spawn fire area or apply burn to players in radius
			pass
		"blindness":
			# TODO: Apply blindness effect to players in radius
			pass
		"wind":
			# TODO: Apply knockback force to all physics bodies in radius
			pass

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
	# Add to the current scene instead of root for better tracking
	var target_parent = get_tree().current_scene
	if not target_parent: target_parent = get_tree().root
	target_parent.add_child(particles)
	
	particles.global_position = global_position
	
	# Default colors
	var p_color = Color(1, 0.5, 0)
	var p_emission = Color(1, 0.3, 0)
	var p_count = shrapnel_count
	var p_size = 0.2
	var p_lifetime = 1.0
	
	# Override with type_data if present
	if type_data:
		p_color = type_data.particle_color
		p_emission = type_data.particle_emission
		p_count = type_data.particle_count
		p_size = type_data.particle_size
		p_lifetime = type_data.particle_lifetime

	# Configure explosion look
	particles.emitting = false
	particles.amount = p_count
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = p_lifetime
	
	# Shape
	particles.spread = 180.0
	particles.gravity = Vector3(0, -4, 0)
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 12.0
	
	# Appearance
	var mesh = SphereMesh.new()
	mesh.radius = p_size
	mesh.height = p_size * 2.0
	particles.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = p_color
	mat.emission_enabled = true
	mat.emission = p_emission
	mat.emission_energy_multiplier = 3.0 # Brighter emission
	particles.material_override = mat
	
	# Scale curve (shrink over time)
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	particles.scale_amount_curve = curve
	
	# Start emitting
	particles.emitting = true
	
	# Auto-cleanup
	get_tree().create_timer(p_lifetime + 0.5).timeout.connect(particles.queue_free)
