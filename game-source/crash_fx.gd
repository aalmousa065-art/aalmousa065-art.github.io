extends Node3D
## Lightweight GL-compatible vehicle damage and impact effects.
## impact strength is normalized from 0 to 1; integrity is from 0 to 100.

const MAX_PARTICLES := 96
const MAX_SKIDS := 72
var trauma := 0.0
var impact_count := 0
var enabled_sound := true
var vehicle: Node3D
var integrity := 100.0
var particles: Array[Dictionary] = []
var skids: Array[Dictionary] = []
var body_parts: Array[Dictionary] = []
var smoke_clock := 0.0
var skid_clock := 0.0
var last_skid_position := Vector3(9999, 9999, 9999)
var random := RandomNumberGenerator.new()
var crash_sound: AudioStreamWAV
var audio_players: Array[AudioStreamPlayer3D] = []
var audio_index := 0
var sphere: SphereMesh
var fragment: BoxMesh
var spark_mesh: BoxMesh
var skid_mesh: PlaneMesh
var metal_material: StandardMaterial3D

func _ready() -> void:
	random.randomize()
	sphere = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	fragment = BoxMesh.new()
	fragment.size = Vector3(0.11, 0.045, 0.19)
	spark_mesh = BoxMesh.new()
	spark_mesh.size = Vector3(0.025, 0.025, 0.14)
	skid_mesh = PlaneMesh.new()
	skid_mesh.size = Vector2(0.22, 0.80)
	metal_material = StandardMaterial3D.new()
	metal_material.albedo_color = Color("40515a")
	metal_material.metallic = 0.72
	metal_material.roughness = 0.46
	crash_sound = make_crash_audio()
	for i in range(3):
		var sound := AudioStreamPlayer3D.new()
		sound.stream = crash_sound
		sound.max_distance = 70.0
		sound.unit_size = 8.0
		sound.max_db = -4.0
		add_child(sound)
		audio_players.append(sound)

func setup(car: Node3D) -> void:
	vehicle = car
	body_parts.clear()
	collect_body_parts(car)

func collect_body_parts(node: Node) -> void:
	if node is MeshInstance3D:
		var part := node as MeshInstance3D
		var part_name := String(part.name).to_lower().replace(" ", "_")
		if part.mesh != null and (part_name.contains("hood") or part_name.contains("lower_body") or part_name.contains("front_bumper")):
			body_parts.append({"node": part, "mesh": part.mesh, "to_car": vehicle.global_transform.affine_inverse() * part.global_transform})
	for child in node.get_children():
		collect_body_parts(child)

func impact(world_position: Vector3, normal: Vector3, strength: float) -> void:
	var power := clampf(strength, 0.0, 1.0)
	if power < 0.035:
		return
	impact_count += 1
	trauma = minf(1.0, trauma + 0.13 + power * 0.76)
	var outward := normal.normalized()
	if outward.length_squared() < 0.1:
		outward = Vector3.UP
	var origin := world_position + outward * 0.15
	origin.y = maxf(origin.y, 0.18)
	for i in range(4 + int(power * 12.0)):
		var velocity := outward * random.randf_range(1.5, 5.0) * power
		velocity += Vector3(random.randf_range(-4.0, 4.0), random.randf_range(1.7, 6.0), random.randf_range(-4.0, 4.0)) * (0.4 + power)
		spawn_particle(origin, velocity, "spark", random.randf_range(0.17, 0.52), random.randf_range(0.5, 1.5), Color(1.0, 0.59, 0.12, 1.0))
	for i in range(2 + int(power * 5.0)):
		var velocity := outward * (1.5 + power * 2.0) + Vector3(random.randf_range(-2.0, 2.0), random.randf_range(1.8, 4.8), random.randf_range(-2.0, 2.0))
		spawn_particle(origin, velocity, "debris", random.randf_range(1.7, 3.4), random.randf_range(0.6, 1.4), Color.WHITE)
	for i in range(3 + int(power * 5.0)):
		var velocity := outward * 0.8 + Vector3(random.randf_range(-1.2, 1.2), random.randf_range(0.25, 1.0), random.randf_range(-1.2, 1.2))
		spawn_particle(origin, velocity, "dust", random.randf_range(0.6, 1.15), random.randf_range(0.2, 0.55), Color(0.46, 0.43, 0.39, 0.26))
	if enabled_sound and DisplayServer.get_name() != "headless" and not audio_players.is_empty():
		var sound := audio_players[audio_index % audio_players.size()]
		audio_index += 1
		sound.global_position = origin
		sound.volume_db = lerpf(-17.0, -3.0, power)
		sound.pitch_scale = random.randf_range(0.84, 1.12)
		sound.play()

func spawn_particle(origin: Vector3, velocity: Vector3, kind: String, lifetime: float, size: float, color: Color) -> void:
	if particles.size() >= MAX_PARTICLES:
		var oldest: Dictionary = particles.pop_front()
		if is_instance_valid(oldest.node):
			oldest.node.queue_free()
	var node := MeshInstance3D.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D
	if kind == "debris":
		node.mesh = fragment
		node.material_override = metal_material
	else:
		material = StandardMaterial3D.new()
		material.albedo_color = color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.disable_receive_shadows = true
		material.no_depth_test = false
		node.material_override = material
		if kind == "spark":
			node.mesh = spark_mesh
			material.emission_enabled = true
			material.emission = Color(1.0, 0.36, 0.06)
			material.emission_energy_multiplier = 2.0
		else:
			node.mesh = sphere
	add_child(node)
	node.global_position = origin
	node.scale = Vector3.ONE * size
	particles.append({"node": node, "velocity": velocity, "kind": kind, "life": lifetime, "total": lifetime, "size": size, "alpha": color.a, "material": material, "spin": Vector3(random.randf_range(-8.0, 8.0), random.randf_range(-8.0, 8.0), random.randf_range(-8.0, 8.0))})

func _process(delta: float) -> void:
	trauma = maxf(0.0, trauma - delta * 1.9)
	skid_clock = maxf(0.0, skid_clock - delta)
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p.life -= delta
		var node := p.node as MeshInstance3D
		if p.life <= 0.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			particles.remove_at(i)
			continue
		var kind: String = p.kind
		var velocity: Vector3 = p.velocity
		if kind == "debris" or kind == "spark":
			velocity.y -= 9.8 * delta
			node.global_position += velocity * delta
			if node.global_position.y < 0.055:
				node.global_position.y = 0.055
				if velocity.y < 0.0:
					velocity.y *= -0.28
					velocity.x *= 0.62
					velocity.z *= 0.62
			if kind == "debris":
				node.rotation += (p.spin as Vector3) * delta * minf(velocity.length(), 1.0)
				if p.life < 0.4:
					node.scale = Vector3.ONE * float(p.size) * maxf(float(p.life) / 0.4, 0.01)
			elif velocity.length_squared() > 0.02:
				node.look_at(node.global_position + velocity.normalized(), Vector3.FORWARD if absf(velocity.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP)
		else:
			velocity = velocity.move_toward(Vector3(0.18, 0.75 if kind == "smoke" else 0.35, 0.10), delta * 0.65)
			node.global_position += velocity * delta
			var growth := 1.0 + (1.0 - float(p.life) / float(p.total)) * 2.0
			node.scale = Vector3.ONE * float(p.size) * growth
		if p.material != null:
			var material := p.material as StandardMaterial3D
			var color := material.albedo_color
			color.a = float(p.alpha) * clampf(float(p.life) / float(p.total), 0.0, 1.0)
			material.albedo_color = color
		p.velocity = velocity
	for i in range(skids.size() - 1, -1, -1):
		var skid: Dictionary = skids[i]
		skid.life -= delta
		if skid.life <= 0.0:
			skid.node.queue_free()
			skids.remove_at(i)
		elif skid.life < 3.0:
			var material := skid.material as StandardMaterial3D
			var color := material.albedo_color
			color.a = float(skid.life) / 3.0 * 0.55
			material.albedo_color = color
	if is_instance_valid(vehicle) and integrity < 48.0 and vehicle.visible:
		smoke_clock -= delta
		if smoke_clock <= 0.0:
			smoke_clock = lerpf(0.11, 0.35, integrity / 48.0)
			var origin := vehicle.to_global(Vector3(0.25, 1.05, -1.32))
			var darkness := lerpf(0.14, 0.42, integrity / 48.0)
			spawn_particle(origin, Vector3(0.10, 0.8, 0.08), "smoke", random.randf_range(1.6, 2.2), 0.22, Color(darkness, darkness, darkness, 0.27))

func update_damage(value: float) -> void:
	var next_integrity := clampf(value, 0.0, 100.0)
	if absf(next_integrity - integrity) < 0.1:
		return
	integrity = next_integrity
	var damage := clampf((100.0 - integrity) / 100.0, 0.0, 1.0)
	for part in body_parts:
		var node := part.node as MeshInstance3D
		if not is_instance_valid(node):
			continue
		var original := part.mesh as Mesh
		if damage < 0.01:
			node.mesh = original
			continue
		var dented := ArrayMesh.new()
		var to_car: Transform3D = part.to_car
		var from_car := to_car.affine_inverse()
		for surface in range(original.get_surface_count()):
			var arrays := original.surface_get_arrays(surface).duplicate(true)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in range(vertices.size()):
				var v := to_car * vertices[i]
				var front := clampf((-v.z - 0.42) / 1.65, 0.0, 1.0)
				var asymmetry := 0.55 + 0.45 * clampf((v.x + 0.9) / 1.8, 0.0, 1.0)
				v.z += front * front * damage * 0.46 * asymmetry
				if v.y > 0.72:
					v.y -= front * damage * 0.15 * asymmetry
				v.x += sin(v.z * 7.2 + v.y * 9.0) * front * damage * 0.018
				vertices[i] = from_car * v
			arrays[Mesh.ARRAY_VERTEX] = vertices
			dented.add_surface_from_arrays(original.surface_get_primitive_type(surface), arrays)
			dented.surface_set_material(surface, original.surface_get_material(surface))
		node.mesh = dented

func repair() -> void:
	integrity = 100.0
	trauma = 0.0
	smoke_clock = 0.0
	last_skid_position = Vector3(9999, 9999, 9999)
	for part in body_parts:
		if is_instance_valid(part.node):
			part.node.mesh = part.mesh
	for p in particles:
		if is_instance_valid(p.node):
			p.node.queue_free()
	particles.clear()
	for skid in skids:
		if is_instance_valid(skid.node):
			skid.node.queue_free()
	skids.clear()
	for sound in audio_players:
		sound.stop()

func add_skid(position_world: Vector3, forward: Vector3) -> void:
	if skid_clock > 0.0 or last_skid_position.distance_to(position_world) < 0.48:
		return
	skid_clock = 0.04
	last_skid_position = position_world
	var direction := Vector3(forward.x, 0.0, forward.z).normalized()
	if direction.length_squared() < 0.5:
		return
	var side := direction.cross(Vector3.UP).normalized()
	for offset in [-0.88, 0.88]:
		if skids.size() >= MAX_SKIDS:
			var oldest: Dictionary = skids.pop_front()
			oldest.node.queue_free()
		var mark := MeshInstance3D.new()
		mark.mesh = skid_mesh
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.025, 0.028, 0.030, 0.55)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 1.0
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mark.material_override = material
		add_child(mark)
		mark.global_position = position_world + side * float(offset)
		mark.global_position.y = 0.085
		mark.rotation.y = atan2(direction.x, direction.z)
		skids.append({"node": mark, "material": material, "life": 16.0})

func make_crash_audio() -> AudioStreamWAV:
	# Original procedural impact: low thump, short crunches, and metal resonance.
	var sample_rate := 22050
	var frames := int(sample_rate * 0.76)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 41728
	var filtered := 0.0
	for i in range(frames):
		var t := float(i) / float(sample_rate)
		var white := noise.randf_range(-1.0, 1.0)
		filtered = filtered * 0.72 + white * 0.28
		var thump := sin(TAU * (62.0 * t - 15.0 * t * t)) * exp(-t * 14.0) * 0.55
		var crunch := (white * 0.32 + filtered * 0.5) * exp(-t * 21.0)
		crunch += white * exp(-absf(t - 0.064) * 75.0) * 0.20
		crunch += filtered * exp(-absf(t - 0.14) * 40.0) * 0.32
		var metal := (sin(TAU * 491.0 * t) * 0.05 + sin(TAU * 733.0 * t) * 0.03) * exp(-t * 9.0)
		var value := (thump + crunch + metal) * minf(t * 1000.0, 1.0)
		bytes.encode_s16(i * 2, int(clampf(value, -0.98, 0.98) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream
