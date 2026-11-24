extends RefCounted

const Campaign := preload("res://scripts/county_case.gd")
const NOTES_PER_PAGE := 6
const PAPER_INK := Color("#353f3c")
const FORM_BLUE := Color("#475e72")
const FADED := Color("#67746e")
const LINE := Color("#9aa498")
const GREEN := Color("#344e43")
const ORIGINAL := Color("#e4e0cd")
const TISSUE := Color("#e3d5ce")
const HATCH := Color("#a6b4a3")
const RADIO_ENAMEL := preload("res://assets/ui/sign_enamel.jpg")
const ATLAS_A := Vector2(-635,-575)
const ATLAS_B := Vector2(934,836)
const KEY_PLACES := [
	["A","Brandt yard","Brandt Towing",Vector2(-32,-64)],
	["B","Highway 64 bridge","River bridge",Vector2(-435,0)],
	["C","Lindquist farm","Lindquist",Vector2(431,246)],
	["D","Brzezinski Dairy","Brzezinski Dairy",Vector2(90,425)],
	["E","Section 3 corner","Section 3",Vector2(314,-400)],
	["F","Esker Fuel & Food","Fuel & Food",Vector2(-71,18)],
	["G","St. Hedwig’s","St. Hedwig’s",Vector2(22,80)]
]

func paint(c, p: Rect2, page: String, s: Dictionary) -> void:
	match page:
		"map": _atlas(c,p,s)
		"radio": _radio(c,p,s)
		"fax": _fax(c,p,s)
		"custody": _custody(c,p,s)
		"field": _field(c,p,s)
		"parts": _parts(c,p,s)
		"passenger": _passenger(c,p,s)
		_: _slip(c,p,s)

func _header(c, p: Rect2, small: String, title: String, reference: String, font: Font) -> void:
	var x := p.position.x+32
	var y := p.position.y+32
	c.text(Vector2(x,y),small,c.MONO,13,FADED)
	c.text(Vector2(x,y+43),title,font,38,PAPER_INK)
	if not reference.is_empty():
		var stamp_width: float = c.MONO.get_string_size(reference,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x+16
		var stamp := Rect2(p.end.x-32-stamp_width,y-18,stamp_width,25)
		c.draw_rect(stamp,c.OXBLOOD,false,1)
		c.fitted(stamp,reference,c.MONO,13,c.OXBLOOD)
	c.rule(x,y+59,p.size.x-64,PAPER_INK,1.8)
	c.rule(x,y+63,p.size.x-64,LINE)

func _slip(c, p: Rect2, s: Dictionary) -> void:
	var history: Array = s.get("slips",[])
	var archived: bool = c.desk.slip_index >= 0 and c.desk.slip_index < history.size()
	var active_job: Dictionary = history[c.desk.slip_index] if archived else s.get("job",{})
	var num := str(active_job.get("number",1001+history.size()))
	var job_kind := str(active_job.get("kind","")).replace("_"," ").capitalize()
	var detail: Dictionary = Campaign.DETAILS.get(active_job.get("case_id",""),{})
	if not detail.is_empty():
		job_kind = detail.title
	var road := str(active_job.get("location","Awaiting county dispatch"))
	c._sheet(p,TISSUE)
	c.draw_rect(Rect2(p.end.x-11,p.position.y+6,6,p.size.y-6),Color("#b0b7a2"))
	_header(c,p,"BRANDT TOWING & RECOVERY   /   ESKER, WI","Tow service record","INVOICE  "+num,c.MONO)
	var x := p.position.x+32
	var y := p.position.y+110
	var w := p.size.x-64
	var right := x+w*.65
	var split := w*.62
	_entry(c,Rect2(x,y,split,49),"SERVICE LOCATION",road)
	_entry(c,Rect2(right,y,w*.35,49),"COUNTY CALL",job_kind if not job_kind.is_empty() else "—")
	_entry(c,Rect2(x,y+54,split,49),"VEHICLE",str(active_job.get("vehicle","—")))
	_entry(c,Rect2(right,y+54,w*.35,49),"PLATE",str(active_job.get("plate","—")))
	c.text(Vector2(x,y+127),"VEHICLE IDENTIFICATION",c.MONO,12,FADED)
	c.text(Vector2(x+193,y+128),str(active_job.get("vin","—")),c.MONO,17,FORM_BLUE)
	c.rule(x,y+140,w,LINE)
	var col := w/3.0
	var values := []
	for key in ["pickup_odo","drop_odo","loaded"]:
		values.append("%.1f mi" % float(active_job[key]) if active_job.has(key) and float(active_job[key]) >= 0.0 else "—")
	for i in 3:
		_entry(c,Rect2(x+i*col,y+155,col-14,48),["ODOMETER / PICKUP","ODOMETER / DROP","BILLABLE LOADED MI"][i],values[i])
	var note := ""
	if archived:
		note = "County schedule    $%.2f" % float(active_job.get("pay",0))
		var shoulder: String = str(active_job.get("run","")).get_slice("/",1)
		if not shoulder.is_empty():
			note += "    /    %s shoulder" % shoulder.capitalize()
		var clipped: Array = s.get("clipped_slips",[])
		if not clipped.is_empty():
			note += "\nPaper clip    " + "  /  ".join(clipped.map(func(n): return str(int(n))))
	else:
		note = str(s.get("progress",""))
		if note.is_empty():
			note = str(active_job.get("dispatch",active_job.get("directions","Dispatch calls come in on the county radio.")))
	c.text(Vector2(x,y+231),"OPERATOR NOTES",c.MONO,12,FADED)
	c.multiline(Vector2(x,y+257),note,c.HAND,24,FORM_BLUE,w,2)
	var touch: bool = c.desk.is_touch_mode()
	var archive_button := Vector2(82,80) if touch else Vector2(52,36)
	var footer_top := p.end.y-(87 if touch else 53)
	c.rule(x,footer_top-(5 if touch else 13),w,LINE)
	if not history.is_empty():
		c.button("prev_slip",Rect2(Vector2(x,footer_top),archive_button),"‹")
		c.button("next_slip",Rect2(Vector2(x+archive_button.x+8,footer_top),archive_button),"›")
		c.text(Vector2(x+2*archive_button.x+21,p.end.y-29),"FILED  %d / %d" % [c.desk.slip_index+1,history.size()] if archived else "CURRENT SLIP",c.MONO,13,FADED)
	else:
		c.text(Vector2(x,p.end.y-29),"COPY  2    /    OPERATOR",c.MONO,14,FADED)
	if s.get("can_fax",false) and not archived:
		c.button("send_fax",Rect2(p.end.x-185,p.end.y-(87 if touch else 56),154,80 if touch else 41),"Fax invoice",true)
	if archived and active_job.get("loaded",0) > 0:
		var attached: bool = int(active_job.number) in s.get("clipped_slips",[])
		c.button("clip_slip",Rect2(p.end.x-214,footer_top,182,archive_button.y),"Unclip carbon" if attached else "Clip for radio")

func _entry(c, r: Rect2, title: String, value: String) -> void:
	c.text(r.position+Vector2(0,12),title,c.MONO,12,FADED)
	c.fitted(Rect2(r.position+Vector2(1,13),r.size-Vector2(2,13)),value,c.HAND,27,FORM_BLUE,HORIZONTAL_ALIGNMENT_LEFT)
	c.rule(r.position.x,r.end.y,r.size.x,LINE)

func _radio(c, p: Rect2, s: Dictionary) -> void:
	var steel := Color("#33413f")
	c.switch_face(p,steel)
	c.draw_texture_rect(RADIO_ENAMEL,p.grow(-5),false,Color(0.75,0.66,0.55,0.22))
	c.draw_rect(p.grow(-9),Color("#26322f"),false,2)
	for dx in [15,p.size.x-15]:
		for dy in [16,p.size.y-16]:
			c._bolt(p.position+Vector2(dx,dy))
	var x := p.position.x+34
	var y := p.position.y+35
	var w := p.size.x-68
	c.text(Vector2(x,y),"VHF TRANSCEIVER",c.MONO,13,Color("#b9c1ad"))
	c.text(Vector2(p.end.x-242,y),"BRANDT  /  UNIT 01",c.MONO,14,c.WHITE,208,HORIZONTAL_ALIGNMENT_RIGHT)
	var lcd := Rect2(x,y+18,w*0.66,67)
	c.switch_face(lcd,Color("#171e1b"),true)
	c.draw_rect(lcd.grow(-7),Color("#c1ac75"))
	c.fitted(lcd.grow(-16),"COUNTY DISPATCH",c.LCD,26,Color("#322d22"),HORIZONTAL_ALIGNMENT_LEFT)
	for i in 8:
		var grille_x := lcd.end.x+21
		var grille_y := lcd.position.y+8+i*7
		c.rule(grille_x,grille_y,p.end.x-35-grille_x,Color("#192321"),3)
		c.rule(grille_x,grille_y+2,p.end.x-35-grille_x,Color("#596054"))
	var records: Array = s.get("calls",[])
	var ry := y+116
	var offer: Dictionary = s.get("offer",{})
	var available: bool = s.get("mode","") == "available"
	c.text(Vector2(x,ry),"ON ROTATION    /    SLIP %d" % int(offer.get("number",1001)) if available else "LAST RECEIVED",c.MONO,13,Color("#b9c1ad"))
	var lead: String = s.get("case_lead","") if available else ""
	var lines: Array = records.duplicate()
	if available and not offer.is_empty():
		lines.append(offer.dispatch)
	if not lead.is_empty():
		c.multiline(Vector2(x,ry+31),lead,c.subtle,19,c.CREAM,w,4)
		ry += 108
		lines = lines.slice(maxi(0,lines.size()-1))
	else:
		lines = lines.slice(maxi(0,lines.size()-3))
	if lines.is_empty():
		lines = [str((s.get("job",{}) as Dictionary).get("dispatch","County channel open."))]
	for i in lines.size():
		var message = lines[lines.size()-1-i]
		var words := str(message)
		if message is Dictionary:
			words = str(message.get("text",""))
		if lead.is_empty():
			c.multiline(Vector2(x,ry+30+i*65),words,c.subtle,19,c.WHITE,w,2)
			c.rule(x,ry+69+i*65,w,Color("#5a685e"))
		else:
			c.multiline(Vector2(x,ry+30),words,c.subtle,19,c.WHITE,w,3)
	var button_height := 80 if c.desk.is_touch_mode() else 52
	var key := Rect2(x,p.end.y-32-button_height,w,button_height)
	if not s.get("can_radio",s.get("in_cab",true)):
		c.fitted(key,"Get in the cab to use the radio.",c.subtle,23,c.CREAM)
	else:
		var contact: Dictionary = s.get("radio_contact",{})
		if not contact.is_empty():
			key.size.x = (w-10)*.48
			c.button(contact.id,Rect2(key.end.x+10,key.position.y,w-key.size.x-10,key.size.y),contact.label,true)
		if available:
			c.button("respond",key,"Keep me on rotation" if s.get("pending_case",false) else "Take contract",true)
		else:
			c.button("directions",key,"Ask for directions",true)

func _passenger(c, p: Rect2, s: Dictionary) -> void:
	c._sheet(p,TISSUE)
	_header(c,p,"ALDER CUT  /  RETURN TO ESKER","The ride home","T. VANG",c.MONO)
	var width := (p.size.x-84)*.5
	var asked: Array = s.get("tou_asked",[])
	for i in Campaign.QUESTIONS.size():
		var at := p.position + Vector2(32 + (i%2)*(width+20),135 + floori(i/2.0)*118)
		c.button("tou_%d" % i,Rect2(at,Vector2(width,84)),Campaign.QUESTIONS[i][0],i not in asked)
		if i in asked:
			c.text(at+Vector2(5,102),"IN THE FIELD NOTES",c.MONO,12,FADED)

func _fax(c, p: Rect2, s: Dictionary) -> void:
	c._sheet(p,Color("#e4e4d8"))
	var x := p.position.x+33
	var width := p.size.x-66
	var archive: Array = s.get("faxes",[])
	var number: int = archive.size()-1 if c.desk.fax_index < 0 else c.desk.fax_index
	var receipt: bool = (s.get("mode","") == "available" and not s.get("slips",[]).is_empty()
		and number == archive.size()-1 and not str(s.get("hint_title","")).is_empty())
	var title := str(s.hint_title) if receipt else "Fax tray"
	var contents := str(archive[number] if number>=0 and number<archive.size() else s.get("fax_text","")).strip_edges()
	if contents.is_empty():
		contents = "No incoming faxes."
	var touch: bool = c.desk.is_touch_mode()
	var key_size := Vector2(82,80) if touch else Vector2(52,40)
	var footer_top := p.end.y-(87 if touch else 54)
	var body_y := p.position.y+111
	var sheets := contents.split("\f",false)
	# A case memo is a second fax sheet. Leave the newest message on top of the tray.
	var page: int = (sheets.size()-1 if receipt else 0) if c.desk.fax_sheet < 0 else posmod(c.desk.fax_sheet,sheets.size())
	c.desk.fax_sheet = page
	_header(c,p,"INCOMING FACSIMILE  /  TAMARACK COUNTY",title,"ACCOUNTS PAYABLE" if sheets.size()==1 else "",c.MONO)
	if sheets.size() > 1:
		var next := "Read invoice" if page == sheets.size()-1 else "Read case memo"
		c.button("fax_sheet",Rect2(p.end.x-222,p.position.y+8,190,80 if touch else 62),next)
	var body := sheets[page]
	var font_size := 18
	while font_size>14 and c.MONO.get_multiline_string_size(body,HORIZONTAL_ALIGNMENT_LEFT,width,font_size).y > footer_top-13-body_y:
		font_size -= 1
	if c.MONO.get_multiline_string_size(body,HORIZONTAL_ALIGNMENT_LEFT,width,font_size).y > footer_top-13-body_y:
		body = body.replace("\n\n","\n")
	while font_size>12 and c.MONO.get_multiline_string_size(body,HORIZONTAL_ALIGNMENT_LEFT,width,font_size).y > footer_top-13-body_y:
		font_size -= 1
	c.multiline(Vector2(x,body_y+c.MONO.get_ascent(font_size)),body,c.MONO,font_size,Color("#50594f"),width)
	c.rule(x,footer_top-5,width,LINE)
	if s.get("can_fax",false):
		c.button("send_fax",Rect2(p.end.x-188,footer_top,156,80 if touch else 39),"Fax invoice",true)
	var caption_x := x
	var caption := "END OF TRANSMISSION"
	if archive.size()>1:
		c.button("prev_fax",Rect2(Vector2(x,footer_top),key_size),"‹")
		c.button("next_fax",Rect2(Vector2(x+key_size.x+8,footer_top),key_size),"›")
		caption_x += 2*key_size.x+22
		caption = "FILED FAX  %d / %d" % [number+1,archive.size()]
	if receipt:
		var footer := Rect2(caption_x,footer_top,p.end.x-33-caption_x,key_size.y)
		c.draw_rect(footer,Color("#d5d8c5"))
		c.draw_rect(Rect2(footer.position,Vector2(3,footer.size.y)),GREEN)
		var stow := "TAP STOW" if touch else "ESC TO STOW"
		c.text(footer.position+Vector2(13,15),stow+"   /   "+caption,c.MONO,12,GREEN)
		var instruction := str(s.get("hint_action",""))
		if touch:
			c.multiline(footer.position+Vector2(13,42),instruction,c.subtle,20,PAPER_INK,footer.size.x-22,2)
		else:
			c.fitted(footer.grow_individual(-13,-15,-8,0),instruction,c.subtle,18,PAPER_INK,HORIZONTAL_ALIGNMENT_LEFT)
	else:
		c.text(Vector2(caption_x,p.end.y-28),caption,c.MONO,14,FADED)

func _custody(c, p: Rect2, s: Dictionary) -> void:
	c._sheet(p,Color("#d8ccab"))
	_header(c,p,"TAMARACK COUNTY SHERIFF'S OFFICE","Evidence custody card","VEHICLE HOLD",c.MONO)
	var x := p.position.x+33
	var y := p.position.y+136
	c.text(Vector2(x,y),"TRANSFER / VEHICLE AND CONTENTS",c.MONO,14,FADED)
	for i in 6:
		c.rule(x,y+46+i*35,p.size.x-66,LINE)
	c.multiline(Vector2(x,y+39),str(s.get("custody_text","No active evidence hold.")),c.MONO,17,PAPER_INK,p.size.x-74,7)
	c.text(Vector2(x,p.end.y-44),"RECEIVED BY",c.MONO,13,FADED)
	c.text(Vector2(x+124,p.end.y-41),"Brandt",c.HAND,30,FORM_BLUE)

func _field(c, p: Rect2, s: Dictionary) -> void:
	c._sheet(p,Color("#d3d7b9"))
	c.draw_rect(Rect2(p.position,Vector2(17,p.size.y)),Color("#6b7663"))
	var x := p.position.x+39
	var y := p.position.y+37
	c.text(Vector2(x,y),"FIELD NOTES   /   TAMARACK COUNTY",c.MONO,13,FADED)
	c.text(Vector2(x,y+45),"S3 / S4 section line",c.FIELD,35,FORM_BLUE)
	var w := p.size.x-72
	for i in range(13):
		c.rule(x,y+67+i*25,w,Color("#a7b9a3"))
	for i in range(int(w/25)):
		c.draw_line(Vector2(x+i*25,y+67),Vector2(x+i*25,y+367),Color("#b9c5b0"))
	var rows := [["11 / 06","5,280.0 ft"],["11 / 09","5,293.8 ft"],["11 / 12","5,337.1 ft"],["11 / 16","5,402.6 ft"]]
	for i in rows.size():
		c.text(Vector2(x+8,y+104+i*45),rows[i][0],c.FIELD,22,FORM_BLUE)
		c.text(Vector2(x+116,y+104+i*45),rows[i][1],c.FIELD,25,FORM_BLUE)
	var nx := x+w*.55
	c.draw_polyline(PackedVector2Array([Vector2(nx,y+110),Vector2(nx+35,y+130),Vector2(nx+57,y+154),Vector2(nx+102,y+148),Vector2(nx+141,y+172)]),FORM_BLUE,1.8,true)
	c.draw_polyline(PackedVector2Array([Vector2(nx-8,y+191),Vector2(nx+61,y+194),Vector2(nx+97,y+179),Vector2(nx+157,y+179)]),FORM_BLUE,1.3,true)
	c.draw_arc(Vector2(nx+57,y+154),6,0,TAU,20,FORM_BLUE,1,true)
	c.text(Vector2(nx+52,y+223),"no road on plat",c.FIELD,17,FORM_BLUE)
	c.text(Vector2(x+7,y+331),"S3/S4 line 5,402.6 — again.",c.FIELD,26,FORM_BLUE)
	c.text(Vector2(x,p.end.y-33),"T. Vang",c.FIELD,24,FORM_BLUE)
	if s.get("can_mark_sketch",false):
		c.button("mark_sketch",Rect2(p.end.x-292,p.end.y-90,260,80),"Copy sketch to plat")

func _atlas(c, p: Rect2, s: Dictionary) -> void:
	c._sheet(p,ORIGINAL)
	for i in range(12):
		var hole := Vector2(p.position.x+11,p.position.y+35+i*37)
		c.draw_circle(hole,3.2,Color("#64716b"))
		c.draw_line(hole-Vector2(13,2),hole,Color("#9a9c89"),1.7,true)
	_header(c,p,"OFFICE OF THE COUNTY SURVEYOR","Tamarack County","PLAT BOOK  /  SHEET 03",c.print_face)
	var map_box := Rect2(p.position+Vector2(30,105), Vector2(p.size.x*.64-35,p.size.y-147))
	_map(c,map_box,s,true)
	var cx := map_box.end.x+19
	var cy := map_box.position.y+19
	var column_w := p.end.x-cx-25
	c.text(Vector2(cx,cy),"ESKER TOWNSHIP",c.scaled,17,GREEN)
	c.rule(cx,cy+8,column_w,LINE)
	var entries: Array = s.get("pencil_notes",[])
	if not entries.is_empty():
		var button_box := Rect2(cx,p.end.y-89,column_w,80)
		var label := "Pencil notes"
		var end := maxi(0,entries.size()-int(c.desk.notes_page)*NOTES_PER_PAGE)
		var start := maxi(0,end-NOTES_PER_PAGE)
		if c.desk.atlas_notes:
			label = "Older notes" if start > 0 else "Parcel index"
		c.button("atlas_notes",button_box,label)
		if c.desk.atlas_notes:
			for i in range(start,end):
				c.fitted(Rect2(cx,cy+14+(i-start)*37,column_w,35),entries[i],c.HAND,20,FORM_BLUE,HORIZONTAL_ALIGNMENT_LEFT)
			return
	var notes := ["County K, north of 64","W0784 · Highway 64","N5016 · Kolpack Rd","W1124 · Hendricks Rd","Swamp Rd · state land","Esker, south of Main","N4886 · County K"]
	for i in KEY_PLACES.size():
		var row_y := cy+29+i*(35 if not entries.is_empty() else 39)
		c.draw_circle(Vector2(cx+8,row_y-5),8,GREEN)
		c.fitted(Rect2(cx-1,row_y-15,18,19),KEY_PLACES[i][0],c.scaled,12,c.WHITE)
		c.text(Vector2(cx+24,row_y),KEY_PLACES[i][1],c.print_face,16,PAPER_INK)
		c.text(Vector2(cx+24,row_y+18),notes[i],c.print_face,13,FADED)
	c.text(Vector2(p.position.x+33,p.end.y-15),"SECTION LINES    /    ONE MILE PER SECTION",c.MONO,11,FADED)

func _map(c, box: Rect2, s: Dictionary, detailed: bool) -> void:
	c.draw_rect(box,Color("#d5d7bc"))
	var bounds := Rect2(ATLAS_A,ATLAS_B-ATLAS_A)
	var pad := 12 if detailed else 4
	var frame := box.grow(-pad)
	var scale_factor := minf(frame.size.x/bounds.size.x,frame.size.y/bounds.size.y)
	var center := frame.get_center()-bounds.get_center()*scale_factor
	var project := func(v: Vector2) -> Vector2: return center+v*scale_factor
	# Engraved parcel lines and lot numbers stay put when a road changes.
	for xi in range(-2,5):
		for zi in range(-1,4):
			var parcel := Rect2(project.call(Vector2(xi*200,zi*200)), Vector2(200,200)*scale_factor)
			if box.encloses(parcel):
				c.draw_rect(parcel,Color("#cad0b4") if (xi+zi)%3==0 else Color("#d9d9c2"))
				c.draw_rect(parcel,Color("#b6bda4"),false,0.7)
				if detailed and xi%2==0 and zi%2==0:
					var section := (15 - xi/2) if zi==0 else (22 + xi/2)
					c.text(parcel.position+Vector2(3,11),str(section),c.MONO,9,Color("#818c75"))
	var river := PackedVector2Array()
	for pt in [Vector2(-452,-460),Vector2(-420,-320),Vector2(-450,-155),Vector2(-435,0),Vector2(-469,123),Vector2(-478,325),Vector2(-524,538),Vector2(-502,830)]:
		river.append(project.call(pt))
	c.draw_polyline(river,Color("#97aba9"),6 if detailed else 2,true)
	var roads: Array = s.get("roads",[])
	for road in roads:
		var pts: PackedVector2Array = road.get("points",PackedVector2Array())
		if pts.size()<2:
			continue
		var projected := PackedVector2Array()
		for point in pts:
			projected.append(project.call(point.clamp(ATLAS_A,ATLAS_B)))
		var width := 3.7 if str(road.get("name","")).contains("64") else 2.3
		if not detailed:
			width *= .64
		c.draw_polyline(projected, Color("#717965"),width+1.8,true)
		c.draw_polyline(projected, Color("#f6edce"),width,true)
		if str(road.get("name","")) in s.get("road_names",[]):
			c.draw_polyline(projected,Color("#566773"),1,true)
	if detailed:
		var road_labels := [
			[Vector2(-423,-279),"RIVER"],[Vector2(-280,-12),"HWY 64"],[Vector2(25,-248),"K"],[Vector2(439,105),"KOLPACK"],
			[Vector2(441,391),"HENDRICKS"],[Vector2(159,791),"ZIELINSKI"],[Vector2(-102,-411),"SWAMP RD"],[Vector2(770,614),"FF"]]
		for entry in road_labels:
			c.text(project.call(entry[0]),entry[1],c.MONO,9,PAPER_INK)
		for property in [[Vector2(27,-326),"STATE LAND"],[Vector2(465,240),"Lindquist"],[Vector2(104,545),"Brzezinski"]]:
			c.text(project.call(property[0]),property[1],c.print_face,10,Color("#6c785f"))
	var offsets := [Vector2(-6,-7), Vector2.ZERO,Vector2(5,0),Vector2(2,8),Vector2(5,3),Vector2(-10,5),Vector2(9,2)]
	var locations := {}
	for place in s.get("places",[]):
		locations[place.name] = place.point
	for i in KEY_PLACES.size():
		var v: Vector2 = project.call(locations.get(KEY_PLACES[i][2],KEY_PLACES[i][3]))
		if detailed:
			c.draw_line(v,v+offsets[i],GREEN,1)
			v+=offsets[i]
			c.draw_circle(v,7.5,GREEN)
			c.fitted(Rect2(v-Vector2(7,8),Vector2(14,16)),KEY_PLACES[i][0],c.scaled,11,c.WHITE)
		else:
			c.draw_circle(v,2.2,GREEN)
	c.draw_rect(box,Color("#87917a"),false,1)
	if detailed:
		var observed: Dictionary = s.get("observations",{})
		for mark in [["rod",Vector2(331,-460),"gate / 38"],["sketch",Vector2(400,336),"T.V. ?"],["house",Vector2(446,332),"5104"]]:
			if observed.has(mark[0]):
				var note_at: Vector2 = project.call(mark[1])
				c.draw_arc(note_at,6.3,0,TAU,15,FORM_BLUE,1.3,true)
				var offset := Vector2(-60,0) if mark[0]=="rod" else (Vector2(-49,12) if mark[0]=="sketch" else Vector2(8,-5))
				c.text(note_at+offset,mark[2],c.HAND,15,FORM_BLUE)
		var evidence: Dictionary = s.get("case_evidence",{})
		if evidence.has("last_cap"):
			var stake: Vector2 = project.call(Vector2(447,-536))
			c.draw_arc(stake,4,0,TAU,12,FORM_BLUE,1.2,true)
			c.text(stake+Vector2(6,4),"S3 NW",c.HAND,14,FORM_BLUE)
		if s.get("adopted",false):
			var turn: Vector2 = project.call(Vector2(441,-466))
			c.text(turn+Vector2(10,0),"ALDER CUT RD",c.MONO,9,GREEN)
			c.text(turn+Vector2(10,13),"N5420 · A. Kraemer",c.print_face,11,GREEN)
		var n := box.position+Vector2(16,23)
		c.text(n,"N",c.scaled,15,GREEN)
		c.draw_colored_polygon(PackedVector2Array([n+Vector2(4,4),n+Vector2(0,16),n+Vector2(4,13),n+Vector2(8,16)]),GREEN)
		var sx := box.end.x - 400*scale_factor - 12
		c.rule(sx,box.end.y-13,400*scale_factor,GREEN,2)
		c.text(Vector2(sx,box.end.y-18),"1 MILE",c.MONO,10,GREEN)

func glance(c, p: Rect2, page: String, s: Dictionary) -> void:
	var job: Dictionary = s.get("job",{})
	c._sheet(p,ORIGINAL if page=="map" else TISSUE)
	var heading := "TAMARACK COUNTY   /   PLAT 03" if page=="map" else "BRANDT   /   TOW SERVICE RECORD"
	if c.MONO.get_string_size(heading,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x > p.size.x-24:
		heading = "TAMARACK / PLAT 03" if page=="map" else "BRANDT / TOW SLIP"
	c.text(p.position+Vector2(12,18),heading,c.MONO,11,GREEN)
	if page == "map":
		_map(c,Rect2(p.position+Vector2(12,25),p.size-Vector2(24,35)),s,false)
	else:
		var x := p.position.x+12
		_entry(c,Rect2(x,p.position.y+24,p.size.x-24,46),"SERVICE LOCATION",str(job.get("location","—")))
		c.multiline(Vector2(x,p.position.y+97),str(job.get("dispatch",s.get("progress",""))),c.HAND,19,FORM_BLUE,p.size.x-24,2)

func _parts(c, p: Rect2, s: Dictionary) -> void:
	c._sheet(p,Color("#d9d9c5"))
	_header(c,p,"BRANDT TOWING & RECOVERY   /   SUPPLY DESK","Winter parts & service","FAX ORDER FORM",c.print_face)
	var x := p.position.x+32
	var y := p.position.y+116
	var width := p.size.x-64
	var money := float(s.get("paid",0))
	var can_order := bool(s.get("can_order",false))
	c.text(Vector2(x,y),"OPERATOR ACCOUNT",c.MONO,13,FADED)
	c.text(Vector2(x+185,y),"$%.2f available" % money,c.MONO,17,FORM_BLUE)
	var rows := [
		["buy_chains","Tire chains","Drive-axle set","More grip for steering and braking on ice.",95.0],
		["service_winch","Winch service","Cable and drum inspection","Service restores a worn winch to full pulling speed.",24.0]]
	var chain_fitted := bool(s.get("chains",false))
	var worn := float(s.get("wear",0))
	for i in rows.size():
		var row: Array = rows[i]
		var ry := y+26+i*131
		c.rule(x,ry,width,LINE)
		var drawing := Rect2(x+1,ry+21,71,68)
		if i==0: _chain_illustration(c,drawing)
		else: _drum_illustration(c,drawing)
		var cols := x+94
		c.text(Vector2(cols,ry+28),row[2].to_upper(),c.MONO,12,FADED)
		c.text(Vector2(cols,ry+56),row[1],c.print_face,25,PAPER_INK)
		c.text(Vector2(cols,ry+81),row[3],c.print_face,15,PAPER_INK)
		var touch: bool = c.desk.is_touch_mode()
		var button_rect := Rect2(p.end.x-194,ry+(44 if touch else 53),162,80 if touch else 43)
		c.text(Vector2(button_rect.position.x,ry+35),"$%.2f" % row[4],c.MONO,20,FORM_BLUE,162,HORIZONTAL_ALIGNMENT_CENTER)
		var status := ""
		if i==0 and chain_fitted: status="Fitted"
		elif i==1 and worn<=.00001: status="Serviced"
		elif not can_order: status="Order at yard"
		elif money<row[4]: status="Awaiting funds"
		if status.is_empty():
			c.button(row[0],button_rect,"Order chains" if i==0 else "Book service",true)
		else:
			c.draw_rect(button_rect,LINE,false,1)
			c.fitted(button_rect,status,c.subtle,16,FADED)
		if i==1:
			c.text(Vector2(cols,ry+105),"WINCH WEAR  %d%%" % ceili(worn*100),c.MONO,12,FADED)
	c.rule(x,p.end.y-73,width,LINE)
	var note := "Order at the yard office fax." if not can_order else "Yard account orders are fitted here on receipt."
	c.text(Vector2(x,p.end.y-38),note,c.HAND,24,FORM_BLUE)

func _chain_illustration(c, r: Rect2) -> void:
	var mid := r.get_center()
	for i in range(5):
		var x := mid.x-26+i*13
		c.draw_line(Vector2(x-4,mid.y-18),Vector2(x+4,mid.y+18),PAPER_INK,1.6,true)
		c.draw_line(Vector2(x+4,mid.y-18),Vector2(x-4,mid.y+18),PAPER_INK,1.6,true)
	for side: int in [-1,1]:
		var y := mid.y+side*18
		for i in 6:
			var center := Vector2(mid.x-29+i*12,y)
			c.draw_arc(center,4.7,0,TAU,14,PAPER_INK,1.5,true)
			c.draw_line(center+Vector2(2,0),center+Vector2(10,0),PAPER_INK,1.6)

func _drum_illustration(c, r: Rect2) -> void:
	var mid := r.get_center()
	c.draw_rect(Rect2(mid-Vector2(21,13),Vector2(42,26)),PAPER_INK,false,1.8)
	for side: int in [-1,1]:
		var x := mid.x+side*24
		c.draw_rect(Rect2(x-3,mid.y-22,6,44),PAPER_INK,false,1.7)
		c.draw_line(Vector2(x,mid.y+21),Vector2(x,mid.y+25),PAPER_INK,1.7)
	for i in 11:
		var x:=mid.x-19+i*3.7
		c.draw_line(Vector2(x+3,mid.y-12),Vector2(x-1,mid.y+12),PAPER_INK,1,true)
	c.draw_polyline(PackedVector2Array([mid+Vector2(-30,25),mid+Vector2(30,25),mid+Vector2(30,29),mid+Vector2(-30,29)]),PAPER_INK,1.8,true)
