extends Control

const SIGN_FONT = preload("res://assets/ui/fonts/overpass.ttf")
const PRINT_SOURCE = preload("res://assets/ui/fonts/public_sans.ttf")
const MONO = preload("res://assets/ui/fonts/plex_mono.ttf")
const HAND = preload("res://assets/ui/fonts/caveat.ttf")
const FIELD = preload("res://assets/ui/fonts/architects_daughter.ttf")
const LCD = preload("res://assets/ui/fonts/dseg14.ttf")
const Documents = preload("res://scripts/desk_paper.gd")
const CabControls = preload("res://scripts/cab_controls.gd")
const ShopAccount = preload("res://scripts/shop_account.gd")

const WHITE := Color("#e8ebe0")
const INK := Color("#323e3d")
const BLUE := Color("#375067")
const LINES := Color("#84918a")
const DARK := Color("#1c292b")
const PAPER := Color("#e1dfcd")
const RUBBER := Color(0.075, 0.09, 0.09, 0.83)
const OXBLOOD := Color("#662c31")
const CREAM := Color("#ede0bb")
const AMBER := Color("#eabe76")
const STICK_RADIUS := 90.0
const THUMB_WIDTH := 130.0
const THUMB_GAP := 12.0
const HUD_MARGIN := 20.0
const TOP_ROW_Y := 16.0
const TOP_ROW_HEIGHT := 94.0

var desk
var docs := Documents.new()
var hit_boxes: Array[Dictionary] = []
var hud_panels: Array[Rect2] = []
var hover := ""
var stick_center := Vector2.ZERO
var dim: Vector2
var unit := 1.0
var scaled: FontVariation
var subtle: FontVariation
var print_face: FontVariation
var drawn: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scaled = FontVariation.new()
	scaled.base_font = SIGN_FONT
	scaled.variation_opentype = { "weight": 735 }
	subtle = FontVariation.new()
	subtle.base_font = SIGN_FONT
	subtle.variation_opentype = { "weight": 570 }
	print_face = FontVariation.new()
	print_face.base_font = PRINT_SOURCE
	print_face.variation_opentype = { "weight": 440 }
	resized.connect(queue_redraw)

func to_page(point: Vector2) -> Vector2:
	return point / unit

func hit_at(point: Vector2) -> String:
	for i in range(hit_boxes.size() - 1, -1, -1):
		if (hit_boxes[i].rect as Rect2).has_point(point):
			return str(hit_boxes[i].id)
	return ""

# Compare a world-camera projection with the controls and gauges actually drawn
# at this aspect ratio. Captions, pedals and the clipboard can cover a sighting.
func covers_world_point(screen_fraction: Vector2) -> bool:
	var at := screen_fraction * dim
	for panel in hud_panels:
		if panel.has_point(at): return true
	return not hit_at(at).is_empty()

func key_choices() -> Array:
	var options := []
	for entry in hit_boxes:
		if not entry.id in options:
			options.append(entry.id)
	return options

func hit(id: String, r: Rect2) -> void:
	hit_boxes.append({"id":id, "rect":r})

func text(at: Vector2, value: String, font: Font, px: int, colour: Color, width: float = -1.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font, at, value, align, width, px, colour, TextServer.JUSTIFICATION_NONE)

func multiline(at: Vector2, value: String, font: Font, px: int, colour: Color, width: float, lines: int = -1, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_multiline_string(font, at, value, align, width, px, lines, colour, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE, TextServer.JUSTIFICATION_NONE)

func fitted(r: Rect2, value: String, font: Font, px: int, colour: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	while px > 12 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > r.size.x:
		px -= 1
	text(Vector2(r.position.x, r.get_center().y + font.get_ascent(px) * 0.38), value, font, px, colour, r.size.x, align)

func rule(x: float, y: float, width: float, colour: Color = LINES, weight: float = 1.0) -> void:
	draw_line(Vector2(x,y), Vector2(x+width,y), colour, weight, true)

# The clipped rim and two bevels catch light like the cab's molded switch caps.
func switch_face(r: Rect2, fill: Color, pressed: bool = false) -> void:
	var a := r.position
	var b := r.end
	var k := 5.0
	var rim := PackedVector2Array([a+Vector2(k,0),Vector2(b.x-k,a.y),
		Vector2(b.x,a.y+k),b-Vector2(0,k),b-Vector2(k,0),
		Vector2(a.x+k,b.y),Vector2(a.x,b.y-k),a+Vector2(0,k)])
	draw_colored_polygon(rim,fill)
	var light := Color(0.88,0.85,0.72,0.56)
	var shadow := Color(0.045,0.05,0.047,0.90)
	draw_polyline(PackedVector2Array([rim[6],rim[7],rim[0],rim[1],rim[2]]),shadow if pressed else light,1.5,true)
	draw_polyline(PackedVector2Array([rim[2],rim[3],rim[4],rim[5],rim[6]]),light if pressed else shadow,2.5,true)

func _bolt(at: Vector2) -> void:
	draw_circle(at,3.2,Color("#282929"),true,-1,true)
	draw_circle(at-Vector2(0,0.6),2.4,Color("#978e78"),true,-1,true)
	draw_line(at-Vector2(1.5,-0.7),at+Vector2(1.5,-0.7),DARK,1.2,true)

func button(id: String, r: Rect2, caption: String, dark: bool = false) -> void:
	var down: bool = desk._is_down(id)
	var focus: bool = hover == id or down
	var type_size := 23 if desk.is_touch_mode() else 18
	if desk.page == "pause":
		# The truck log uses ruled entries with a protruding index tab.
		var ink := OXBLOOD if dark else INK
		draw_rect(r, Color("#d7cfb1") if focus else Color("#dedac7"))
		draw_rect(Rect2(r.position.x,r.position.y,5,r.size.y),ink)
		rule(r.position.x,r.end.y-1,r.size.x,ink)
		fitted(r.grow_individual(-23,0,-44,0),caption,scaled,type_size,ink,HORIZONTAL_ALIGNMENT_LEFT)
		_arrow(Vector2(r.end.x-24,r.get_center().y),10,ink,true)
	elif desk.page == "radio" or id in ["settings_30","settings_60"]:
		# The radio's push keys and the settings selectors sit in recessed sockets.
		switch_face(r,Color("#313732"),true)
		var cap := r.grow(-4)
		if down:
			cap.position.y += 2
		switch_face(cap,Color("#525446") if focus else Color("#42473f"),down)
		var lamp := Rect2(cap.position+Vector2(8,7),Vector2(19,5))
		draw_rect(lamp,AMBER if (dark or focus) else Color("#808575"))
		fitted(cap.grow(-5),caption,scaled,type_size,CREAM)
	else:
		# A printed double rule gives the paper actions the edge of an ink stamp.
		var ink := OXBLOOD if dark else BLUE
		draw_rect(r,Color("#c9bda4") if focus else Color("#d6d0bc"))
		draw_rect(r.grow(-1),ink,false,2.0)
		draw_rect(r.grow(-4),ink,false,1.0)
		fitted(r.grow(-6),caption,scaled,type_size,ink)
	hit(id, r)

func _draw() -> void:
	if not desk or not scaled:
		return
	unit = maxf(0.01, minf(size.y / 600.0, size.x / 790.0))
	dim = size / unit
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * unit)
	hit_boxes.clear()
	hud_panels.clear()
	drawn = desk.state
	match desk.page:
		"title":
			_title()
		"pause", "guidance", "help", "options", "yard_recovery":
			_menu()
		"":
			_hud()
		_:
			if desk.glance:
				_hud()
				_glance()
			else:
				_documents()

func _title_background() -> void:
	var shade := Color("#0d1720")
	var edge := Color(shade,0.67)
	draw_polygon(PackedVector2Array([Vector2.ZERO,Vector2(dim.x*0.7,0),Vector2(dim.x*0.7,dim.y),Vector2(0,dim.y)]), PackedColorArray([edge, Color(shade,0), Color(shade,0), edge]))

func _title() -> void:
	_title_background()
	var w := clampf(dim.x * 0.42, 335.0, 458.0)
	var x := clampf(dim.x * 0.060, 28, 115)
	var y := dim.y * 0.25
	var r := Rect2(x, y, w, 175)
	switch_face(Rect2(r.position+Vector2(2,4),r.size),Color("#262828"))
	switch_face(r,OXBLOOD)
	draw_rect(r.grow(-7),CREAM,false,1.2)
	text(Vector2(x+24,y+35),"TAMARACK COUNTY",MONO,14,CREAM)
	text(Vector2(x+w-134,y+35),"WISCONSIN",MONO,14,CREAM,109,HORIZONTAL_ALIGNMENT_RIGHT)
	rule(x+22,y+48,w-44,CREAM)
	fitted(Rect2(x+21,y+49,w-42,78),"24 HR TOWING",scaled,73,CREAM)
	draw_rect(Rect2(x+8,y+124,w-16,36),CREAM)
	rule(x+8,y+164,w-16,CREAM,2)
	fitted(Rect2(x+20,y+124,w-40,36),"BRANDT TOWING & RECOVERY",scaled,20,OXBLOOD)
	for dx in [13.0,w-13.0]:
		_bolt(Vector2(x+dx,y+14))
		_bolt(Vector2(x+dx,y+153))
	var touch: bool = desk.is_touch_mode()
	var play := Rect2(x, y+198, maxf(246,w*0.65), 80 if touch else 49)
	var down: bool = desk._is_down("play")
	switch_face(play,Color("#272c29"),true)
	switch_face(play.grow(-3),CREAM if hover == "play" or down else AMBER,down)
	var key_at := Vector2(play.position.x+(35 if touch else 28),play.get_center().y)
	_ignition(key_at,1.17 if touch else 0.94,down)
	fitted(play.grow_individual(-65 if touch else -53,0,-9,0), "Continue route" if drawn.get("has_save", false) else "Start engine", scaled, 28 if touch else 22, DARK,HORIZONTAL_ALIGNMENT_LEFT)
	hit("play", play)
	_title_link("help", Vector2(x,play.end.y+16), "Operator guide")
	_title_link("options", Vector2(x+(188 if touch else 147),play.end.y+16), "Settings")

func _ignition(at: Vector2, scale_factor: float, down: bool) -> void:
	draw_set_transform(at*unit,0.40 if down else -0.28,Vector2.ONE*unit*scale_factor)
	draw_circle(Vector2.ZERO,17.0,Color("#423e33"),true,-1,true)
	draw_circle(Vector2.ZERO,14.5,Color("#c6c1ab"),true,-1,true)
	draw_arc(Vector2.ZERO,13.3,PI,TAU,28,Color("#f5ead1"),1.7,true)
	draw_circle(Vector2.ZERO,10.8,Color("#666858"),true,-1,true)
	draw_line(Vector2(-7,0),Vector2(7,0),DARK,4,true)
	draw_line(Vector2(-2,-1),Vector2(9,4),Color("#dbd4bd"),4.0,true)
	var bow := PackedVector2Array([Vector2(7,1),Vector2(15,0),Vector2(23,6),Vector2(20,13),Vector2(12,13),Vector2(5,7)])
	draw_colored_polygon(bow,Color("#29312f"))
	draw_line(bow[0],bow[1],Color("#788171"),1.5,true)
	draw_circle(Vector2(17,7),2.3,Color("#b7ad89"),true,-1,true)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*unit)

func _title_link(id: String, at: Vector2, label: String) -> void:
	var touch: bool = desk.is_touch_mode()
	var r := Rect2(at,Vector2(176,78) if touch else Vector2(134,39))
	switch_face(r,Color("#4a453a") if hover == id else RUBBER,desk._is_down(id))
	fitted(r.grow(-6), label, subtle, 23 if touch else 18, CREAM)
	hit(id,r)

func _menu() -> void:
	if not desk.started:
		_title_background()
	draw_rect(Rect2(Vector2.ZERO,dim), Color(0.035,0.05,0.06,0.67))
	var width := minf(730, dim.x-52)
	var touch: bool = desk.is_touch_mode()
	var height := 506 if touch else 452
	var p := Rect2((dim.x-width)*0.5,(dim.y-height)*0.5,width,height)
	switch_face(p.grow(9),Color("#533f32"))
	_sheet(p,PAPER)
	draw_line(p.position+Vector2(16,0),Vector2(p.position.x+16,p.end.y),Color("#b99283"),1.3)
	var x := p.position.x+28
	var y := p.position.y+28
	text(Vector2(x,y), "BRANDT TOWING & RECOVERY   /   ESKER, WIS.", MONO, 12, BLUE)
	var heading: String = {"pause":"Truck log","guidance":"Directions & next action","options":"Cab settings","help":"Operator guide","yard_recovery":"Recover to yard?"}[desk.page]
	text(Vector2(x,y+47),heading,scaled,40,INK)
	rule(x,y+62,width-56,OXBLOOD,2.5)
	rule(x,y+67,width-56,OXBLOOD)
	match desk.page:
		"pause":
			var row := 88 if touch else 68
			var button_height := 78 if touch else 52
			if drawn.get("in_cab",false) and drawn.get("truck_stopped",false):
				var resume_width := (width-68)*.58
				button("close",Rect2(x,y+91,resume_width,button_height),"Return to work",true)
				button("cab_heat",Rect2(x+resume_width+12,y+91,width-68-resume_width,button_height),"Heater & window")
			else:
				button("close",Rect2(x,y+91,width-56,button_height),"Return to work",true)
			button("guidance", Rect2(x,y+91+row,width-56,button_height),"Directions & next action")
			var half := (width-56-12)*0.5
			button("help", Rect2(x,y+91+row*2,half,button_height),"Operator guide")
			button("yard_recovery", Rect2(x+half+12,y+91+row*2,half,button_height),"Stuck? Recover to yard")
			button("options", Rect2(x,y+109+row*3,half,button_height),"Cab settings")
			button("title", Rect2(x+half+12,y+109+row*3,half,button_height),"Title screen")
		"yard_recovery":
			var charge := ShopAccount.YARD_RECOVERY_PRICE
			text(Vector2(x,y+105),"COUNTY GARAGE   /   WRECKER CALL",MONO,15,BLUE)
			var trip := "The county will bring you and the wrecker back to Brandt’s yard."
			if drawn.get("recovery_restarts_job",false):
				trip += " Contract %04d restarts at the original scene." % drawn.job.number
			if drawn.get("fuel_eta",0) > 0:
				trip += " Dispatch will cancel the fuel delivery."
			multiline(Vector2(x,y+150),trip,print_face,23,INK,width-56)
			multiline(Vector2(x,y+239),"The tow costs $%.2f. Any unpaid balance comes out of your next county payments. Completed slips and notes stay in your log." % charge,print_face,21,INK,width-56)
			var half := (width-68)*0.5
			var h := 78 if touch else 52
			var top := p.end.y-28-h
			button("close",Rect2(x,top,half,h),"Cancel")
			button("confirm_yard_recovery",Rect2(x+half+12,top,half,h),"Recover   ·   $%.2f" % charge,true)
		"guidance":
			_guidance(Vector2(x,y+98),width-56)
			button("close",Rect2(x,p.end.y-(100 if touch else 68),148,78 if touch else 44),"Back")
		"options":
			text(Vector2(x,y+112), "FRAME RATE", MONO, 14, BLUE)
			var current: int = int(drawn.get("frame_rate",desk.fps))
			button("settings_30",Rect2(x,y+136,166,78 if touch else 52), "30 FPS", current==30)
			button("settings_60",Rect2(x+178,y+136,166,78 if touch else 52), "60 FPS", current==60)
			var height_key := 78 if touch else 52
			button("settings_voice",Rect2(x,y+225,width-56,height_key),"Dialogue   /   %s" % ("Spoken" if drawn.get("spoken",false) else "Radio chatter"))
			button("settings_anchors",Rect2(x,y+(311 if touch else 291),width-56,height_key),"Suggested tow eyes   /   %s" % ("On" if drawn.get("suggested_anchors",true) else "Off"))
			button("close",Rect2(x,p.end.y-(91 if touch else 67),155,height_key),"Back")
		"help":
			var line_y := y+94
			var entries: Array
			if desk.is_touch_mode():
				entries = [["DRIVE","Hold either side of the wheel to steer. Hold GAS to accelerate."],["BRAKE / REV","Hold the brake to stop. Press it again from rest to back up."],["CAMERA","Tap CAB VIEW or CHASE VIEW to switch while driving."],["ON FOOT","Stop and tap EXIT CAB. Walk with the pad. Drag to look."],["SIDE PANEL","Hold WINCH to reel. Release it to let tension ease."],["DISPATCH","Tap RADIO to take a call or report a sighting."],["PAPER","PLAT and SLIP open a lap view while moving."]]
			else:
				entries = [["W A S D","Drive or walk. Use the mouse to look around."],["E","Step out, climb aboard, or use the point you face."],["SPACE","Brake in the cab. Hold at the side panel to winch."],["R   /   T","R opens the cab radio. T asks Arlene for directions."],["M   /   J","Open the plat book or tow slip. Press again to stow."],["C","Switch between chase and cab view while driving."],["ESC","Put down a document or open the truck log."]]
			for entry in entries:
				text(Vector2(x,line_y),entry[0],MONO,15,BLUE)
				text(Vector2(x+132,line_y),entry[1],print_face,17,INK)
				rule(x,line_y+11,width-56,Color("#b4b7a9"))
				line_y += 34 if entries.size() > 6 else 39
			button("close",Rect2(x,y+344,148,78 if touch else 44),"Back")

func _sheet(p: Rect2, colour: Color) -> void:
	draw_rect(Rect2(p.position+Vector2(5,8),p.size), Color(0,0,0,0.4))
	draw_rect(Rect2(p.position+Vector2(2,3),p.size), colour.darkened(.25))
	draw_rect(p,colour)
	rule(p.position.x+1,p.position.y+1,p.size.x-2,colour.lightened(0.2))
	rule(p.position.x+1,p.end.y-2,p.size.x-2,colour.darkened(0.17))

func _documents() -> void:
	draw_rect(Rect2(Vector2.ZERO,dim),Color(0.035,0.05,0.06,0.68))
	var width := minf(846,dim.x-58)
	var touch: bool = desk.is_touch_mode()
	var tab_height := 80 if touch else 36
	var top := (dim.y-486)*0.5-(tab_height*0.5 if touch else 9.0)
	var p := Rect2((dim.x-width)*0.5,top,width,486)
	docs.paint(self,p,desk.page,drawn)
	if desk.page in ["cab_heat","deputy_call"]:
		button("close",Rect2(p.end.x-180,p.end.y,180,tab_height),"Back to cab" if desk.page == "cab_heat" else "End call",true)
		return
	if desk.page in ["west_custody","coffee","bulk_pump","reserve_transfer","checked_tape","storage_tag","register_card","impound_register"]:
		button("close",Rect2(p.end.x-148,p.end.y,148,tab_height),"Hang up" if desk.page == "bulk_pump" else "Step away",true)
		return
	# Labeled tabs project beyond the paper's bottom edge.
	var tabs := [["slip","Slip"],["map","Plat book"],["radio","Radio"],["fax","Fax"],["parts","Shop"]]
	if desk.page == "map":
		tabs[1] = ["turn_plat","‹ Esker sheet" if desk.east_sheet else "East sheet ›"]
	if not str(drawn.get("custody_text","")).is_empty():
		tabs.append(["custody","Custody"])
	if drawn.get("field_available",false):
		tabs.append(["field","Field book"])
	var tab_x := p.position.x+8
	var tab_gap := 6 if touch else 3
	var stow_width := 94 if touch else 90
	var touch_tab_width := (p.end.x-stow_width-tab_x)/tabs.size()-tab_gap
	for tab in tabs:
		var width_tab := touch_tab_width if touch else maxf(77,print_face.get_string_size(tab[1],HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+24)
		var tab_box := Rect2(tab_x,p.end.y,width_tab,tab_height)
		var active: bool = desk.page == tab[0]
		draw_rect(tab_box,AMBER if hover == tab[0] else (CREAM if active else Color("#bcb79f")))
		rule(tab_x+3,tab_box.end.y-4,width_tab-6,OXBLOOD if active else Color("#8a876f"),4 if active else 1)
		fitted(tab_box.grow(-3),tab[1],subtle,22 if touch else 17,INK)
		hit(tab[0],tab_box)
		tab_x+=width_tab+tab_gap
	button("close",Rect2(p.end.x-stow_width,p.end.y,stow_width,tab_height),"Stow",true)

func _glance() -> void:
	var width := minf(353, dim.x*.38)
	if desk.is_touch_mode():
		var controls_width := HUD_MARGIN + 2*THUMB_WIDTH + THUMB_GAP
		width = minf(width, dim.x-2*(controls_width+12))
	var p := Rect2((dim.x-width)*0.5,dim.y-183,width,160)
	draw_set_transform(Vector2(p.position.x,p.position.y)*unit, -0.024, Vector2.ONE*unit)
	docs.glance(self,Rect2(0,0,p.size.x,p.size.y),desk.page,drawn)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE*unit)
	hit("close",p)

func _guidance(at: Vector2, width: float) -> void:
	var route: Dictionary = desk.road_note
	if not route.is_empty():
		at.y += _guidance_entry(at,width,route.title,route.instruction,route.get("maneuver",""))
	var title := str(drawn.get("hint_title",""))
	var instruction := str(drawn.get("hint_action",""))
	if instruction.is_empty():
		title = str(drawn.get("job",{}).get("title","Recovery procedure"))
		instruction = str(drawn.get("progress",""))
	if not instruction.is_empty():
		at.y += _guidance_entry(at,width,title,instruction)
	var prompt := str(drawn.get("prompt",""))
	if not prompt.is_empty() and prompt != instruction:
		var label := "Nearby action   /   USE" if desk.is_touch_mode() else "Nearby action   /   E"
		if drawn.get("work_available",false):
			label = "Winch control"
		_guidance_entry(at,width,label,prompt)

func _guidance_entry(at: Vector2, width: float, title: String, instruction: String, maneuver := "") -> float:
	text(at,title.to_upper(),MONO,15,OXBLOOD)
	var inset := 49.0 if not maneuver.is_empty() else 0.0
	var body := at + Vector2(inset,7)
	if not maneuver.is_empty():
		_pencil_arrow(body+Vector2(-28,16),maneuver)
	multiline(body+Vector2(0,subtle.get_ascent(21)),instruction,subtle,21,INK,width-inset)
	var bottom := 7 + maxf(32,subtle.get_multiline_string_size(instruction,HORIZONTAL_ALIGNMENT_LEFT,width-inset,21).y)
	rule(at.x,at.y+bottom+8,width,Color("#b4b7a9"))
	return bottom+34

func _recovery_levers() -> void:
	var width := minf(365,dim.x-32.)
	var rect := Rect2((dim.x-width)*.5,dim.y-112,width,70)
	draw_rect(rect,RUBBER)
	draw_rect(rect,Color("#ad9a76"),false,1.4)
	fitted(Rect2(rect.position+Vector2(8,3),Vector2(width-16,30)),str(drawn.get("boom_instruction",drawn.get("drum_instruction",""))),subtle,20,CREAM)
	var keys := "↑  RAISE    →  SWING IN    ↓  LOWER" if desk.is_touch_mode() else "W  RAISE    D  SWING IN    S  LOWER"
	if drawn.has("drum_instruction"):
		keys = "←  CHECK    ↑  MAIN    ↓  PAY OUT" if desk.is_touch_mode() else "A  CHECK    W  MAIN    S  PAY OUT"
	fitted(Rect2(rect.position+Vector2(8,34),Vector2(width-16,27)),keys,MONO,15,AMBER)
	hud_panels.append(rect)

func _pencil_arrow(center: Vector2, maneuver: String) -> void:
	var stem := PackedVector2Array()
	var head := PackedVector2Array()
	match maneuver:
		"left", "right":
			var side := 1 if maneuver == "right" else -1
			stem = PackedVector2Array([Vector2(-8*side,14),Vector2(-8*side,-1),Vector2(-5*side,-6),Vector2(13*side,-7)])
			head = PackedVector2Array([Vector2(5*side,-14),Vector2(14*side,-7),Vector2(6*side,1)])
		"around":
			stem = PackedVector2Array([Vector2(10,14),Vector2(10,-5),Vector2(7,-12),Vector2(1,-15),Vector2(-6,-13),Vector2(-10,-7),Vector2(-10,6)])
			head = PackedVector2Array([Vector2(-16,-1),Vector2(-10,8),Vector2(-3,0)])
		"ahead":
			stem = PackedVector2Array([Vector2(-1,15),Vector2(0,-13)])
			head = PackedVector2Array([Vector2(-9,-5),Vector2(0,-15),Vector2(8,-6)])
	for stroke: PackedVector2Array in [stem,head]:
		for i in stroke.size():
			stroke[i] += center
		draw_polyline(stroke,BLUE,3.6,true)

func _hud() -> void:
	if drawn.get("tower_glasses",false):
		_field_glasses()
	if drawn.has("boom_instruction") or drawn.has("drum_instruction"): _recovery_levers()
	if drawn.has("ice_line"):
		var meter := Rect2(dim.x*.5-87.,dim.y*.64-39.,174,34)
		draw_rect(meter,RUBBER)
		draw_rect(meter,Color("#ac9c7e"),false,1.)
		fitted(meter.grow(-3),drawn.ice_line,MONO,16,AMBER)
		hud_panels.append(meter)
	if not drawn.get("in_cab",true):
		draw_circle(dim*0.5,1.7,Color(0.08,0.11,0.13,0.70))
		draw_circle(dim*0.5,1.0,Color(0.92,0.95,0.90,0.82))
	var feedback := str(drawn.get("feedback",""))
	if not feedback.is_empty() and not desk.glance:
		var line_width := minf(dim.x-180,580)
		var size_prompt := 19
		var length := minf(line_width,subtle.get_string_size(feedback,HORIZONTAL_ALIGNMENT_LEFT,-1,size_prompt).x)
		var box := Rect2((dim.x-length)*.5-10,dim.y*.555,length+20,33)
		hud_panels.append(box)
		draw_rect(box, Color(0.045,0.065,0.07,0.77))
		draw_rect(Rect2(box.position,Vector2(2,box.size.y)),AMBER)
		fitted(box.grow(-4),feedback,subtle,size_prompt,WHITE)
	var words: String = str(drawn.get("subtitle","")).strip_edges()
	if not words.is_empty() and not desk.glance:
		var available := minf(665,dim.x-90)
		var line_height := subtle.get_multiline_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,available-30,18).y
		var height := maxf(73,32+line_height)
		var top := TOP_ROW_Y+TOP_ROW_HEIGHT+10 if desk.is_touch_mode() else dim.y-24-height
		var box := Rect2((dim.x-available)*0.5,top,available,height)
		hud_panels.append(box)
		draw_rect(box,Color(0.035,0.048,0.055,0.86))
		draw_rect(Rect2(box.position,Vector2(3,box.size.y)),AMBER)
		var who := str(drawn.get("speaker","DISPATCH")).to_upper()
		text(box.position+Vector2(15,17),who,MONO,13,AMBER)
		multiline(box.position+Vector2(15,39),words,subtle,18,WHITE,box.size.x-30)
	if not str(drawn.get("readable_fire_plate","")).is_empty() and not desk.is_touch_mode():
		var read_key := Rect2(16,60,197,36)
		hud_panels.append(read_key)
		draw_rect(read_key,RUBBER)
		var plate := Rect2(read_key.position+Vector2(3,3),Vector2(77,30))
		draw_rect(plate,Color("#254e40"))
		draw_rect(plate.grow(-1),CREAM,false,1.0)
		fitted(plate,drawn.readable_fire_plate,scaled,21,WHITE)
		fitted(Rect2(plate.end.x+3,read_key.position.y,111,36),"G   Check plat",subtle,16,WHITE)
	if drawn.get("in_cab",true):
		_driving_view()
		if drawn.get("passenger_drop",false) and not desk.is_touch_mode():
			var latch := Rect2(16,16,205,36)
			draw_rect(latch,RUBBER)
			fitted(latch,"E   Let the passenger out",subtle,17,WHITE)
	if not desk.is_touch_mode() and (drawn.get("tower_height",-1.0) >= 0.0 or drawn.get("tower_action","") == "tower_ladder"):
		_ladder_keys()
	if desk.is_touch_mode():
		_mobile()
		if drawn.get("work_available",false) and not drawn.get("in_cab",true):
			_tension_dial()
	if drawn.has("milk_load") and (drawn.get("work_available",false) or drawn.get("in_cab",false) or drawn.get("phase","") == "loaded"):
		_milk_load_dial(drawn.milk_load)

const TOWER_LABELS := {"tower_ladder":"LADDER","tower_off":"STEP OFF","tower_glass":"GLASSES","tower_lower":"LOWER","tower_note":"NOTE RING"}

func _ladder_keys() -> void:
	var action := str(drawn.get("tower_action",""))
	var controls := "" if action == "tower_ladder" else ("S   Descend" if drawn.get("tower_top",false) else "W / S   Climb")
	if TOWER_LABELS.has(action):
		var verb := "Take ladder" if action == "tower_ladder" else str(drawn.prompt)
		controls += ("     " if not controls.is_empty() else "") + "E   " + verb
	var width := subtle.get_string_size(controls,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x + 24
	var box := Rect2(16,16,width,36)
	hud_panels.append(box)
	draw_rect(box,RUBBER)
	fitted(box.grow(-5),controls,subtle,17,WHITE)

func _field_glasses() -> void:
	# The rubber eyecups frame the real county view. Leave the middle clear.
	var radius := Vector2(dim.x*.48,dim.y*.46)
	for side: float in [-1.0,1.0]:
		var lip := PackedVector2Array()
		for step in 65:
			var angle := PI*step/64.
			var x := cos(angle)
			var y := sin(angle)*(.90+.15*absf(x))
			lip.append(dim*.5 + Vector2(x*radius.x,side*y*radius.y))
		var brim := lip.duplicate()
		var edge_y := 0.0 if side < 0.0 else dim.y
		brim.append(Vector2(0,dim.y*.5))
		brim.append(Vector2(0,edge_y))
		brim.append(Vector2(dim.x,edge_y))
		brim.append(Vector2(dim.x,dim.y*.5))
		draw_colored_polygon(brim,Color("#101417"))
		draw_polyline(lip,Color("#44494a"),4,true)
	# A magnetic scale floats below the sight line in the lower lens.
	var heading := float(drawn.get("glass_bearing",0))
	var bearing := posmod(roundi(heading/45.0),8)
	var compass := "%s   %03d°" % [["N","NE","E","SE","S","SW","W","NW"][bearing],posmod(roundi(heading),360)]
	var plate := Rect2(dim.x*.5-59,dim.y*.91,118,28)
	draw_rect(plate,Color("#101417"))
	fitted(plate,compass,MONO,18,CREAM)

func _driving_view() -> void:
	var chase: bool = drawn.get("driving_view","chase") == "chase"
	var right := dim.x-HUD_MARGIN
	var destination := "CAB VIEW" if chase else "CHASE VIEW"
	var camera_box: Rect2
	if desk.is_touch_mode():
		camera_box = Rect2(right-TOP_ROW_HEIGHT-THUMB_GAP-140,TOP_ROW_Y,140,TOP_ROW_HEIGHT)
		_control("camera",camera_box,destination)
	else:
		camera_box = Rect2(right-165,16,165,37)
		hud_panels.append(camera_box)
		switch_face(camera_box,RUBBER)
		var key := Rect2(camera_box.position+Vector2(6,5),Vector2(27,26))
		switch_face(key,CREAM)
		fitted(key,"C",scaled,18,DARK)
		fitted(camera_box.grow_individual(-37,-2,-6,-2), "Switch to cab" if chase else "Switch to chase",subtle,17,WHITE)
	var compass := Rect2(camera_box.position.x-101,maxf(6, camera_box.get_center().y-(36 if chase else 20)),92,41)
	hud_panels.append(compass)
	_dash_compass(compass)
	if chase:
		var meter := Rect2(compass.position.x,compass.end.y+1,92,49)
		hud_panels.append(meter)
		switch_face(meter,Color("#292d29"),true)
		draw_rect(meter.grow(-4),Color("#151b18"))
		fitted(Rect2(meter.position+Vector2(7,1),Vector2(42,29)),"%d" % roundi(absf(float(drawn.get("speed_mph",0)))),LCD,23,AMBER,HORIZONTAL_ALIGNMENT_RIGHT)
		fitted(Rect2(meter.position+Vector2(53,2),Vector2(32,27)),"MPH",MONO,13,CREAM)
		var tank := clampf(float(drawn.get("fuel",1.0)),0.0,1.0)
		var fuel_ink := Color("#f79775") if tank <= 0.15 else AMBER
		fitted(Rect2(meter.position+Vector2(6,28),Vector2(80,16)),"FUEL  %d%%" % ceili(tank*100.0),MONO,12,fuel_ink)

func _dash_compass(box: Rect2) -> void:
	switch_face(box,Color("#42443d"))
	draw_rect(box.grow(-4),Color("#171e1b"))
	var center := box.get_center()
	var degrees := fposmod(float(drawn.get("heading_degrees", 0.0)), 360.0)
	fitted(Rect2(box.position+Vector2(6,1),Vector2(38,25)),str(drawn.get("heading","N")),scaled,21,CREAM)
	fitted(Rect2(box.position+Vector2(44,1),Vector2(42,25)),"%03d°" % posmod(roundi(degrees),360),MONO,14,CREAM)
	# Marks travel past the fixed orange lubber line as the truck turns.
	for i in range(floori(degrees/5.0)-5, ceili(degrees/5.0)+6):
		var x := center.x + (i*5.0 - degrees)*1.65
		if absf(x-center.x) > 35:
			continue
		draw_line(Vector2(x,box.end.y-8),Vector2(x,box.end.y-(15 if posmod(i,3)==0 else 12)),CREAM,1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(center.x-4,box.end.y-4),Vector2(center.x,box.end.y-11),Vector2(center.x+4,box.end.y-4)]),AMBER)

func _mobile() -> void:
	var left := HUD_MARGIN
	for tab in [["radio","RADIO"],["map","PLAT"],["slip","SLIP"]]:
		_control(tab[0],Rect2(left,TOP_ROW_Y,118,TOP_ROW_HEIGHT),tab[1])
		left+=118+THUMB_GAP
	var right := dim.x-HUD_MARGIN
	var bottom := dim.y-HUD_MARGIN
	if not str(drawn.get("readable_fire_plate","")).is_empty():
		var read := Rect2(right-THUMB_WIDTH*2-THUMB_GAP,bottom-164-THUMB_GAP-96,THUMB_WIDTH,96)
		_control("read_fire_plate",read,"")
		var plate := Rect2(read.position+Vector2(13,15),Vector2(read.size.x-26,36))
		draw_rect(plate,Color("#254e40"))
		draw_rect(plate.grow(-1),CREAM,false,1.2)
		fitted(plate,drawn.readable_fire_plate,scaled,23,WHITE)
		fitted(Rect2(read.position+Vector2(3,54),Vector2(read.size.x-6,28)),"CHECK PLAT",scaled,16,CREAM)
	_control("pause",Rect2(right-TOP_ROW_HEIGHT,TOP_ROW_Y,TOP_ROW_HEIGHT,TOP_ROW_HEIGHT),"")
	if drawn.get("in_cab",true):
		# The wheel is one piece of hardware with independent left/right touch zones.
		var left_rim := Rect2(HUD_MARGIN,bottom-178,THUMB_WIDTH+THUMB_GAP/2,178)
		var right_rim := Rect2(left_rim.end.x,left_rim.position.y,left_rim.size.x,left_rim.size.y)
		CabControls.wheel(self,left_rim.merge(right_rim),desk._is_down("steer_l"),desk._is_down("steer_r"))
		hit("steer_l",left_rim)
		hit("steer_r",right_rim)
		var pedal_x := right-THUMB_WIDTH
		var brake_x := pedal_x-THUMB_GAP-THUMB_WIDTH
		var stopped: bool = drawn.get("truck_stopped",true)
		var reversing: bool = desk._is_down("reverse")
		var reverse_label: bool = reversing or (stopped and not desk.brake_held())
		_control("gas",Rect2(pedal_x,bottom-164,THUMB_WIDTH,164),"GAS")
		_control("brake",Rect2(brake_x,bottom-130,THUMB_WIDTH,130),"REVERSE" if reverse_label else "BRAKE")
		if drawn.get("aux_lamps",false):
			_control("spot",Rect2(HUD_MARGIN,bottom-178-THUMB_GAP-94,132,94),"SPOT ON" if drawn.get("spot_on",false) else "SPOT OFF")
		if stopped:
			_control("interact",Rect2(pedal_x,bottom-164-THUMB_GAP-96,THUMB_WIDTH,96),"LET OUT" if drawn.get("passenger_drop",false) else "EXIT CAB")
	else:
		stick_center = Vector2(HUD_MARGIN+STICK_RADIUS,bottom-STICK_RADIUS)
		draw_circle(stick_center,STICK_RADIUS,RUBBER)
		draw_arc(stick_center,STICK_RADIUS-1,0,TAU,48,Color("#a29b85"),2,true)
		draw_arc(stick_center,STICK_RADIUS-13,0,TAU,48,Color(0.75,0.71,0.59,0.24),1.3,true)
		if drawn.get("tower_height",-1.0) >= 0.0:
			fitted(Rect2(stick_center-Vector2(52,86),Vector2(104,28)),"CLIMB",scaled,18,CREAM)
			fitted(Rect2(stick_center+Vector2(-52,57),Vector2(104,28)),"DESCEND",scaled,16,CREAM)
		var thumb: Vector2 = stick_center + desk._stick*(STICK_RADIUS-33)
		draw_circle(thumb,31,Color("#706b59"),true,-1,true)
		draw_arc(thumb,29,PI,TAU,24,CREAM,1.7,true)
		for i in [-1,0,1]:
			rule(thumb.x-11,thumb.y+i*5,22,Color("#47453a"),1.6)
		hit("stick",Rect2(stick_center-Vector2.ONE*STICK_RADIUS,2*Vector2.ONE*STICK_RADIUS).grow(8))
		var use_label := "WIPE" if drawn.get("can_wipe",false) else ("INSPECT" if drawn.get("can_inspect_sighting",false) else "USE")
		if not str(drawn.get("visit_action","")).is_empty():
			use_label = drawn.visit_action
		if drawn.has("boom_instruction") or drawn.has("drum_instruction"): use_label = "LET GO"
		var tower_action := str(drawn.get("tower_action",""))
		if TOWER_LABELS.has(tower_action):
			use_label = TOWER_LABELS[tower_action]
		if drawn.get("tower_height",-1.0) < 0.0 or not tower_action.is_empty():
			_control("interact",Rect2(right-144,bottom-112,144,112),"ENTER CAB" if drawn.get("can_enter_cab",false) else use_label)
		if drawn.get("work_available",false):
			_control("work",Rect2(right-144,bottom-112-THUMB_GAP-106,144,106),"WINCH")

func stick_input(point: Vector2) -> Vector2:
	return ((point-stick_center)/(STICK_RADIUS*0.85)).limit_length()

func _control(id: String, r: Rect2, caption: String) -> void:
	var pressed: bool = desk._is_down(id) or (id == "brake" and desk._is_down("reverse"))
	CabControls.paint(self,id,r,caption,pressed)
	hit(id,r)

func _arrow(center: Vector2,scale_px: float,colour: Color,right: bool) -> void:
	var side := 1 if right else -1
	var points := PackedVector2Array([center+Vector2(-.4*side,-.78)*scale_px, center+Vector2(.38*side,0)*scale_px, center+Vector2(-.4*side,.78)*scale_px])
	draw_polyline(points,colour,maxf(2.5,scale_px*.24),true)

func _milk_load_dial(load_shift: Vector2) -> void:
	var face := Rect2(dim.x-110,TOP_ROW_Y+(TOP_ROW_HEIGHT if desk.is_touch_mode() else 39)+8,88,94)
	hud_panels.append(face)
	switch_face(face,Color("#3d4844"))
	draw_rect(face.grow(-4),Color("#dfd8b9"))
	var pivot := face.get_center()+Vector2(0,4)
	draw_arc(pivot,23,0,TAU,40,INK,1.5,true)
	draw_arc(pivot,17,0,TAU,40,Color("#c09360"),1.,true)
	draw_line(pivot-Vector2(29,0),pivot+Vector2(29,0),LINES,1)
	draw_line(pivot-Vector2(0,25),pivot+Vector2(0,25),LINES,1)
	var weight := pivot+Vector2(load_shift.x,-load_shift.y).limit_length(1.35)*17.0
	draw_circle(weight,4.8,Color("#77382e"),true,-1,true)
	fitted(Rect2(face.position+Vector2(4,4),Vector2(80,20)),"TANK LOAD",scaled,14,DARK)
	var cue := "EASE OFF" if load_shift.length()>.87 else "FRONT  ↑"
	fitted(Rect2(face.position+Vector2(4,73),Vector2(80,16)),cue,MONO,12,OXBLOOD if load_shift.length()>.87 else DARK)

func _tension_dial() -> void:
	var value := clampf(float(drawn.get("tension",0.0)),0,1)
	var slipping := str(drawn.get("prompt","")).contains("slipped")
	var face := Rect2(dim.x*.5 - 65,dim.y*.64,130,75)
	hud_panels.append(face)
	var pivot := Vector2(face.get_center().x,face.position.y+51)
	draw_rect(face, Color("#222c2b"))
	draw_rect(face.grow(-3),Color("#c3c1a7"))
	var start := PI*1.10
	var stop := PI*1.90
	draw_arc(pivot,36,start,stop,32,DARK,1.5,true)
	draw_arc(pivot,36,lerpf(start,stop,.82),stop,10,Color("#893633"),4,true)
	for tick in 11:
		var mark := Vector2.from_angle(lerpf(start,stop,tick*.1))
		draw_line(pivot+mark*(31 if tick%5==0 else 33),pivot+mark*40,DARK,1.5,true)
	var needle := Vector2.from_angle(lerpf(start,stop,value))
	draw_line(pivot-needle*4,pivot+needle*34,Color("#893633"),2.5,true)
	draw_circle(pivot,3.6,DARK)
	var caption := "LINE LOAD"
	if slipping:
		caption = "DRUM SLIP"
	elif value>=.82:
		caption = "EASE OFF"
	var shade := Color("#813730") if slipping or value>=.82 else DARK
	fitted(Rect2(face.position+Vector2(6,53),Vector2(118,20)),caption,scaled,13,shade)
	if value>=.82 or slipping:
		var pulse := 0.52 + 0.45*cos(Time.get_ticks_msec()*0.013)
		draw_circle(face.position+Vector2(13,13),3.5,Color("#b93736").lerp(Color("#f5945f"),pulse))
