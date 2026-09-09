extends SubViewportContainer

var view: SubViewport
var actor: Node3D
var stage: Node3D
var clock_time := 0.0
var city_ref: RefCounted
var identity := ""
var speaker_name := ""
var channel_label := "IN PERSON"

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	view = SubViewport.new()
	view.size = Vector2i(365,500)
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(view)
	stage = Node3D.new()
	view.add_child(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("13212b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c6d7e5")
	env.ambient_light_energy = 0.55
	environment.environment = env
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25,-25,0)
	key.light_color = Color("ffe1bc")
	key.light_energy = 1.0
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-8,145,0)
	fill.light_color = Color("89c7df")
	fill.light_energy = 0.65
	stage.add_child(fill)
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.position = Vector3(0,1.46,2.4)
	cam.look_at(Vector3(0,1.03,0))
	cam.fov = 42
	cam.current = true
	hide()

func present(city: RefCounted, speaker: String) -> void:
	city_ref = city
	speaker_name = speaker
	identity = speaker.split(" · ")[0]
	channel_label = "IN PERSON"
	if "radio" in speaker or "call" in speaker or "phone" in speaker or "missing" in speaker:
		channel_label = "VOICE ON THE LINE"
	elif "RECORDER" in speaker or "SYSTEM" in speaker:
		channel_label = "RECOVERED EVIDENCE"
	elif "letter" in speaker: channel_label = "ELI'S LETTER"
	elif "ALEX" in speaker: channel_label = "ALEX'S THOUGHTS"
	if is_instance_valid(actor): actor.queue_free()
	var color := Color("405766")
	if "MARA" in identity: color = Color("945c44")
	elif "JUNE" in identity: color = Color("5c7567")
	elif "IMANI" in identity: color = Color("c8d0cf")
	elif "RHEA" in identity: color = Color("76565c")
	elif "SEN" in identity: color = Color("364455")
	elif "ORTIZ" in identity: color = Color("846e52")
	if identity in ["RECORDER","SYSTEM"]:
		actor = Node3D.new()
		city.box(actor,Vector3(0,1.06,0),Vector3(0.92,1.2,0.35),Color("313d43"))
		city.box(actor,Vector3(0,1.29,0.20),Vector3(0.76,0.50,0.035),Color("172b30"))
		city.box(actor,Vector3(0,1.27,0.23),Vector3(0.56,0.035,0.02),Color("94d4b9"),false,0.5)
		for row in range(5):
			city.box(actor,Vector3(0,0.77+row*0.055,0.20),Vector3(0.63,0.017,0.02),Color("121b22"))
		city.cylinder(actor,Vector3(-0.30,1.89,0),0.017,0.58,Color("a8aead"))
	elif city.has_method("detailed_person"):
		actor = city.detailed_person(color,identity)
	else: actor = city.person_model(color)
	stage.add_child(actor)
	actor.position = Vector3.ZERO
	actor.rotation.y = -0.12
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	clock_time = 0
	show()

func dismiss() -> void:
	if view: view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hide()

func _process(delta: float) -> void:
	if not visible or not is_instance_valid(actor): return
	clock_time += delta
	if city_ref and city_ref.has_method("animate_person") and identity not in ["RECORDER","SYSTEM"]:
		city_ref.animate_person(actor,clock_time,true)
	else:
		actor.rotation.y = -0.12+sin(clock_time*0.6)*0.045
		actor.position.y = sin(clock_time*1.4)*0.004
