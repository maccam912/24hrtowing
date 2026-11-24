extends Control

const SIGN_FONT = preload("res://assets/ui/fonts/overpass.ttf")
const PRINT_SOURCE = preload("res://assets/ui/fonts/public_sans.ttf")
const MONO = preload("res://assets/ui/fonts/plex_mono.ttf")
const HAND = preload("res://assets/ui/fonts/caveat.ttf")
const FIELD = preload("res://assets/ui/fonts/architects_daughter.ttf")
const LCD = preload("res://assets/ui/fonts/dseg14.ttf")
const ENAMEL = preload("res://assets/ui/sign_enamel.jpg")
const YARD = preload("res://assets/ui/yard_at_night.jpg")
const Documents = preload("res://scripts/desk_paper.gd")

const WHITE := Color("#e8ebe0")
const INK := Color("#323e3d")
const BLUE := Color("#375067")
const LINES := Color("#84918a")
const DARK := Color("#1c292b")
const PAPER := Color("#e1dfcd")
const RUBBER := Color(0.08, 0.11, 0.13, 0.72)

var desk
var docs := Documents.new()
var hit_boxes: Array[Dictionary] = []
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

func button(id: String, r: Rect2, caption: String, dark: bool = false) -> void:
	var selected := hover == id
	var fill := INK if dark or selected else Color("#c6c9ba")
	draw_rect(r, fill)
	draw_rect(r, INK, false, 1.0)
	fitted(r.grow(-4), caption, scaled, 18, WHITE if dark or selected else INK)
	hit(id, r)

func _draw() -> void:
	if not desk or not scaled:
		return
	unit = maxf(0.01, minf(size.y / 600.0, size.x / 790.0))
	dim = size / unit
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * unit)
	hit_boxes.clear()
	drawn = desk.state
	match desk.page:
		"title":
			_title()
		"pause", "help", "options":
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
	var world_ratio := dim.aspect()
	var image_size: Vector2 = YARD.get_size()
	var src := Rect2(Vector2.ZERO, image_size)
	if world_ratio > image_size.aspect():
		src.size.y = src.size.x / world_ratio
		src.position.y = (image_size.y - src.size.y) * 0.58
	else:
		src.size.x = src.size.y * world_ratio
		src.position.x = (image_size.x - src.size.x) * 0.40
	draw_texture_rect_region(YARD, Rect2(Vector2.ZERO, dim), src)
	var shade := Color("#0d1720")
	var edge := Color(shade,0.67)
	draw_polygon(PackedVector2Array([Vector2.ZERO,Vector2(dim.x*0.7,0),Vector2(dim.x*0.7,dim.y),Vector2(0,dim.y)]), PackedColorArray([edge, Color(shade,0), Color(shade,0), edge]))

func _title() -> void:
	_title_background()
	var w := clampf(dim.x * 0.44, 340.0, 502.0)
	var x := clampf(dim.x * 0.060, 28, 115)
	var y := dim.y * 0.25
	var r := Rect2(x, y, w, 175)
	draw_rect(Rect2(r.position+Vector2(3,7), r.size), Color(0.01,0.02,0.02,0.38))
	draw_texture_rect(ENAMEL, r, false, Color("#a8beb1"))
	draw_rect(r.grow(-5), WHITE.darkened(0.12), false, 2.6)
	for dx in [13.0, w-13.0]:
		for dy in [13.0, r.size.y-13.0]:
			draw_circle(r.position+Vector2(dx,dy), 2.3, Color("#61766a"))
			draw_line(r.position+Vector2(dx-1,dy), r.position+Vector2(dx+1,dy), Color("#b8c7bc"))
	text(Vector2(x+23,y+36), "TAMARACK COUNTY", scaled, 16, WHITE)
	text(Vector2(x+w-94,y+36), "WISCONSIN", subtle, 13, WHITE)
	rule(x+22, y+49, w-44, Color("#a5b4a3"), 1.0)
	fitted(Rect2(x+22,y+49,w-44,83), "24 HR Towing", scaled, 70, WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	text(Vector2(x+25,y+152), "Brandt Towing & Recovery", subtle, 23, WHITE)
	var play := Rect2(x, y+198, w*0.65, 49)
	draw_rect(play, Color("#dedfcf") if hover != "play" else Color("#f0f0df"))
	text(Vector2(play.position.x+17,play.position.y+31), "Continue route" if drawn.get("has_save", false) else "Start engine", scaled, 22, DARK)
	_arrow(Vector2(play.end.x-26, play.get_center().y), 9, DARK, true)
	hit("play", play)
	_title_link("help", Vector2(x,play.end.y+16), "Operator guide")
	_title_link("options", Vector2(x+147,play.end.y+16), "Settings")

func _title_link(id: String, at: Vector2, label: String) -> void:
	var r := Rect2(at,Vector2(134,39))
	draw_rect(r, Color(0.06,0.10,0.12,0.78))
	fitted(r.grow(-4), label, subtle, 18, WHITE)
	if hover == id:
		rule(r.position.x+10,r.end.y-5,r.size.x-20,WHITE)
	hit(id,r)

func _menu() -> void:
	if not desk.started:
		_title_background()
	draw_rect(Rect2(Vector2.ZERO,dim), Color(0.035,0.05,0.06,0.67))
	var width := minf(730, dim.x-52)
	var p := Rect2((dim.x-width)*0.5,(dim.y-452)*0.5,width,452)
	_sheet(p,PAPER)
	var x := p.position.x+28
	var y := p.position.y+28
	text(Vector2(x,y), "BRANDT TOWING & RECOVERY   /   ESKER, WIS.", MONO, 12, BLUE)
	var heading: String = {"pause":"Truck log","options":"Cab settings","help":"Operator guide"}[desk.page]
	text(Vector2(x,y+47),heading,scaled,40,INK)
	rule(x,y+62,width-56,INK,1.7)
	match desk.page:
		"pause":
			button("close", Rect2(x,y+91, width-56,56),"Return to work",true)
			button("help", Rect2(x,y+163,width-56,52),"Operator guide")
			button("options", Rect2(x,y+226,width-56,52),"Cab settings")
			button("title", Rect2(x,y+317,width-56,47),"Title screen")
		"options":
			text(Vector2(x,y+112), "FRAME RATE", MONO, 14, BLUE)
			var current: int = int(drawn.get("frame_rate",desk.fps))
			button("settings_30",Rect2(x,y+136,166,52), "30 FPS", current==30)
			button("settings_60",Rect2(x+178,y+136,166,52), "60 FPS", current==60)
			text(Vector2(x,y+227),"Changes take effect immediately.",print_face,17,INK)
			button("close",Rect2(x,y+332,155,45),"Back")
		"help":
			var line_y := y+94
			var entries: Array
			if desk.is_touch_mode():
				entries = [["DRIVE","Steer with the arrows. Use GAS, BRAKE and REV."],["ON FOOT","Walk with the thumb pad. Drag open space to look."],["AT A SCENE","Read the prompt. Tap USE to handle equipment."],["SIDE PANEL","Hold WINCH to reel. Release it to let tension ease."],["DISPATCH","RADIO opens the call log, answer key and talk-in."],["PAPER","PLAT and SLIP open a lap view while moving."]]
			else:
				entries = [["W A S D","Drive or walk. Use the mouse to look around."],["E","Step out, climb aboard, or use the point you face."],["SPACE","Brake in the cab. Hold at the side panel to winch."],["R   /   T","Answer the radio or ask Arlene for directions."],["M   /   J","Open the plat book or tow slip. Press again to stow."],["ESC","Put down a document or open the truck log."]]
			for entry in entries:
				text(Vector2(x,line_y),entry[0],MONO,15,BLUE)
				text(Vector2(x+132,line_y),entry[1],print_face,17,INK)
				rule(x,line_y+11,width-56,Color("#b4b7a9"))
				line_y+=39
			button("close",Rect2(x,y+344,148,44),"Back")

func _sheet(p: Rect2, colour: Color) -> void:
	draw_rect(Rect2(p.position+Vector2(5,8),p.size), Color(0,0,0,0.4))
	draw_rect(Rect2(p.position+Vector2(2,3),p.size), colour.darkened(.25))
	draw_rect(p,colour)

func _documents() -> void:
	draw_rect(Rect2(Vector2.ZERO,dim),Color(0.035,0.05,0.06,0.68))
	var width := minf(846,dim.x-58)
	var p := Rect2((dim.x-width)*0.5,(dim.y-486)*0.5-9,width,486)
	docs.paint(self,p,desk.page,drawn)
	# Labeled tabs project beyond the paper's bottom edge.
	var tabs := [["slip","Slip"],["map","Plat book"],["radio","Radio"],["fax","Fax"],["parts","Parts"]]
	if not str(drawn.get("custody_text","")).is_empty():
		tabs.append(["custody","Custody"])
	if drawn.get("field_available",false):
		tabs.append(["field","Field book"])
	var tab_x := p.position.x+8
	for tab in tabs:
		var width_tab := maxf(77,print_face.get_string_size(tab[1],HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+24)
		var tab_box := Rect2(tab_x,p.end.y,width_tab,36)
		var active: bool = desk.page == tab[0]
		draw_rect(tab_box, PAPER if active else Color("#99a69d"))
		fitted(tab_box,tab[1],subtle,17,INK)
		hit(tab[0],tab_box)
		tab_x+=width_tab+3
	button("close",Rect2(p.end.x-90,p.end.y,90,36),"Stow",true)

func _glance() -> void:
	var width := minf(353, dim.x*.38)
	var p := Rect2((dim.x-width)*0.5,dim.y-183,width,160)
	draw_set_transform(Vector2(p.position.x,p.position.y)*unit, -0.024, Vector2.ONE*unit)
	docs.glance(self,Rect2(0,0,p.size.x,p.size.y),desk.page,drawn)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE*unit)
	hit("close",p)

func _hud() -> void:
	if not drawn.get("in_cab",true):
		draw_circle(dim*0.5,1.7,Color(0.08,0.11,0.13,0.70))
		draw_circle(dim*0.5,1.0,Color(0.92,0.95,0.90,0.82))
	var prompt: String = str(drawn.get("prompt","")).strip_edges()
	if not prompt.is_empty() and not desk.glance:
		var line_width := minf(dim.x-180,580)
		var size_prompt := 19
		var label := prompt
		if drawn.get("mode","") == "available" and drawn.get("in_cab",true):
			label = "RADIO   ·   Answer dispatch" if desk.is_touch_mode() else "R   ·   Answer dispatch"
		elif drawn.get("work_available",false):
			label = prompt
		elif not desk.is_touch_mode() and not prompt.begins_with("[") and not prompt.begins_with("Hold "):
			label = "E   "+prompt
		var length := minf(line_width,subtle.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size_prompt).x)
		var box := Rect2((dim.x-length)*.5-10,dim.y*.555,length+20,33)
		draw_rect(box, Color(0.045,0.065,0.07,0.77))
		fitted(box.grow(-4),label,subtle,size_prompt,WHITE)
	var words: String = str(drawn.get("subtitle","")).strip_edges()
	if not words.is_empty() and not desk.glance and (not desk.is_touch_mode() or words != prompt):
		var available := minf(665,dim.x - (374 if desk.is_touch_mode() else 90))
		var box := Rect2((dim.x-available)*0.5,dim.y-97,available,73)
		draw_rect(box,Color(0.035,0.048,0.055,0.86))
		var who := str(drawn.get("speaker","DISPATCH")).to_upper()
		text(box.position+Vector2(15,17),who,scaled,13,Color("#dbb890"))
		multiline(box.position+Vector2(15,39),words,subtle,18,WHITE,box.size.x-30,2)
	if desk.is_touch_mode():
		_mobile()
		if drawn.get("work_available",false) and not drawn.get("in_cab",true):
			_tension_dial()

func _mobile() -> void:
	var top := 14.0
	var left := 21.0
	for tab in [["radio","RADIO"],["map","PLAT"],["slip","SLIP"]]:
		_rubber(tab[0],Rect2(left,top,70,43),tab[1],15)
		left+=74
	_rubber("pause",Rect2(dim.x-75,top,51,43),"Ⅱ",20)
	if drawn.get("in_cab",true):
		var bottom := dim.y-21
		for i in 2:
			var b := Rect2(22+i*78,bottom-73,71,73)
			var id := "steer_l" if i==0 else "steer_r"
			_rubber(id,b,"",16)
			_arrow(b.get_center(),15,WHITE,i!=0)
		_rubber("gas",Rect2(dim.x-87,bottom-115,65,115),"GAS",17)
		_rubber("brake",Rect2(dim.x-166,bottom-76,69,76),"BRAKE",15)
		_rubber("reverse",Rect2(dim.x-166,bottom-130,69,46),"REV",15)
		_rubber("interact",Rect2(dim.x-95,bottom-178,73,48),"USE",16)
	else:
		stick_center = Vector2(87,dim.y-88)
		draw_circle(stick_center,59,RUBBER)
		draw_arc(stick_center,58,0,TAU,48,Color("#a4b1ad"),1.5,true)
		draw_circle(stick_center + desk._stick*33,21, Color(0.82,0.86,0.83,0.42))
		hit("stick",Rect2(stick_center-Vector2(77,77),Vector2(154,154)))
		_rubber("interact",Rect2(dim.x-105,dim.y-87,82,64),"USE",17)
		if str(drawn.get("prompt","")).to_lower().contains("winch") or drawn.get("work_available",false):
			_rubber("work",Rect2(dim.x-117,dim.y-156,94,61),"WINCH",16)

func _rubber(id: String,b: Rect2,label: String, px: int) -> void:
	draw_rect(b,Color("#5a635e") if desk._is_down(id) else RUBBER)
	draw_rect(b,Color(0.74,0.79,0.76,0.51),false,1.0)
	if not label.is_empty():
		fitted(b.grow(-4), label, scaled,px, WHITE)
	hit(id,b)

func _arrow(center: Vector2,scale_px: float,colour: Color,right: bool) -> void:
	var side := 1 if right else -1
	var points := PackedVector2Array([center+Vector2(-.4*side,-.78)*scale_px, center+Vector2(.38*side,0)*scale_px, center+Vector2(-.4*side,.78)*scale_px])
	draw_polyline(points,colour,maxf(2.5,scale_px*.24),true)

func _tension_dial() -> void:
	var value := clampf(float(drawn.get("tension",0.0)),0,1)
	var slipping := str(drawn.get("prompt","")).contains("slipped")
	var face := Rect2(dim.x*.5 - 65,dim.y*.64,130,75)
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
