extends RefCounted

var root: Node3D
var rng := RandomNumberGenerator.new()
var mats := {}
var cars: Array = []
var pedestrians: Array = []
var talking_npcs := {}
var surface_maps := {}
const SURFACE_SHADER = preload("res://city_surface.gdshader")

func surface_material(color: Color, kind: String = "concrete") -> ShaderMaterial:
	var key := "surface/"+kind+"/"+str(color)
	if mats.has(key): return mats[key]
	if not surface_maps.has(kind): surface_maps[kind] = make_surface_map(kind)
	var m := ShaderMaterial.new()
	m.shader = SURFACE_SHADER
	m.set_shader_parameter("base_color",color)
	m.set_shader_parameter("surface_map",surface_maps[kind])
	m.set_shader_parameter("tile_scale",0.62 if kind == "brick" else 0.4)
	m.set_shader_parameter("surface_roughness",0.96 if kind == "asphalt" else 0.87)
	mats[key] = m
	return m

func make_surface_map(kind: String) -> ImageTexture:
	var img := Image.create(256,256,false,Image.FORMAT_RGB8)
	var random := RandomNumberGenerator.new()
	random.seed = 2277
	for y in 256:
		for x in 256:
			var v := random.randf_range(0.72,1.0)
			if kind == "brick":
				var row := y/32
				var col := ((x+32*(row%2))%256)/64
				var edge := ((x+32*(row%2))%64 < 3) or (y%32 < 3)
				var tint := 0.82+0.15*sin(float(row*17+col*7))
				v = 0.48 if edge else v*tint
			elif kind == "concrete":
				v = random.randf_range(0.88,1.0)
				v *= 0.94+0.06*sin(float(x)*0.08)*sin(float(y)*0.11)
				if x < 2 or y < 2: v = 0.66
			else:
				v *= 0.90+0.10*sin(float(x)*0.028)*cos(float(y)*0.033)
			img.set_pixel(x,y,Color(v,v,v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func material(color: Color, glow: float = 0.0, metallic: float = 0.0) -> StandardMaterial3D:
	var key = str(color) + str(glow) + str(metallic)
	if mats.has(key): return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.65
	m.metallic = metallic
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	mats[key] = m
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid: bool = false, glow: float = 0.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color, glow)
	mesh.position = pos
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collision.shape = box_shape
		body.add_child(collision)
		mesh.add_child(body)
	return mesh

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 10
	mesh.mesh = shape
	mesh.material_override = material(color)
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func sign_text(parent: Node3D, pos: Vector3, words: String, color: Color, size: int = 72) -> Label3D:
	var sign := Label3D.new()
	sign.text = words
	sign.position = pos
	sign.font_size = size
	sign.pixel_size = 0.013
	sign.modulate = color
	sign.outline_size = 7
	sign.no_depth_test = false
	parent.add_child(sign)
	return sign

func build(parent: Node3D) -> void:
	root = parent
	rng.seed = 48151
	box(root, Vector3(0,-0.35,0),Vector3(425,0.6,425),Color("3b4144"),true).material_override = surface_material(Color("565958"))
	# A compact, traversable grid: five avenues and five cross streets.
	for line in [-160,-80,0,80,160]:
		box(root,Vector3(line,0,0),Vector3(19,0.06,416),Color("242c34")).material_override = surface_material(Color("343a40"),"asphalt")
		box(root,Vector3(0,0.005,line),Vector3(416,0.06,19),Color("242c34")).material_override = surface_material(Color("343a40"),"asphalt")
		for s in range(-200,201,10):
			if abs(s % 80) < 12: continue
			box(root,Vector3(line,0.045,s),Vector3(0.18,0.025,4),Color("d8b97c"))
			box(root,Vector3(s,0.05,line),Vector3(4,0.025,0.18),Color("d8b97c"))
		for edge in [-10.5,10.5]:
			box(root,Vector3(line+edge,0.09,0),Vector3(2.0,0.18,420),Color("7b7d78")).material_override = surface_material(Color("82827b"))
			box(root,Vector3(0,0.095,line+edge),Vector3(420,0.18,2.0),Color("7b7d78")).material_override = surface_material(Color("82827b"))
	for x in [-160,-80,0,80,160]:
		for z in [-160,-80,0,80,160]:
			for k in range(-7,8,2):
				box(root,Vector3(x+k,0.06,z+8),Vector3(1.1,0.025,3),Color("b7bcb8"))
	var colors = [Color("806456"),Color("565c63"),Color("a4957e"),Color("74504a"),Color("62717b"),Color("8b7661")]
	for bx in [-200,-120,-40,40,120,200]:
		for bz in [-200,-120,-40,40,120,200]:
			if abs(bx) == 200 or abs(bz) == 200:
				building(Vector3(bx,0,bz),Vector3(32,rng.randf_range(30,68),32),colors[rng.randi_range(0,5)])
				continue
			for dx in [-15,15]:
				for dz in [-15,15]:
					var h := rng.randf_range(10,32)
					if bx < 0 and bz < 0: h *= 1.65
					building(Vector3(bx+dx,0,bz+dz),Vector3(25,h,25),colors[rng.randi_range(0,5)])
	# Distant skyline beyond the water.
	box(root,Vector3(0,-1.1,265),Vector3(1200,0.15,95),Color("426976"))
	for i in range(45):
		var x := rng.randf_range(-550,550)
		var h := rng.randf_range(22,110)
		box(root,Vector3(x,h/2,360+rng.randf_range(0,100)),Vector3(rng.randf_range(15,38),h,28),Color("546574"))
	# Boundary rail and promenade.
	for side in [-1,1]:
		box(root,Vector3(side*211,1.1,0),Vector3(0.45,2.2,425),Color("5e696a"),true)
		box(root,Vector3(0,1.1,side*211),Vector3(425,2.2,0.45),Color("5e696a"),true)
	for x in range(-192,193,32):
		for z in [-12,12,-172,172]:
			lamp(Vector3(x,0,z))
		for z in [-92,92]:
			tree(Vector3(x,0,z))
	for x in [-172,172]:
		for z in range(-192,193,32): tree(Vector3(x,0,z))
	landmarks()
	street_details()
	batch_static_boxes()
	for i in range(28):
		var lane: float = [-160.0,-80.0,0.0,80.0,160.0][i%5]
		var direction := 1.0 if i%2 == 0 else -1.0
		var vehicle := car(colors[i%6] if i%4 else Color("a08037"))
		var axis := (i/2)%2
		vehicle.position = Vector3(lane+direction*4.6,0,rng.randf_range(-195,195)) if axis == 0 else Vector3(rng.randf_range(-195,195),0,lane+direction*4.6)
		vehicle.rotation.y = (PI if direction > 0 else 0.0) if axis == 0 else (-PI/2 if direction > 0 else PI/2)
		root.add_child(vehicle)
		cars.append({"node":vehicle,"axis":axis,"direction":direction,"speed":rng.randf_range(8,13)})
	for i in range(40):
		var person := person_model(colors[i%6])
		person.position = Vector3(rng.randf_range(-195,195),0.2,[-12.5,12.5,-92.5,92.5,172.5,-172.5][i%6])
		person.rotation.y = PI/2 if i%2 else -PI/2
		root.add_child(person)
		pedestrians.append({"node":person,"direction":1 if i%2 else -1,"speed":rng.randf_range(0.8,1.5)})

func building(pos: Vector3, size: Vector3, color: Color) -> void:
	var wall := box(root,pos+Vector3(0,size.y/2,0),size,color,true)
	wall.material_override = surface_material(color,"brick" if size.y < 39 else "concrete")
	box(root,pos+Vector3(0,size.y+0.25,0),Vector3(size.x+0.7,0.5,size.z+0.7),color.darkened(0.35))
	box(root,pos+Vector3(0,2,0),Vector3(size.x+0.1,4,size.z+0.1),color.darkened(0.42)).material_override = surface_material(color.darkened(0.3))
	# Cornices and recessed floor lines keep the skyline from reading as plain boxes.
	for floor_y in range(4,int(size.y),8):
		box(root,pos+Vector3(0,floor_y,0),Vector3(size.x+0.2,0.18,size.z+0.2),color.darkened(0.2))
	# Street-level shops, doorframes, cornices, and projecting awnings.
	for side in [-1,1]:
		box(root,pos+Vector3(0,1.85,side*(size.z/2+0.10)),Vector3(size.x-3,2.7,0.08),Color("344e56"))
		box(root,pos+Vector3(side*(size.x/2+0.10),1.85,0),Vector3(0.08,2.7,size.z-3),Color("344e56"))
		box(root,pos+Vector3(0,3.9,side*(size.z/2+0.55)),Vector3(size.x+0.3,0.20,1.1),color.darkened(0.15))
		box(root,pos+Vector3(side*(size.x/2+0.55),3.9,0),Vector3(1.1,0.20,size.z+0.3),color.darkened(0.15))
		for col in [-8,-4,0,4,8]:
			box(root,pos+Vector3(col,1.9,side*(size.z/2+0.17)),Vector3(0.12,2.8,0.12),Color("aaa596"))
			box(root,pos+Vector3(side*(size.x/2+0.17),1.9,col),Vector3(0.12,2.8,0.12),Color("aaa596"))
		box(root,pos+Vector3(0,1.3,side*(size.z/2+0.2)),Vector3(1.3,2.6,0.1),Color("202e34"))
		box(root,pos+Vector3(0,0.25,side*(size.z/2+0.5)),Vector3(1.7,0.25,0.7),Color("8f948e"))
	box(root,pos+Vector3(3,size.y+1.1,1),Vector3(5,1.8,4),Color("555b5d"))
	if size.y < 30 and rng.randf() < 0.35:
		cylinder(root,pos+Vector3(-5,size.y+2.2,-3),1.25,3.8,Color("504d46"))
		box(root,pos+Vector3(-5,size.y+4.2,-3),Vector3(2.8,0.2,2.8),Color("333b40"))
	# Window grids are batched into one draw call per facade material.
	var lit_transforms: Array[Transform3D] = []
	var dark_transforms: Array[Transform3D] = []
	for y in range(5,int(size.y)-1,4):
		for x in range(-int(size.x/2)+3,int(size.x/2)-1,4):
			for side in [-1,1]:
				var t := Transform3D(Basis.IDENTITY.scaled(Vector3(1.8,2.1,0.08)),pos+Vector3(x,y,side*(size.z/2+0.07)))
				if rng.randf() > 0.62: lit_transforms.append(t)
				else: dark_transforms.append(t)
				var t2 := Transform3D(Basis.IDENTITY.scaled(Vector3(0.08,2.1,1.8)),pos+Vector3(side*(size.x/2+0.07),y,x))
				if rng.randf() > 0.62: lit_transforms.append(t2)
				else: dark_transforms.append(t2)
	multi_windows(lit_transforms,Color("e5bd80"),0.35)
	multi_windows(dark_transforms,Color("314853"),0)

func batch_static_boxes() -> void:
	# Group city detail by block and material. Collisions remain independent.
	var groups := {}
	for child in root.get_children():
		if not child is MeshInstance3D or not child.mesh is BoxMesh: continue
		var mesh := child as MeshInstance3D
		var cube := mesh.mesh as BoxMesh
		if cube.size.x > 65 or cube.size.z > 65: continue
		var mat: Material = mesh.material_override
		if mat == null: continue
		var key := str(mat.get_instance_id())+"/"+str(floori(mesh.position.x/80))+"/"+str(floori(mesh.position.z/80))
		if not groups.has(key): groups[key] = {"material":mat,"transforms":[]}
		groups[key].transforms.append(Transform3D(mesh.basis.scaled(cube.size),mesh.position))
		for body in mesh.get_children():
			if body is StaticBody3D:
				mesh.remove_child(body)
				root.add_child(body)
				body.transform = mesh.transform
		root.remove_child(mesh)
		mesh.free()
	for group in groups.values():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		cube.material = group.material
		mm.mesh = cube
		mm.instance_count = group.transforms.size()
		for i in mm.instance_count: mm.set_instance_transform(i,group.transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = mm
		root.add_child(instance)

func street_details() -> void:
	for x in [-160,-80,0,80,160]:
		for z in [-160,-80,0,80,160]:
			var corner := Vector3(x+11.2,0.18,z+11.2)
			cylinder(root,corner+Vector3(0,2.3,0),0.065,4.6,Color("3d454a"))
			box(root,corner+Vector3(0,3.9,-0.14),Vector3(0.34,0.92,0.3),Color("1e262b"))
			for light_index in 3:
				var bulb := cylinder(root,corner+Vector3(0,4.15-light_index*0.25,-0.31),0.09,0.02,[Color("e96b48"),Color("ba934d"),Color("45736b")][light_index])
				bulb.rotation.x = PI/2
			# Road repairs, inset drain grates, and worn tire-darkened lanes.
			box(root,Vector3(x+7,0.059,z+20),Vector3(1.2,0.015,0.55),Color("252b2e"))
			for stripe in 5:
				box(root,Vector3(x+6.55+stripe*0.23,0.074,z+20),Vector3(0.06,0.012,0.51),Color("606665"))
	for x in range(-184,185,40):
		for z in [-13.5,93.5]:
			box(root,Vector3(x,0.55,z),Vector3(1.8,0.12,0.52),Color("625140"))
			box(root,Vector3(x,0.98,z+0.21),Vector3(1.8,0.62,0.1),Color("625140"))
			for side in [-0.68,0.68]: box(root,Vector3(x+side,0.3,z),Vector3(0.09,0.52,0.48),Color("31383b"))
			cylinder(root,Vector3(x+2.4,0.65,z),0.28,0.9,Color("3d504c"))
			cylinder(root,Vector3(x+2.4,1.12,z),0.3,0.06,Color("293a39"))
	for p in [Vector3(-28,0,12.2),Vector3(42,0,-12.2),Vector3(125,0,12.2),Vector3(-113,0,92.2)]:
		cylinder(root,p+Vector3(0,0.59,0),0.13,0.82,Color("a9503b"))
		cylinder(root,p+Vector3(0,1.01,0),0.18,0.09,Color("b05b42"))
		box(root,p+Vector3(0,0.7,0),Vector3(0.47,0.13,0.16),Color("a9503b"))
	var shop_names := ["MERCER MARKET","ORIN PHARMACY","LAUNDRY  /  OPEN LATE","HARBOR COFFEE"]
	for i in 4:
		var p := Vector3(-135+i*80,3.45,12.7)
		box(root,p+Vector3(0,0,-0.08),Vector3(11,0.84,0.13),[Color("254f4a"),Color("505752"),Color("50434b"),Color("704735")][i])
		sign_text(root,p,shop_names[i],Color("e4dfd1"),32)

func multi_windows(transforms: Array[Transform3D], color: Color, glow: float) -> void:
	if transforms.is_empty(): return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = material(color,glow)
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size(): mm.set_instance_transform(i,transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	root.add_child(node)

func lamp(pos: Vector3) -> void:
	cylinder(root,pos+Vector3(0,3,0),0.08,6,Color("343d43"))
	box(root,pos+Vector3(0,6,0),Vector3(1.2,0.15,0.5),Color("ffe0a4"),false,1.5)

func tree(pos: Vector3) -> void:
	cylinder(root,pos+Vector3(0,1.6,0),0.22,3.2,Color("655040"))
	var canopy := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 2.3
	s.height = 4.8
	s.radial_segments = 9
	s.rings = 5
	canopy.mesh = s
	canopy.position = pos+Vector3(0,4.4,0)
	canopy.material_override = material(Color("657861"))
	root.add_child(canopy)

func person_model(color: Color) -> Node3D:
	return make_person(color,"",false)

func detailed_person(color: Color, identity: String = "") -> Node3D:
	return make_person(color,identity,true)

func oval(parent: Node3D, pos: Vector3, size: Vector3, color: Color, segments: int = 14) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = 8
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	node.scale = size
	parent.add_child(node)
	return node

func make_person(color: Color, identity: String, detailed: bool) -> Node3D:
	var p := Node3D.new()
	p.name = "Citizen" if identity.is_empty() else identity.replace(" ","")
	var who := identity.to_upper()
	var skin := Color("bc9278")
	var hair := Color("372e29")
	var jacket := color
	var female := who.contains("MARA") or who.contains("JUNE") or who.contains("IMANI") or who.contains("RHEA") or who.contains("ORTIZ")
	if who.contains("ALEX"):
		skin = Color("b18d73")
		hair = Color("272323")
		jacket = Color("303236")
	elif who.contains("IMANI"):
		skin = Color("775344")
		jacket = Color("c6d0c9")
	elif who.contains("MARA"):
		skin = Color("bd9b80")
		hair = Color("79746c")
		jacket = Color("764e47")
	elif who.contains("JUNE"):
		jacket = Color("436365")
		skin = Color("b08a70")
	elif who.contains("RHEA"):
		jacket = Color("766445")
		hair = Color("653c2b")
	elif who.contains("SEN"):
		skin = Color("bda58a")
		jacket = Color("414b54")
	elif who.contains("ELI"):
		jacket = Color("3b474c")
		hair = Color("42352c")
	elif who.contains("ORTIZ"):
		hair = Color("aaa49a")
		jacket = Color("786173")
	var torso := oval(p,Vector3(0,1.16,0),Vector3(0.53,0.66,0.32),jacket)
	torso.name = "Torso"
	cylinder(p,Vector3(0,1.48,0),0.068,0.16,skin)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0,1.65,0)
	p.add_child(head)
	oval(head,Vector3.ZERO,Vector3(0.285,0.37,0.28),skin,20 if detailed else 12)
	oval(head,Vector3(0,0.11,-0.038),Vector3(0.30,0.18,0.265),hair)
	if who.contains("ALEX"):
		# Cover-inspired dark wavy hair, short beard and charcoal field jacket.
		for i in range(7):
			oval(head,Vector3(-0.12+i*0.04,0.145,0.035+sin(i)*0.025),Vector3(0.09,0.10,0.16),hair)
		oval(head,Vector3(0,-0.095,0.097),Vector3(0.23,0.15,0.12),hair.lightened(0.07))
		box(p,Vector3(0,1.26,0.164),Vector3(0.10,0.29,0.015),Color("77716b"))
	if female:
		oval(head,Vector3(0,0.018,-0.098),Vector3(0.305,0.38,0.19),hair)
		if who.contains("MARA") or who.contains("IMANI"):
			oval(head,Vector3(0,0.115,-0.205),Vector3(0.14,0.14,0.16),hair)
	else:
		oval(head,Vector3(0,0.0,-0.10),Vector3(0.281,0.24,0.135),hair)
	for side in [-1,1]:
		var leg := Node3D.new()
		leg.name = "LeftLeg" if side < 0 else "RightLeg"
		leg.position = Vector3(side*0.125,0.89,0)
		p.add_child(leg)
		oval(leg,Vector3(0,-0.38,0),Vector3(0.205,0.83,0.235),Color("303840"))
		oval(leg,Vector3(0,-0.81,0.048),Vector3(0.21,0.15,0.36),Color("22292c"))
		var arm := Node3D.new()
		arm.name = "LeftArm" if side < 0 else "RightArm"
		arm.position = Vector3(side*0.265,1.37,0)
		p.add_child(arm)
		oval(arm,Vector3(side*0.035,-0.255,0),Vector3(0.16,0.61,0.19),jacket)
		oval(arm,Vector3(side*0.035,-0.565,0.007),Vector3(0.106,0.19,0.115),skin)
		if detailed:
			oval(head,Vector3(side*0.141,-0.005,-0.015),Vector3(0.044,0.083,0.055),skin)
			oval(head,Vector3(side*0.064,0.028,0.124),Vector3(0.055,0.026,0.019),Color("ddd4c3"),12)
			oval(head,Vector3(side*0.064,0.029,0.134),Vector3(0.021,0.023,0.008),Color("424c42"),12)
			oval(head,Vector3(side*0.064,0.029,0.139),Vector3(0.009,0.013,0.004),Color("1b2020"),10)
			var brow := box(head,Vector3(side*0.064,0.057,0.123),Vector3(0.059,0.009,0.011),hair)
			brow.rotation.z = side*0.08
	if detailed:
		oval(head,Vector3(0,-0.015,0.14),Vector3(0.043,0.077,0.081),skin.lightened(0.03),14)
		var mouth := oval(head,Vector3(0,-0.085,0.121),Vector3(0.067,0.013,0.017),skin.darkened(0.47),14)
		mouth.name = "Mouth"
		oval(head,Vector3(0,-0.102,0.119),Vector3(0.065,0.015,0.019),skin.darkened(0.1),14)
		box(p,Vector3(0,1.16,0.16),Vector3(0.018,0.43,0.019),jacket.darkened(0.35))
		for side in [-1,1]:
			var collar := box(p,Vector3(side*0.074,1.405,0.115),Vector3(0.095,0.125,0.025),jacket.lightened(0.12))
			collar.rotation.z = side*0.42
			box(p,Vector3(side*0.15,1.25,0.148),Vector3(0.086,0.085,0.027),jacket.darkened(0.05))
		if who.contains("IMANI") or who.contains("SEN"):
			box(p,Vector3(-0.147,1.275,0.168),Vector3(0.065,0.042,0.013),Color("c5ad6d"))
		if who.contains("MARA"):
			box(p,Vector3(0,0.995,0.159),Vector3(0.33,0.33,0.025),Color("a59885"))
	if who.contains("ALEX"):
		var envelope := box(p,Vector3(-0.35,0.72,0.14),Vector3(0.25,0.32,0.025),Color("bda581"))
		envelope.name = "EvidenceEnvelope"
		envelope.rotation.z = 0.1
	return p

func animate_person(person: Node3D, elapsed: float, talking: bool = false) -> void:
	var head := person.get_node_or_null("Head") as Node3D
	if head:
		head.rotation.y = sin(elapsed*0.8)*0.06
		head.rotation.x = sin(elapsed*1.45)*0.022
		var mouth := head.get_node_or_null("Mouth") as Node3D
		if mouth: mouth.scale.y = 0.013*(1.0+2.2*absf(sin(elapsed*11.5))) if talking else 0.013
	var torso := person.get_node_or_null("Torso") as Node3D
	if torso: torso.position.y = 1.16+sin(elapsed*1.8)*0.005
	for side in ["LeftArm","RightArm"]:
		var arm := person.get_node_or_null(side) as Node3D
		if arm: arm.rotation.x = sin(elapsed*1.6+(1.0 if side == "LeftArm" else 0.0))*(0.08 if talking else 0.02)

func get_talking_npc(identity: String, at_position: Vector3 = Vector3.INF) -> Node3D:
	var key := identity.to_upper().split("·")[0].strip_edges()
	if not talking_npcs.has(key):
		var npc := detailed_person(Color("62666a"),key)
		root.add_child(npc)
		talking_npcs[key] = npc
	if at_position != Vector3.INF: talking_npcs[key].position = at_position
	return talking_npcs[key]

func car(color: Color, police: bool = false) -> Node3D:
	var c := Node3D.new()
	box(c,Vector3(0,0.6,0),Vector3(1.9,0.58,4.1),color)
	box(c,Vector3(0,1.07,0.15),Vector3(1.65,0.6,1.85),Color("253b4b"))
	box(c,Vector3(0,1.4,0.2),Vector3(1.7,0.12,1.7),color)
	box(c,Vector3(0,0.85,-1.35),Vector3(1.85,0.08,1.3),color.lightened(0.08))
	for side in [-1,1]:
		for z in [-1.32,1.32]:
			var wheel := cylinder(c,Vector3(side*0.94,0.39,z),0.38,0.21,Color("171d23"))
			wheel.rotation.z = PI/2
			var hub := cylinder(c,Vector3(side*1.06,0.39,z),0.19,0.02,Color("939b9f"))
			hub.rotation.z = PI/2
		box(c,Vector3(side*0.64,0.68,-2.06),Vector3(0.43,0.18,0.03),Color("fff0c7"),false,1)
		box(c,Vector3(side*0.65,0.67,2.06),Vector3(0.44,0.18,0.03),Color("cf392d"),false,1)
	box(c,Vector3(0,0.37,-2.09),Vector3(1.7,0.12,0.12),Color("a1aaae"))
	box(c,Vector3(0,0.37,2.09),Vector3(1.7,0.12,0.12),Color("a1aaae"))
	if police:
		box(c,Vector3(-0.42,1.54,0),Vector3(0.65,0.16,0.3),Color("f44244"),false,1.8)
		box(c,Vector3(0.42,1.54,0),Vector3(0.65,0.16,0.3),Color("449eff"),false,1.8)
	return c

func landmarks() -> void:
	var signs = [[Vector3(-19,5,14),"MARA'S  /  DINER",Color("ffd19c")],[Vector3(146,5,16),"REYES  AUTO",Color("9fd8dc")],[Vector3(20,6,-63),"SAINT ORIN  +",Color("dbede1")],[Vector3(-100,5,-65),"RIVERSIDE / SHELTER",Color("e8c390")],[Vector3(142,6,98),"NORTHLINE / PRESS",Color("c2d2d8")],[Vector3(94,6,-63),"JUSTICE FOR ALL",Color("e0d4b8")],[Vector3(-21,8,-141),"K A D E",Color("e4c794")]]
	for item in signs: sign_text(root,item[0],item[1],item[2])
	box(root,Vector3(-20,3.1,13),Vector3(18,0.25,4),Color("864b3e"))
	for x in [-25,-20,-15]: cylinder(root,Vector3(x,0.75,16),0.6,1.5,Color("a35941"))
	# Telephone kiosk and memorial on accessible sidewalks.
	box(root,Vector3(68,1.4,13),Vector3(1.8,2.8,1.1),Color("345562"))
	box(root,Vector3(68,1.5,12.4),Vector3(1.1,1.8,0.1),Color("98c8cf"))
	sign_text(root,Vector3(68,3.2,12.3),"TELEPHONE",Color("d9e8dd"),34)
	box(root,Vector3(92,1.3,151),Vector3(8,2.6,1.4),Color("bcb3a1"),true)
	sign_text(root,Vector3(92,1.7,150.2),"WE REMEMBER\nTHE HARBOR EIGHT",Color("ecdfc0"),34)
	for x in range(89,96): cylinder(root,Vector3(x,0.25,149.6),0.09,0.5,Color("f4d1a1"))
	for i in range(5):
		box(root,Vector3(-138+i*7,1.5,-138),Vector3(5.8,3,12),Color("8d6147"),true)
	var locals := [["MARA",Vector3(-12,0,18)],["DR. IMANI",Vector3(12,0,-68)],["JUNE",Vector3(-92,0,-68)],["RHEA",Vector3(148,0,92)],["DETECTIVE SEN",Vector3(92,0,-68)],["TOMAS",Vector3(-148,0,-148)],["ELI",Vector3(-148,0,148)],["MRS. ORTIZ",Vector3(-68,0,92)]]
	for item in locals:
		get_talking_npc(item[0],item[1]+Vector3(1.8,0.2,1))

func update(delta: float, elapsed: float) -> void:
	for entry in cars:
		var c: Node3D = entry.node
		c.visible = not root.performance_mode or c.position.distance_squared_to(root.camera.position) < 12100
		var axis: int = entry.axis
		var coord: float = c.position.z if axis == 0 else c.position.x
		var cross := fposmod(coord+40,80)-40
		var red := int(elapsed/9)%2 == axis
		var stop: bool = red and abs(cross+entry.direction*14) < 2.8
		if not stop: coord += entry.direction*entry.speed*delta
		if coord > 204: coord = -204
		if coord < -204: coord = 204
		if axis == 0: c.position.z = coord
		else: c.position.x = coord
	for entry in pedestrians:
		entry.node.visible = not root.performance_mode or entry.node.position.distance_squared_to(root.camera.position) < 4900
		entry.node.position.x += entry.direction*entry.speed*delta
		if abs(entry.node.position.x) > 199: entry.direction *= -1
		if not entry.node.visible: continue
		entry.node.rotation.y = -PI/2 if entry.direction > 0 else PI/2
		entry.node.position.y = 0.2+sin(elapsed*7+entry.node.position.x)*0.025
		var swing: float = sin(elapsed*6+entry.node.position.x)*0.32
		entry.node.get_node("LeftLeg").rotation.x = swing
		entry.node.get_node("RightLeg").rotation.x = -swing
		entry.node.get_node("LeftArm").rotation.x = -swing*0.7
		entry.node.get_node("RightArm").rotation.x = swing*0.7
	for npc in talking_npcs.values():
		npc.visible = not root.performance_mode or npc.position.distance_squared_to(root.camera.position) < 6400
		if npc.visible: animate_person(npc,elapsed)

