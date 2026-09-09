extends Control

var game: Node3D
var stick_id := -1
var look_id := -1
var stick_origin := Vector2.ZERO
var stick_value := Vector2.ZERO
var held := {}
var was_active := false
var factor := 1.0
var buttons := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_window().focus_exited.connect(release_all)

func active() -> bool:
	return game.touch_mode and game.mode != "menu" and not game.dialogue and not game.journal and not game.paused

func _process(_delta: float) -> void:
	factor = minf(size.x/1280.0,size.y/720.0)
	buttons = {"interact":Rect2(1090,410,150,64),"drive":Rect2(1090,485,150,64),"jump":Rect2(1090,560,150,64),"sprint":Rect2(920,560,150,64),"pause":Rect2(1170,165,70,58),"view":Rect2(920,485,150,64),"reset":Rect2(920,410,150,64)}
	if was_active and not active(): release_all()
	was_active = active()
	queue_redraw()

func _draw() -> void:
	if not active(): return
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*factor)
	var center := stick_origin if stick_id >= 0 else Vector2(160,535)
	draw_circle(center,83,Color(0.04,0.09,0.12,0.65))
	draw_arc(center,83,0,TAU,48,Color(0.94,0.76,0.48,0.8),3,true)
	draw_circle(center+stick_value*64,29,Color(0.94,0.76,0.48,0.8))
	var labels := {"interact":"TALK / QUEST","drive":"EXIT CAR" if game.driving else "ENTER CAR","jump":"BRAKE" if game.driving else "JUMP","sprint":"BOOST" if game.driving else "SPRINT","pause":"II","view":"CAMERA","reset":"RECOVER"}
	for action in buttons:
		var rect: Rect2 = buttons[action]
		draw_style_box(game.hud.style(Color(0.05,0.11,0.14,0.85)),rect)
		draw_rect(rect,Color(0.82,0.68,0.44,0.8),false,2)
		draw_string(ThemeDB.fallback_font,rect.position+Vector2(8,40),labels[action],HORIZONTAL_ALIGNMENT_CENTER,rect.size.x-16,19)
	draw_string(ThemeDB.fallback_font,Vector2(385,675),"LEFT: MOVE / STEER     RIGHT: SWIPE TO LOOK",HORIZONTAL_ALIGNMENT_CENTER,490,17,Color("edba77"))

func _input(event: InputEvent) -> void:
	if not active(): return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position/factor
		if not event.pressed:
			if event.index == stick_id:
				stick_id = -1
				set_stick(Vector2.ZERO)
			if event.index == look_id: look_id = -1
			if held.has(event.index):
				Input.action_release(held[event.index])
				held.erase(event.index)
		else:
			for action in buttons:
				if buttons[action].has_point(p):
					match action:
						"interact": game.interact()
						"drive": game.toggle_drive()
						"view": game.third_person = not game.third_person
						"reset": game.recover()
						"pause": game.paused = true
						_:
							Input.action_press(action)
							held[event.index] = action
					get_viewport().set_input_as_handled()
					return
			if p.x < 440 and p.y > 250 and stick_id < 0:
				stick_id = event.index
				stick_origin = p
			elif p.x >= 440 and look_id < 0: look_id = event.index
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == stick_id: set_stick((event.position/factor-stick_origin)/64.0)
		elif event.index == look_id:
			game.yaw -= event.relative.x/factor*0.0035
			game.pitch = clampf(game.pitch-event.relative.y/factor*0.0035,-1.25,1.05)
		get_viewport().set_input_as_handled()

func set_stick(value: Vector2) -> void:
	stick_value = value.limit_length()
	for action in ["left","right","forward","back"]: Input.action_release(action)
	if absf(stick_value.x) > 0.12: Input.action_press("right" if stick_value.x > 0 else "left",absf(stick_value.x))
	if absf(stick_value.y) > 0.12: Input.action_press("back" if stick_value.y > 0 else "forward",absf(stick_value.y))

func release_all() -> void:
	set_stick(Vector2.ZERO)
	for action in held.values(): Input.action_release(action)
	held.clear()
	stick_id = -1
	look_id = -1
