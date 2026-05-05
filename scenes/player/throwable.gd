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
	if not type_data:
		type_data = load("res://scripts/Item Data/footbomb_default.tres")
		
	if type_data:
		explosion_radius = type_data.explosion_radius
		fuse_time = type_data.fuse_time
		destroy_voxels = type_data.destroy_voxels
		shrapnel_count = type_data.particle_count
		
		# Apply bomb color
		var mesh_instance = get_node_or_null("MeshInstance3D")
		if mesh_instance:
			var mat = mesh_instance.get_surface_override_material(0)
			if not mat:
				var base_mat = mesh_instance.mesh.surface_get_material(0)
				if base_mat:
					mat = base_mat.duplicate()
				else:
					mat = StandardMaterial3D.new()
				mesh_instance.set_surface_override_material(0, mat)
			
			if "bomb_color" in type_data:
				mat.albedo_color = type_data.bomb_color
			else:
				mat.albedo_color = type_data.particle_color
		
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
	
	if has_node("AudioStreamPlayer3D"):
		var audio = $AudioStreamPlayer3D
		remove_child(audio)
		var target_parent = get_tree().current_scene
		if not target_parent: target_parent = get_tree().root
		target_parent.add_child(audio)
		audio.global_position = global_position
		audio.play()
		audio.finished.connect(audio.queue_free)
		
	queue_free()

func _trigger_explosion():
	if destroy_voxels:
		var terrain_path = last_hit_terrain
		if terrain_path.is_empty():
			var terrain = get_tree().root.find_child("VoxelLodTerrain", true, false)
			if terrain:
				terrain_path = terrain.get_path()
		
		_find_player_and_explode(get_tree().root, terrain_path)

	_apply_explosion_damage()

func _apply_explosion_damage():
	var damage = 50
	if type_data and "explosion_damage" in type_data:
		damage = type_data.explosion_damage

	# Search all nodes in the scene for anything that can take damage
	var candidates = get_tree().root.find_children("*", "CharacterBody3D", true, false)
	for node in candidates:
		if not node.has_method("take_damage"):
			continue
		var dist = node.global_position.distance_to(global_position)
		if dist <= explosion_radius:
			# Scale damage: full at centre, zero at the edge
			var damage_scale = 1.0 - clamp(dist / explosion_radius, 0.0, 1.0)
			var scaled_damage = int(damage * damage_scale)
			if scaled_damage <= 0:
				continue
			# Knock the player away from the explosion, slightly upward
			var direction = (node.global_position - global_position)
			direction.y += explosion_radius * 0.3
			direction = direction.normalized()
			node.take_damage(scaled_damage, 0, direction)


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
	# Read values from type_data or fall back to defaults
	var p_color    = Color(1, 0.5, 0)
	var p_emission = Color(1, 0.3, 0)
	var p_count    = shrapnel_count
	var p_size     = 0.2
	var p_lifetime = 1.0

	if type_data:
		p_color    = type_data.particle_color
		p_emission = type_data.particle_emission
		p_count    = type_data.particle_count
		p_size     = type_data.particle_size
		p_lifetime = type_data.particle_lifetime

	# --- Process Material (controls movement & color) ---
	var process_mat = ParticleProcessMaterial.new()
	process_mat.direction          = Vector3(0, 1, 0)
	process_mat.spread             = 180.0
	process_mat.gravity            = Vector3(0, -10, 0)
	process_mat.initial_velocity_min = 5.0
	process_mat.initial_velocity_max = 12.0
	process_mat.scale_min          = p_size
	process_mat.scale_max          = p_size * 1.5

	# Fade from bright emission colour → transparent over lifetime
	var gradient = Gradient.new()
	gradient.set_color(0, Color(p_emission.r, p_emission.g, p_emission.b, 1.0))
	gradient.add_point(1.0, Color(p_color.r, p_color.g, p_color.b, 0.0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = gradient
	process_mat.color_ramp = grad_tex

	# --- Draw mesh (billboard quad looks great for sparks) ---
	var draw_mesh = QuadMesh.new()
	draw_mesh.size = Vector2(p_size, p_size)

	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency           = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode           = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.billboard_mode         = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.albedo_color           = p_color
	draw_mat.emission_enabled       = true
	draw_mat.emission               = p_emission
	draw_mat.emission_energy_multiplier = 4.0
	draw_mat.vertex_color_use_as_albedo = true  # lets the color ramp tint the quads
	draw_mesh.material = draw_mat

	# --- GPUParticles3D node ---
	var particles = GPUParticles3D.new()
	particles.amount          = p_count
	particles.lifetime        = p_lifetime
	particles.one_shot        = true
	particles.explosiveness   = 1.0
	particles.randomness      = 0.2
	particles.process_material = process_mat
	particles.draw_passes     = 1
	particles.set_draw_pass_mesh(0, draw_mesh)
	# Bounding box large enough to never cull early
	particles.visibility_aabb  = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))

	# Add to scene AFTER full configuration so the first frame is correct
	var target_parent = get_tree().current_scene
	if not target_parent:
		target_parent = get_tree().root
	target_parent.add_child(particles)
	particles.global_position = global_position
	particles.emitting = true

	# Auto-cleanup once the burst is done
	get_tree().create_timer(p_lifetime + 0.5).timeout.connect(particles.queue_free)
