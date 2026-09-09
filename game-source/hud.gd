extends Control

var game: Node3D
var font: Font = ThemeDB.fallback_font
var gold := Color("edba77")
var white := Color("f0eee6")
var muted := Color("a9b7bb")
var ink := Color(0.035,0.065,0.085,0.94)
var actions: Array = []
var scale_factor := 1.0
var portrait: SubViewportContainer
var cover: Texture2D = preload("res://alex_cover.png")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	portrait = SubViewportContainer.new()
	portrait.set_script(preload("res://dialogue_portrait.gd"))
	add_child(portrait)
	portrait.position = Vector2(55,113)
	portrait.size = Vector2(365,470)

func present_speaker() -> void:
	portrait.present(game.city,game.current_mission().speaker)

func hide_speaker() -> void:
	if portrait: portrait.dismiss()

func text(pos: Vector2, value: String, size: int = 20, color: Color = Color("f0eee6")) -> void:
	draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func paragraph(pos: Vector2, value: String, width: float, size: int = 20, color: Color = Color("f0eee6")) -> void:
	draw_multiline_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,width,size,-1,color)

func panel(rect: Rect2, color: Color = Color(0.035,0.065,0.085,0.94)) -> void:
	draw_style_box(style(color),rect)

func style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	return s

func button(rect: Rect2, title: String, action: String, primary: bool = false) -> void:
	var hover := rect.has_point(get_local_mouse_position()/scale_factor)
	panel(rect,gold if primary else Color("294049") if hover else Color("172a33"))
	text(rect.position+Vector2(20,rect.size.y/2+7),title,20,Color("12242d") if primary else white)
	actions.append({"rect":rect,"action":action})

func _draw() -> void:
	if not game: return
	scale_factor = minf(size.x/1280.0,size.y/720.0)
	if portrait:
		portrait.position = Vector2(55,113)*scale_factor
		portrait.size = Vector2(365,470)*scale_factor
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*scale_factor)
	actions.clear()
	if game.mode == "menu":
		draw_menu()
		return
	if not game.dialogue: draw_hud()
	if game.dialogue: draw_dialogue()
	elif game.journal: draw_journal()
	elif game.paused: draw_pause()

func draw_menu() -> void:
	draw_texture_rect(cover,Rect2(0,0,1280,720),false)
	panel(Rect2(0,0,565,720),Color(0.025,0.052,0.069,0.94))
	draw_rect(Rect2(55,61,40,3),gold)
	text(Vector2(110,70),"A CITY THAT REMEMBERS",16,gold)
	text(Vector2(50,194),"LAST",108,white)
	text(Vector2(50,293),"EXIT",108,white)
	paragraph(Vector2(57,342),"Your brother is alive.\nThe city wants him silent.",450,25,white)
	paragraph(Vector2(57,422),"An original crime thriller across seven in-game days.\nFollow the evidence. Bring each other home.",430,17,muted)
	button(Rect2(57,477,438,53),"CONTINUE STORY" if game.saved else "BEGIN STORY", "continue",true)
	button(Rect2(57,541,211,49),"FREE ROAM","free")
	button(Rect2(281,541,214,49),"NEW STORY" if game.saved else "QUIT", "new" if game.saved else "quit")
	text(Vector2(57,647),"TOUCH: LEFT STICK MOVE / RIGHT SWIPE LOOK" if game.touch_mode else "WASD MOVE  /  MOUSE LOOK  /  F DRIVE  /  V VIEW",14,muted)
	text(Vector2(57,675),"CITY EDITION 02   ·   19 STORY QUESTS",13,gold)
	text(Vector2(1053,665),"PORT MERCER",19,white)
	text(Vector2(1000,688),"CONCEPT ART / STYLIZED 3D GAME",12,white)

func draw_hud() -> void:
	panel(Rect2(26,25,392,125))
	draw_rect(Rect2(26,25,4,125),gold)
	if game.mode == "story":
		var m: Dictionary = game.current_mission()
		text(Vector2(46,50),"DAY %02d   /   PORT MERCER" % m.day,14,gold)
		text(Vector2(46,82),m.title,23)
		paragraph(Vector2(46,109),m.goal,348,16,muted)
	else:
		text(Vector2(46,50),"FREE ROAM   /   PORT MERCER",14,gold)
		text(Vector2(46,82),"The road is yours.",23)
		text(Vector2(46,109),"Courier stop: "+game.missions[maxi(game.contract,0)%19].place,15,muted)
		text(Vector2(46,133),"%d deliveries  ·  $%d earned" % [game.deliveries,game.money],14,gold)
	panel(Rect2(1016,25,238,48))
	text(Vector2(1033,55),"LAST EXIT",18,white)
	text(Vector2(1163,55),"$%d" % game.money,17,gold)
	if game.heat > 0:
		panel(Rect2(484,25,312,65),Color(0.3,0.085,0.07,0.94))
		text(Vector2(505,50),"PURSUIT   /   BREAK LINE OF SIGHT",14,Color("ffbaa1"))
		draw_rect(Rect2(505,66,268,4),Color("63372f"))
		draw_rect(Rect2(505,66,268*game.heat/100,4),Color("ec9377"))
	if not game.dialogue and not game.paused and not game.journal:
		if game.distance_to_objective() < 6:
			panel(Rect2(425,474,430,52))
			text(Vector2(449,507),("TAP TALK / QUEST  /  " if game.touch_mode else "E  /  ")+("COMPLETE DELIVERY" if game.mode == "free" else "INTERACT"),20,gold)
		elif not game.driving and game.player.position.distance_to(game.ride.position) < 5.5:
			panel(Rect2(465,474,350,52))
			text(Vector2(488,507),"TAP ENTER CAR" if game.touch_mode else "F  /  DRIVE REYES COUPE",20,gold)
		if not game.driving:
			draw_circle(Vector2(640,360),2,Color(1,1,1,0.65))
		var wp: Vector3 = game.objective_position+Vector3(0,4.6,0)
		if not game.camera.is_position_behind(wp):
			var screen: Vector2 = game.camera.unproject_position(wp)/scale_factor
			screen.x = clampf(screen.x,445,970)
			screen.y = clampf(screen.y,135,440)
			draw_circle(screen,5,gold)
			text(screen+Vector2(12,6),"%dm" % game.distance_to_objective(),15,gold)
	if game.touch_mode: return
	draw_map()
	panel(Rect2(26,595,340,99))
	text(Vector2(44,621),"CONDITION",12,muted)
	draw_rect(Rect2(132,612,211,6),Color("304550"))
	draw_rect(Rect2(132,612,211*game.integrity/100,6),Color("a4c9ba"))
	text(Vector2(44,649),"BOOST" if game.driving else "STAMINA",12,muted)
	draw_rect(Rect2(132,640,211,6),Color("304550"))
	draw_rect(Rect2(132,640,211*game.stamina/100,6),gold)
	text(Vector2(44,679),"J  JOURNAL     ESC  PAUSE     M  SOUND",12,muted)
	if game.driving:
		text(Vector2(402,653),"%03d" % int(absf(game.speed)*3.6),48,white)
		text(Vector2(508,651),"KM/H",13,gold)
		text(Vector2(402,680),"SPACE  BRAKE    SHIFT  BOOST    F  EXIT",12,white)
	else:
		text(Vector2(405,663),"SHIFT  SPRINT    SPACE  JUMP    CTRL  SLIDE",12,white)
		text(Vector2(405,685),"F  ENTER CAR    E  INTERACT    R  RECOVER",12,muted)
	if game.toast_time > 0:
		panel(Rect2(265,542,750,42),Color(0.055,0.12,0.15,0.95))
		text(Vector2(283,569),game.toast,14,gold)

func map_point(p: Vector3) -> Vector2:
	return Vector2(1123,582)+Vector2(p.x,p.z)*0.45

func draw_map() -> void:
	panel(Rect2(1016,447,238,247))
	text(Vector2(1033,471),"PORT MERCER",12,gold)
	text(Vector2(1227,471),"N",12,white)
	for street in [-160,-80,0,80,160]:
		draw_line(map_point(Vector3(street,0,-210)),map_point(Vector3(street,0,210)),Color("43545b"),5)
		draw_line(map_point(Vector3(-210,0,street)),map_point(Vector3(210,0,street)),Color("43545b"),5)
	for entry in game.city.cars: draw_circle(map_point(entry.node.position),1.3,Color("71848a"))
	var a: Vector3 = game.actor_position()
	var goal: Vector3 = game.objective_position
	var elbow := Vector3(a.x,0,goal.z)
	draw_dashed_line(map_point(a),map_point(elbow),Color(0.93,0.73,0.47,0.5),1,4)
	draw_dashed_line(map_point(elbow),map_point(goal),Color(0.93,0.73,0.47,0.5),1,4)
	draw_circle(map_point(goal),4.5,gold)
	draw_circle(map_point(game.ride.position),3.5,Color("79c6ed"))
	for cop in game.cops: draw_circle(map_point(cop.position),3,Color("ee7666"))
	var point := map_point(a)
	var heading: float = game.ride.rotation.y if game.driving else game.yaw
	var forward := Vector2(-sin(heading),-cos(heading))
	draw_circle(point,4,white)
	draw_line(point,point+forward*11,white,2)
	text(Vector2(1033,687),"GOLD  QUEST      BLUE  YOUR CAR",10,muted)

func draw_dialogue() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(0.01,0.025,0.04,0.63))
	panel(Rect2(45,72,385,581),Color(0.035,0.065,0.085,0.96))
	panel(Rect2(450,72,785,581),ink)
	draw_rect(Rect2(450,72,785,3),gold)
	var m: Dictionary = game.current_mission()
	text(Vector2(69,102),portrait.channel_label if portrait else "IN PERSON",12,gold)
	text(Vector2(70,610),m.speaker.split(" · ")[0],28,white)
	text(Vector2(70,636),"PORT MERCER  /  DAY %02d" % m.day,12,muted)
	text(Vector2(478,110),"DAY %02d     /     %s" % [m.day,m.place],14,gold)
	text(Vector2(478,151),m.title,29,white)
	text(Vector2(478,186),m.speaker,14,gold)
	var body: String = m.text if game.response.is_empty() else game.response
	paragraph(Vector2(478,224),body,724,19,white)
	if m.has("choice") and game.response.is_empty():
		button(Rect2(477,514,730,51),"1   "+m.choice[0],"choice0",true)
		button(Rect2(477,577,730,51),"2   "+m.choice[1],"choice1")
	else:
		button(Rect2(883,577,324,51),"CONTINUE   /   ENTER","advance",true)
		text(Vector2(478,608),"CHECKPOINT SAVES AFTER THIS SCENE",11,muted)

func draw_journal() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(0.01,0.025,0.04,0.78))
	panel(Rect2(145,57,990,606))
	text(Vector2(185,109),"THE MERCER FILE",34,white)
	text(Vector2(185,141),"EVIDENCE  /  PEOPLE  /  THE ROAD AHEAD",13,gold)
	if game.mode == "story":
		var m: Dictionary = game.current_mission()
		text(Vector2(185,190),"CURRENT  ·  "+m.title.to_upper(),19,gold)
		paragraph(Vector2(185,226),m.goal+"\n\n"+m.place+"  /  "+str(int(game.distance_to_objective()))+" metres away",445,19,white)
		text(Vector2(725,190),"CHAPTERS",14,muted)
		var first := maxi(0,game.mission-3)
		for i in range(first,mini(first+10,game.missions.size())):
			var color := gold if i == game.mission else muted
			var prefix := "+ " if i < game.mission else "> " if i == game.mission else "  "
			text(Vector2(725,226+(i-first)*30),prefix+"%02d  " % game.missions[i].day+game.missions[i].title,14,color)
		text(Vector2(185,365),"PEOPLE TO REMEMBER",14,gold)
		paragraph(Vector2(185,397),"Eli Reyes · your brother, a driver with a secret\nMara Salcedo · diner owner, June's mother\nJune Salcedo · a survivor building a case\nRhea · a reporter who needs proof\nDetective Sen · the law's last honest bet",470,17,muted)
	else:
		paragraph(Vector2(185,205),"Explore Port Mercer at your own pace.\n\nDrive the blue coupe, run the avenues, or complete courier deliveries at the gold markers. Each stop pays $150.\n\nCompleted deliveries: %d\nBest delivery time: %.1f seconds\n\nPress R if you need to recover your car." % [game.deliveries,game.personal_best],790,23,white)
	button(Rect2(850,591,245,45),"CLOSE   /   J","close_journal",true)
	text(Vector2(185,620),"WASD MOVE  ·  E INTERACT  ·  F DRIVE  ·  R RECOVER",13,muted)

func draw_pause() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(0.01,0.025,0.04,0.83))
	if game.finished and game.mode == "story":
		text(Vector2(170,142),"THE CITY REMEMBERS.",48,white)
		text(Vector2(174,185),"SEVEN DAYS LATER, THE ROAD IS STILL YOURS.",17,gold)
		var public_choices: int = game.choices.count(0)
		var result := "The files reach the public. The city watches the trial together." if public_choices >= 2 else "The case moves carefully through court. The witnesses remain protected."
		paragraph(Vector2(174,255),"Kade is arrested. Vale resigns. June and Mara begin again.\nEli faces the consequences of the choices he made.\n\n"+result+"\n\n"+("You keep Eli's letter, and leave room for forgiveness." if game.choices.back() == 0 else "You leave the letter behind, and begin a life of your own."),940,25,white)
		text(Vector2(174,523),"19 QUESTS COMPLETE    /    %.1f MINUTES    /    4 CHOICES" % (game.play_time/60),15,gold)
		button(Rect2(174,571,385,55),"CONTINUE IN FREE ROAM","free",true)
		button(Rect2(580,571,255,55),"MAIN MENU","menu")
	else:
		panel(Rect2(412,137,456,448))
		text(Vector2(457,205),"TAKE A BREATH.",31)
		text(Vector2(457,237),"Port Mercer will wait.",18,muted)
		button(Rect2(457,271,366,52),"RESUME","resume",true)
		button(Rect2(457,337,366,52),"SAVE & MAIN MENU","menu")
		button(Rect2(457,403,366,52),"SOUND: "+("ON" if game.sound else "OFF"),"sound")
		button(Rect2(457,469,366,52),"SAVE & QUIT","quit")

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		var p: Vector2 = event.position/scale_factor
		for entry in actions:
			if entry.rect.has_point(p):
				activate(entry.action)
				accept_event()
				break

func activate(action: String) -> void:
	match action:
		"continue": game.start_game("story",game.saved)
		"new": game.start_game("story")
		"free": game.start_game("free")
		"choice0": game.advance_dialogue(0)
		"choice1": game.advance_dialogue(1)
		"advance": game.advance_dialogue(-1)
		"menu": game.return_menu()
		"resume":
			game.paused = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if game.touch_mode else Input.MOUSE_MODE_CAPTURED
		"close_journal":
			game.journal = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if game.touch_mode else Input.MOUSE_MODE_CAPTURED
		"sound":
			game.sound = not game.sound
			AudioServer.set_bus_mute(0,not game.sound)
		"quit":
			game.save_game()
			get_tree().quit()
