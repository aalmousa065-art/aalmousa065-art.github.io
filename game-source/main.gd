extends Node3D

const City = preload("res://city.gd")
const Story = preload("res://story.gd")
const Hud = preload("res://hud.gd")
var save_path := "user://last_exit_save.json"
var city = City.new()
var missions: Array = Story.missions()
var mission := 0
var choices: Array = []
var mode := "menu"
var previous_mode := "story"
var dialogue := false
var response := ""
var journal := false
var paused := false
var finished := false
var alex_model: Node3D
var third_person := true
var touch_mode := false
var touch_controls: Control
var performance_mode := false
var sun_light: DirectionalLight3D
var player: CharacterBody3D
var ride: CharacterBody3D
var camera: Camera3D
var hud: Control
var marker: Node3D
var cops: Array = []
var yaw := 0.0
var pitch := -0.06
var driving := false
var speed := 0.0
var stamina := 100.0
var integrity := 100.0
var heat := 0.0
var elapsed := 0.0
var play_time := 0.0
var coyote := 0.0
var slide := 0.0
var bob := 0.0
var toast := ""
var toast_time := 0.0
var money := 0
var deliveries := 0
var contract := -1
var contract_timer := 0.0
var personal_best := 0.0
var saved := false
var sound := true
var police_cooldown := 0.0
var ambience: AudioStreamPlayer
var motor: AudioStreamPlayer
var objective_position := Vector3.ZERO
var auto_test := false
var screenshot_mode := false
var frame_count := 0
var crash_fx: Node3D
var impact_cooldown := 0.0
var skid_cooldown := 0.0
var wreck_timer := 0.0
var last_impact_speed := 0.0
var capture_camera_locked := false

func _ready() -> void:
	touch_mode = DisplayServer.is_touchscreen_available() or "--touch-test" in OS.get_cmdline_user_args()
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if touch_mode else Viewport.MSAA_2X
	setup_input()
	setup_environment()
	city.build(self)
	setup_player()
	apply_render_quality(OS.has_feature("web") or touch_mode)
	setup_ride()
	setup_crashes()
	setup_marker()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Control.new()
	hud.set_script(Hud)
	hud.game = self
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(hud)
	touch_controls = Control.new()
	touch_controls.set_script(preload("res://mobile_controls.gd"))
	touch_controls.game = self
	touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(touch_controls)
	setup_audio()
	auto_test = "--self-test" in OS.get_cmdline_user_args()
	if auto_test: save_path = "user://last_exit_test_save.json"
	saved = FileAccess.file_exists(save_path)
	screenshot_mode = "--capture" in OS.get_cmdline_user_args()
	if auto_test: call_deferred("self_test")
	if screenshot_mode: call_deferred("capture_preview")
	if "--playtest" in OS.get_cmdline_user_args(): call_deferred("physics_test")
	if "--crash-test" in OS.get_cmdline_user_args(): call_deferred("crash_test")
	if "--touch-test" in OS.get_cmdline_user_args(): call_deferred("touch_test")
	if "--showcase" in OS.get_cmdline_user_args(): call_deferred("capture_showcase")
	if "--turn-benchmark" in OS.get_cmdline_user_args(): call_deferred("turn_benchmark")

func apply_render_quality(fast: bool) -> void:
	performance_mode = fast
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if fast else Viewport.MSAA_2X
	get_viewport().scaling_3d_scale = 0.75 if fast else 1.0
	if sun_light: sun_light.shadow_enabled = not fast
	if camera: camera.far = 260 if fast else 850

func turn_benchmark() -> void:
	start_game("free")
	player.position = Vector3(0,0.3,24)
	for fast in [false,true]:
		apply_render_quality(fast)
		for i in 30: await RenderingServer.frame_post_draw
		var start := Time.get_ticks_msec()
		for i in 120:
			yaw = float(i)/120.0*TAU
			await RenderingServer.frame_post_draw
		var duration := Time.get_ticks_msec()-start
		print("TURN BENCHMARK ","PERFORMANCE" if fast else "DETAIL",": ",duration," ms / 120 frames")
	get_tree().quit()

func capture_showcase() -> void:
	start_game("story")
	capture_camera_locked = true
	hud.hide()
	player.position = Vector3(0,0.3,24)
	ride.position = Vector3(-4.6,0.3,25)
	yaw = PI
	camera.position = Vector3(4,2.7,33)
	camera.fov = 62
	camera.look_at(Vector3(-2,1.2,23))
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../Actual Gameplay.png")
	get_tree().quit()

func touch_test() -> void:
	save_path = "user://last_exit_touch_test.json"
	start_game("free")
	await get_tree().process_frame
	touch_controls.set_stick(Vector2(0,-1))
	var start := player.position
	await get_tree().create_timer(0.5).timeout
	assert(player.position.distance_to(start) > 1.0,"Touch stick must move the player")
	paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not Input.is_action_pressed("forward"),"Pausing must release touch movement")
	paused = false
	await get_tree().process_frame
	var tap := InputEventScreenTouch.new()
	tap.index = 1
	tap.pressed = true
	tap.position = Vector2(950,510)*touch_controls.factor
	var old_view := third_person
	touch_controls._input(tap)
	assert(third_person != old_view,"Touch camera button must change view")
	touch_controls.release_all()
	print("TOUCH TEST PASS: movement, pause release, camera button")
	get_tree().quit()

func setup_crashes() -> void:
	if ResourceLoader.exists("res://crash_fx.gd"):
		crash_fx = Node3D.new()
		crash_fx.set_script(load("res://crash_fx.gd"))
		add_child(crash_fx)
		crash_fx.setup(ride)
		crash_fx.enabled_sound = DisplayServer.get_name() != "headless"

func setup_input() -> void:
	var bindings = {"forward":[KEY_W,KEY_UP],"back":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"sprint":[KEY_SHIFT],"jump":[KEY_SPACE],"crouch":[KEY_CTRL],"interact":[KEY_E],"drive":[KEY_F],"journal":[KEY_J],"reset":[KEY_R],"mute":[KEY_M],"view":[KEY_V]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in bindings[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action,ev)

func setup_environment() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("496c8c")
	sky_material.sky_horizon_color = Color("dcc5ad")
	sky_material.ground_bottom_color = Color("283440")
	sky_material.ground_horizon_color = Color("b7987c")
	sky_material.sky_curve = 0.65
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8c9dc")
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("bba48e")
	env.fog_light_energy = 0.5
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.12
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun_light = sun
	sun.name = "LateAfternoon"
	sun.rotation_degrees = Vector3(-27,-35,0)
	sun.light_color = Color("ffd6a0")
	sun.light_energy = 1.18
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65 if touch_mode else 120
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)

func setup_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Alex"
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	player.add_child(collider)
	add_child(player)
	player.position = Vector3(0,0.3,24)
	player.floor_snap_length = 0.35
	alex_model = city.detailed_person(Color("303236"),"ALEX")
	player.add_child(alex_model)
	camera = Camera3D.new()
	camera.fov = 78
	camera.near = 0.08
	camera.far = 850
	add_child(camera)
	camera.current = true

func setup_ride() -> void:
	ride = CharacterBody3D.new()
	ride.name = "ReyesCoupe"
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.85,1.25,4.1)
	collider.shape = shape
	collider.position.y = 0.625
	ride.add_child(collider)
	if ResourceLoader.exists("res://reyes_coupe.glb"):
		ride.add_child(load("res://reyes_coupe.glb").instantiate())
	else:
		ride.add_child(city.car(Color("397995")))
	add_child(ride)
	ride.position = Vector3(-4.6,0.3,25)
	ride.floor_snap_length = 0.5

func setup_marker() -> void:
	marker = Node3D.new()
	add_child(marker)
	marker.visible = false
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.4
	mesh.outer_radius = 1.65
	mesh.rings = 20
	mesh.ring_segments = 8
	ring.mesh = mesh
	ring.material_override = city.material(Color("efb86d"),1)
	ring.position.y = 0.23
	marker.add_child(ring)
	var diamond := city.box(marker,Vector3(0,3.6,0),Vector3(0.55,0.55,0.55),Color("ffcc83"),false,1)
	diamond.rotation.z = PI/4

func setup_audio() -> void:
	if DisplayServer.get_name() == "headless": return
	if ResourceLoader.exists("res://ambient.wav"):
		ambience = AudioStreamPlayer.new()
		ambience.stream = load("res://ambient.wav")
		ambience.volume_db = -18
		add_child(ambience)
		ambience.play()
	if ResourceLoader.exists("res://motor.wav"):
		motor = AudioStreamPlayer.new()
		motor.stream = load("res://motor.wav")
		motor.volume_db = -80
		add_child(motor)
		motor.play()

func start_game(kind: String, resume: bool = false) -> void:
	if hud: hud.hide_speaker()
	recover()
	yaw = 0
	pitch = -0.06
	stamina = 100
	mode = kind
	previous_mode = kind
	dialogue = false
	journal = false
	paused = false
	if kind == "story":
		if resume: load_game()
		else:
			mission = 0
			choices.clear()
			finished = false
			money = 0
			play_time = 0
			player.position = Vector3(0,0.3,24)
			show_toast("DAY 01 / THE DEAD STILL CALL     ·     Meet Mara at the gold marker.",7)
	else:
		show_toast("FREE ROAM     ·     F near the blue coupe to drive. E at a gold marker for courier work.",8)
		contract = 0
		contract_timer = 0
	heat = 0
	clear_cops()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if touch_mode else Input.MOUSE_MODE_CAPTURED
	update_objective()

func current_mission() -> Dictionary:
	return missions[clampi(mission,0,missions.size()-1)]

func update_objective() -> void:
	if mode == "story": objective_position = current_mission().p
	elif mode == "free": objective_position = missions[maxi(contract,0)%missions.size()].p
	marker.position = objective_position
	marker.visible = mode != "menu" and not finished or mode == "free"

func actor_position() -> Vector3:
	return ride.position if driving else player.position

func distance_to_objective() -> float:
	var a := actor_position()
	a.y = 0
	return a.distance_to(objective_position)

func _unhandled_input(event: InputEvent) -> void:
	if auto_test or screenshot_mode: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		apply_render_quality(not performance_mode)
		show_toast("Graphics: Performance" if performance_mode else "Graphics: Detail")
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not paused and not dialogue and not journal:
		yaw -= event.relative.x*0.0022
		pitch = clampf(pitch-event.relative.y*0.0022,-1.25,1.05)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if mode == "menu": return
			if dialogue: return
			if journal:
				journal = false
			else: paused = not paused
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
		if event.keycode == KEY_ENTER:
			if mode == "menu": start_game("story",saved)
			elif dialogue: advance_dialogue(-1)
		if dialogue:
			if event.keycode == KEY_1: advance_dialogue(0)
			if event.keycode == KEY_2: advance_dialogue(1)
			return
	if mode == "menu" or paused or dialogue: return
	if event.is_action_pressed("journal"):
		journal = not journal
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if journal else Input.MOUSE_MODE_CAPTURED
	if journal: return
	if event.is_action_pressed("view"): third_person = not third_person
	if event.is_action_pressed("drive"): toggle_drive()
	if event.is_action_pressed("interact"): interact()
	if event.is_action_pressed("reset"): recover()
	if event.is_action_pressed("mute"):
		sound = not sound
		AudioServer.set_bus_mute(0,not sound)
		show_toast("Sound on" if sound else "Sound muted")

func _physics_process(delta: float) -> void:
	elapsed += delta
	if alex_model:
		alex_model.visible = third_person and not driving and mode != "menu"
		alex_model.rotation.y = yaw+PI
		city.animate_person(alex_model,elapsed,false)
		var stride := sin(bob)*minf(player.velocity.length()/12.0,0.6)
		alex_model.get_node("LeftLeg").rotation.x = stride
		alex_model.get_node("RightLeg").rotation.x = -stride
	frame_count += 1
	if mode == "menu":
		var angle := sin(elapsed*0.025)*0.2
		camera.position = Vector3(8+sin(angle)*38,62,125+cos(angle)*8)
		camera.look_at(Vector3(-25,14,-50))
		city.update(delta,elapsed)
		return
	if paused or dialogue or journal: return
	if capture_camera_locked: return
	impact_cooldown = maxf(0,impact_cooldown-delta)
	skid_cooldown = maxf(0,skid_cooldown-delta)
	if wreck_timer > 0:
		wreck_timer -= delta
		speed = 0
		update_camera(delta)
		if wreck_timer <= 0: recover()
		return
	play_time += delta
	if mode == "free": contract_timer += delta
	city.update(delta,elapsed)
	if driving: drive_update(delta)
	else:
		ride.velocity = Vector3(0,maxf(-8,ride.velocity.y-25*delta),0)
		ride.move_and_slide()
		walk_update(delta)
	traffic_collisions(delta)
	police_update(delta)
	if integrity <= 0:
		wreck_timer = 3.5
		show_toast("VEHICLE DISABLED     ·     Recovering to Mara's garage...",4)
	if crash_fx: crash_fx.update_damage(integrity)
	marker.get_child(1).rotation.y += delta
	marker.get_child(1).position.y = 3.6+sin(elapsed*2)*0.25
	update_camera(delta)
	if motor:
		motor.volume_db = -22 if driving else -80
		motor.pitch_scale = 0.65+absf(speed)/25

func _process(delta: float) -> void:
	toast_time = maxf(0,toast_time-delta)
	if hud: hud.queue_redraw()

func walk_update(delta: float) -> void:
	var input := Input.get_vector("left","right","forward","back")
	var dir := Basis(Vector3.UP,yaw)*Vector3(input.x,0,input.y)
	var running := Input.is_action_pressed("sprint") and stamina > 4 and input.length() > 0.1
	var crouching := Input.is_action_pressed("crouch")
	var pace := 10.0 if running else 5.5
	if crouching: pace = 3.0
	if running: stamina = maxf(0,stamina-16*delta)
	else: stamina = minf(100,stamina+22*delta)
	if player.is_on_floor(): coyote = 0.13
	else: coyote -= delta
	if Input.is_action_just_pressed("jump") and coyote > 0:
		player.velocity.y = 7
		coyote = 0
	if Input.is_action_just_pressed("crouch") and player.velocity.length() > 8 and player.is_on_floor(): slide = 0.65
	if slide > 0:
		slide -= delta
		pace = 13*maxf(0.45,slide/0.65)
		dir = -Basis(Vector3.UP,yaw).z
	var acceleration := 32.0 if player.is_on_floor() else 9.0
	player.velocity.x = move_toward(player.velocity.x,dir.x*pace,acceleration*delta)
	player.velocity.z = move_toward(player.velocity.z,dir.z*pace,acceleration*delta)
	player.velocity.y -= 21*delta
	player.move_and_slide()
	if player.position.y < -8: recover()
	bob += delta*player.velocity.length()*1.5

func drive_update(delta: float) -> void:
	var throttle := Input.get_action_strength("forward")-Input.get_action_strength("back")
	var steering := Input.get_action_strength("left")-Input.get_action_strength("right")
	var braking := Input.is_action_pressed("jump")
	var boost := Input.is_action_pressed("sprint") and stamina > 2
	var limit := 40.0 if boost else 29.0
	if boost and throttle > 0:
		stamina = maxf(0,stamina-22*delta)
	else: stamina = minf(100,stamina+13*delta)
	if throttle > 0: speed = move_toward(speed,limit,(15 if boost else 10)*delta)
	elif throttle < 0: speed = move_toward(speed,-12,20*delta)
	else: speed = move_toward(speed,0,3*delta)
	if braking: speed = move_toward(speed,0,24*delta)
	ride.rotation.y += steering*minf(absf(speed)/7,1.0)*(1.8 if braking else 1.1)*delta*signf(speed)
	var target := -ride.transform.basis.z*speed
	ride.velocity.x = move_toward(ride.velocity.x,target.x,(15 if braking else 40)*delta)
	ride.velocity.z = move_toward(ride.velocity.z,target.z,(15 if braking else 40)*delta)
	ride.velocity.y -= 25*delta
	var old_velocity := ride.velocity
	ride.move_and_slide()
	if ride.get_slide_collision_count() > 0:
		for i in ride.get_slide_collision_count():
			var c := ride.get_slide_collision(i)
			var closing_speed := maxf(0,-old_velocity.dot(c.get_normal()))
			if absf(c.get_normal().y) < 0.5 and closing_speed > 3:
				register_crash(c.get_position(),c.get_normal(),closing_speed)
				speed *= 0.35
				ride.velocity += c.get_normal()*minf(closing_speed*0.13,3)
				break
	if braking and absf(speed) > 7 and skid_cooldown <= 0 and crash_fx:
		crash_fx.add_skid(ride.position+ride.transform.basis.z*1.3,-ride.transform.basis.z)
		skid_cooldown = 0.065
	player.position = ride.position+Vector3(0,2.7,0)
	if old_velocity.length() > 48: speed = 38

func update_camera(delta: float) -> void:
	if driving:
		var forward := -ride.global_transform.basis.z
		var focus := ride.position+Vector3(0,1.8,0)
		var desired := focus-forward*7.8+Vector3(0,3.1,0)
		var query := PhysicsRayQueryParameters3D.create(focus,desired)
		query.exclude = [ride.get_rid(),player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): desired = hit.position+hit.normal*0.3
		camera.position = camera.position.lerp(desired,1-exp(-7*delta))
		camera.look_at(focus+forward*4)
		camera.fov = lerpf(camera.fov,78+absf(speed)*0.25,delta*3)
	else:
		var eye := 1.0 if Input.is_action_pressed("crouch") or slide > 0 else 1.68
		var sway := sin(bob)*0.035 if player.is_on_floor() else 0.0
		camera.position = player.position+Vector3(0,eye+sway,0)
		camera.rotation = Vector3(pitch,yaw,0)
		if third_person:
			var focus := player.position+Vector3(0,1.5,0)
			var desired := focus+Basis(Vector3.UP,yaw)*Vector3(0.65,1.0,4.3)
			var query := PhysicsRayQueryParameters3D.create(focus,desired)
			query.exclude = [player.get_rid()]
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty(): desired = hit.position+hit.normal*0.25
			camera.position = desired
			camera.look_at(focus+Basis(Vector3.UP,yaw)*Vector3(0,pitch*3,-3))
		camera.fov = lerpf(camera.fov,85 if Input.is_action_pressed("sprint") else 78,delta*5)
	if crash_fx and crash_fx.trauma > 0.01:
		var shake: float = crash_fx.trauma*crash_fx.trauma
		camera.position += camera.basis.x*sin(elapsed*47)*shake*0.14
		camera.position += camera.basis.y*sin(elapsed*59)*shake*0.09
		camera.rotate_object_local(Vector3.FORWARD,sin(elapsed*41)*shake*0.012)

func toggle_drive() -> void:
	if driving:
		if absf(speed) > 3:
			show_toast("Slow down before stepping out.")
			return
		var exit_pos := ride.position+ride.transform.basis.x*2.4+Vector3(0,0.2,0)
		var query := PhysicsRayQueryParameters3D.create(ride.position+Vector3(0,1,0),exit_pos+Vector3(0,1,0))
		query.exclude = [ride.get_rid(),player.get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): exit_pos = ride.position-ride.transform.basis.x*2.4+Vector3(0,0.2,0)
		driving = false
		player.set_collision_layer_value(1,true)
		player.set_collision_mask_value(1,true)
		player.position = exit_pos
		player.velocity = Vector3.ZERO
		yaw = ride.rotation.y
		pitch = -0.05
		speed = 0
	else:
		if player.position.distance_to(ride.position) > 5.5:
			show_toast("Your blue coupe is marked on the map. Get closer and press F.")
			return
		driving = true
		player.set_collision_layer_value(1,false)
		player.set_collision_mask_value(1,false)
		show_toast("WASD drive · Space brake · Shift boost · F exit when stopped",5)

func traffic_collisions(delta: float) -> void:
	for entry in city.cars:
		var other: Node3D = entry.node
		var dist := actor_position().distance_to(other.position)
		if driving and dist < 2.8:
			var away := (ride.position-other.position).normalized()
			var traffic_velocity := Vector3.ZERO
			if int(entry.axis) == 0: traffic_velocity.z = entry.direction*entry.speed
			else: traffic_velocity.x = entry.direction*entry.speed
			var closing_speed := maxf(0,-(ride.velocity-traffic_velocity).dot(away))
			if closing_speed > 3:
				register_crash((ride.position+other.position)*0.5+Vector3(0,0.6,0),away,closing_speed)
				speed *= 0.5
			ride.position += away*delta*4
			ride.velocity += away*delta*20
		elif not driving and dist < 1.65:
			player.velocity += (player.position-other.position).normalized()*delta*45
			integrity -= delta*8

func register_crash(contact: Vector3, normal: Vector3, closing_speed: float) -> void:
	if closing_speed < 3 or impact_cooldown > 0: return
	impact_cooldown = 0.6
	last_impact_speed = closing_speed
	var severity := clampf(closing_speed/32,0.08,1)
	integrity = maxf(0,integrity-(3+severity*severity*45))
	if crash_fx:
		crash_fx.impact(contact,normal,severity)
		crash_fx.update_damage(integrity)
	if severity > 0.3: show_toast("IMPACT  /  %d km/h     ·     Condition %d%%     ·     R to repair & recover" % [closing_speed*3.6,integrity],4)

func spawn_cops() -> void:
	clear_cops()
	var a := actor_position()
	var road_x := clampf(roundf(a.x/80)*80,-160,160)
	var road_z := clampf(roundf(a.z/80)*80,-160,160)
	for i in 2:
		var cop := city.car(Color("deded4"),true)
		add_child(cop)
		cop.position = Vector3(road_x+4.6,0.15,clampf(road_z+70*(1 if i == 0 else -1),-198,198))
		cops.append(cop)
	police_cooldown = 7

func clear_cops() -> void:
	for cop in cops: cop.queue_free()
	cops.clear()

func police_update(delta: float) -> void:
	if heat <= 0: return
	police_cooldown = maxf(0,police_cooldown-delta)
	var nearest := 999.0
	var a := actor_position()
	for cop in cops:
		var p: Vector3 = cop.position
		var target: Vector3 = a
		var gx := roundf(p.x/80)*80
		var gz := roundf(p.z/80)*80
		# Travel to junctions before changing roads, rather than crossing buildings.
		if absf(p.x-gx) < 7:
			if absf(p.z-gz) < 2 and absf(a.x-p.x) > 28: target = Vector3(a.x,0,gz+4.6)
			else: target = Vector3(gx+4.6,0,a.z)
		else: target = Vector3(a.x,0,gz+4.6)
		var direction := target-p
		direction.y = 0
		if direction.length() > 2:
			cop.position += direction.normalized()*delta*(12 if driving else 4.2)
			cop.rotation.y = lerp_angle(cop.rotation.y,atan2(-direction.x,-direction.z),delta*5)
		var distance := a.distance_to(cop.position)
		nearest = minf(nearest,distance)
		if distance < 4: integrity -= delta*7
	if police_cooldown <= 0:
		if nearest > 35: heat = maxf(0,heat-delta*6)
		else: heat = maxf(0,heat-delta*0.65)
	if heat == 0:
		clear_cops()
		show_toast("PURSUIT LOST     ·     The streets are clear.",5)

func interact() -> void:
	if finished and mode == "story": return
	if distance_to_objective() > 6:
		show_toast("Follow the gold diamond. Your destination is on the map.")
		return
	if driving and absf(speed) > 2:
		show_toast("Stop the car to interact.")
		return
	if mode == "free":
		money += 150
		deliveries += 1
		if personal_best == 0 or contract_timer < personal_best: personal_best = contract_timer
		show_toast("DELIVERY COMPLETE  +$150     ·     %.1fs     ·     Next courier stop marked." % contract_timer,5)
		contract = (maxi(contract,0)+5)%missions.size()
		contract_timer = 0
		update_objective()
		return
	if heat > 0 and current_mission().kind == "escape":
		show_toast("Lose the pursuit first. Put distance between you and the patrols.",4)
		return
	dialogue = true
	response = ""
	hud.present_speaker()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func advance_dialogue(choice: int) -> void:
	var m := current_mission()
	if m.has("choice") and response.is_empty():
		if choice < 0: return
		choices.append(choice)
		response = m.responses[choice]
		return
	dialogue = false
	hud.hide_speaker()
	if m.has("heat"):
		heat = float(m.heat)
		spawn_cops()
	mission += 1
	money += 200
	if mission >= missions.size():
		finished = true
		mission = missions.size()
		paused = true
		marker.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		update_objective()
		var next := current_mission()
		if next.day != m.day: show_toast("DAY %02d     /     %s" % [next.day,next.title.to_upper()],6)
		else: show_toast("CHAPTER COMPLETE  +$200     ·     " + next.title,5)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if touch_mode else Input.MOUSE_MODE_CAPTURED
	save_game()

func show_toast(message: String, duration: float = 3.0) -> void:
	toast = message
	toast_time = duration

func recover() -> void:
	if crash_fx: crash_fx.repair()
	wreck_timer = 0
	impact_cooldown = 0
	if driving: toggle_drive_force()
	player.position = Vector3(0,0.3,24)
	player.velocity = Vector3.ZERO
	ride.position = Vector3(-4.6,0.3,25)
	ride.rotation = Vector3.ZERO
	ride.velocity = Vector3.ZERO
	speed = 0
	integrity = 100
	heat = 0
	clear_cops()
	show_toast("BACK AT MARA'S     ·     Car repaired. Your current quest is still active.",6)

func toggle_drive_force() -> void:
	driving = false
	player.set_collision_layer_value(1,true)
	player.set_collision_mask_value(1,true)

func save_game() -> void:
	if screenshot_mode: return
	if mode != "story": return
	var file := FileAccess.open(save_path,FileAccess.WRITE)
	if not file:
		show_toast("Save unavailable. Keep the game open to retain this session.")
		return
	file.store_string(JSON.stringify({"version":1,"mission":mission,"choices":choices,"money":money,"time":play_time,"finished":finished}))
	saved = true

func load_game() -> void:
	if not FileAccess.file_exists(save_path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary: return
	mission = clampi(int(data.get("mission",0)),0,missions.size())
	choices = data.get("choices",[])
	money = int(data.get("money",0))
	play_time = float(data.get("time",0))
	finished = bool(data.get("finished",false))
	if finished:
		mode = "free"
		contract = 0
		show_toast("Story complete. Welcome back to the city.",5)
	else: show_toast("CHECKPOINT LOADED     ·     " + current_mission().title,5)

func return_menu() -> void:
	hud.hide_speaker()
	save_game()
	mode = "menu"
	paused = false
	journal = false
	dialogue = false
	marker.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func self_test() -> void:
	# End-to-end state checks run in the actual engine; no save files are touched.
	start_game("story")
	for i in missions.size():
		var text_size := ThemeDB.fallback_font.get_multiline_string_size(missions[i].text,HORIZONTAL_ALIGNMENT_LEFT,724,19)
		assert(text_size.y < 280 if missions[i].has("choice") else text_size.y < 340,"Dialogue overflows speaker panel")
		assert(mission == i,"Story progression lost a chapter")
		player.position = missions[i].p
		heat = 0
		interact()
		assert(dialogue,"Quest could not be opened")
		if current_mission().has("choice"):
			advance_dialogue(i%2)
			assert(not response.is_empty(),"Choice response missing")
		advance_dialogue(-1)
		if i == 8:
			var expected_money := money
			mission = 0
			money = 0
			load_game()
			assert(mission == 9 and money == expected_money,"Checkpoint save/load failed")
	assert(finished,"Ending unreachable")
	assert(choices.size() == 4,"Choices not recorded")
	start_game("free")
	player.position = objective_position
	interact()
	assert(deliveries == 1,"Courier delivery failed")
	player.position = ride.position+Vector3(2,0,0)
	toggle_drive()
	assert(driving,"Car entry failed")
	toggle_drive()
	assert(not driving,"Car exit failed")
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("LAST EXIT SELF TEST PASS: 19 quests, 4 choices, checkpoint save/load, ending, free roam delivery, car entry/exit")
	get_tree().quit()

func crash_test() -> void:
	screenshot_mode = true
	start_game("free")
	assert(crash_fx != null,"Crash effects not loaded")
	assert(not crash_fx.body_parts.is_empty(),"Car body deformation targets missing")
	player.position = ride.position+Vector3(2,0,0)
	toggle_drive()
	ride.rotation.y = PI/2
	Input.action_press("forward")
	await get_tree().create_timer(2.2).timeout
	Input.action_release("forward")
	assert(crash_fx.impact_count > 0,"Wall impact did not trigger crash effects")
	assert(integrity < 100,"Wall impact caused no damage")
	var counter: int = crash_fx.impact_count
	register_crash(ride.position,Vector3.UP,0.5)
	assert(crash_fx.impact_count == counter,"Resting contact incorrectly creates crashes")
	impact_cooldown = 0
	register_crash(ride.position+Vector3(0,0.8,0),Vector3.UP,32)
	assert(crash_fx.impact_count == counter+1,"Hard impact not recorded")
	assert(crash_fx.particles.size()>0 and crash_fx.particles.size()<=96,"Crash debris not generated or not bounded")
	recover()
	assert(integrity == 100 and wreck_timer == 0,"Recovery failed to repair damage")
	print("LAST EXIT CRASH PASS: real wall collision, impact damage, effect trigger, no resting-contact spam, repair")
	get_tree().quit()

func physics_test() -> void:
	screenshot_mode = true
	start_game("free")
	await get_tree().create_timer(0.3).timeout
	# Every objective must have space for the player's collision capsule.
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.7
	query.shape = shape
	query.exclude = [player.get_rid(),ride.get_rid()]
	for m in missions:
		query.transform = Transform3D(Basis.IDENTITY,m.p+Vector3(0,1.15,0))
		assert(get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"Blocked objective: "+m.title)
	player.position = Vector3(0,0.3,40)
	var origin := player.position
	Input.action_press("forward")
	await get_tree().create_timer(1).timeout
	Input.action_release("forward")
	assert(player.position.distance_to(origin) > 4,"Walking input failed")
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	await get_tree().create_timer(0.2).timeout
	assert(player.position.y > 0.65,"Jump physics failed")
	await get_tree().create_timer(1).timeout
	ride.position = Vector3(-4.6,0.3,80)
	player.position = Vector3(0,0.3,25)
	yaw = PI/2
	Input.action_press("forward")
	await get_tree().create_timer(3).timeout
	Input.action_release("forward")
	assert(player.position.x > -12.3 and player.position.x < -8,"Building collision failed")
	recover()
	player.position = ride.position+Vector3(2,0,0)
	toggle_drive()
	var car_origin := ride.position
	Input.action_press("forward")
	await get_tree().create_timer(2).timeout
	Input.action_release("forward")
	assert(ride.position.distance_to(car_origin) > 8,"Driving movement failed")
	Input.action_press("jump")
	await get_tree().create_timer(2).timeout
	Input.action_release("jump")
	assert(absf(speed) < 0.1,"Brake did not stop car")
	heat = 50
	spawn_cops()
	for cop in cops: cop.position = Vector3(160,0,160)
	police_cooldown = 0
	police_update(9)
	assert(heat == 0,"Pursuit cannot be escaped")
	print("LAST EXIT PHYSICS PASS: all objectives accessible, walking, jump, building collision, driving, braking, pursuit escape")
	get_tree().quit()

func capture_preview() -> void:
	await get_tree().create_timer(2).timeout
	get_viewport().get_texture().get_image().save_png("res://../Title Screen.png")
	start_game("story")
	player.position = objective_position
	interact()
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png("res://../Story Preview.png")
	start_game("free")
	player.position = ride.position+Vector3(2,0,0)
	toggle_drive()
	ride.position = Vector3(-4.6,0.3,35)
	await get_tree().create_timer(3).timeout
	get_viewport().get_texture().get_image().save_png("res://../Preview.png")
	if crash_fx:
		capture_camera_locked = true
		integrity = 30
		camera.position = ride.position+Vector3(4.8,3.3,-6.8)
		camera.look_at(ride.position+Vector3(0,0.7,0))
		crash_fx.update_damage(integrity)
		crash_fx.impact(ride.position+Vector3(0,0.9,-1.6),Vector3(0,0.5,1),0.85)
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://../Crash Preview.png")
	print("CAPTURE COMPLETE; rendering FPS: ",Engine.get_frames_per_second())
	get_tree().quit()

