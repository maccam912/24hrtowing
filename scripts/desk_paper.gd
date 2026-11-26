extends RefCounted

const Addresses := preload("res://scripts/fire_numbers.gd")
const CabHeater := preload("res://scripts/cab_heater.gd")
const Campaign := preload("res://scripts/county_case.gd")
const Dispatch := preload("res://scripts/dispatch.gd")
const ShopAccount := preload("res://scripts/shop_account.gd")
const NOTES_PER_PAGE := 6
const SIGHTINGS_PER_PAGE := 3
const Broadcast := preload("res://scripts/broadcast_radio.gd")
const Scanner := preload("res://scripts/county_scanner.gd")
const PAPER_INK := Color("#353f3c")
const FORM_BLUE := Color("#475e72")
const FADED := Color("#67746e")
const LINE := Color("#9aa498")
const GREEN := Color("#344e43")
const ORIGINAL := Color("#e4e0cd")
const TISSUE := Color("#e3d5ce")
const HATCH := Color("#a6b4a3")
const RADIO_ENAMEL := preload("res://assets/ui/sign_enamel.jpg")
const Pencil := preload("res://scripts/plat_pencil.gd")
const EastPlat := preload("res://scripts/tamarack_east_plat.gd")
const ATLAS_A := Pencil.NORTHWEST
const ATLAS_B := Pencil.SOUTHEAST
var pencil_projection := Transform2D.IDENTITY
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
		"radio","deputy_call": _radio(c,p,s)
		"visit_call": _visit_call(c,p,s)
		"west_custody": _west_custody(c,p,s)
		"fax": _fax(c,p,s)
		"custody": _custody(c,p,s)
		"field": _field(c,p,s)
		"parts": _parts(c,p,s)
		"coffee": _coffee(c,p,s)
		"bulk_pump", "reserve_transfer": _bulk_pump(c,p,s,page == "reserve_transfer")
		"cab_heat": CabHeater.draw_panel(c,p,s)
		"checked_tape": _mirror_tape(c,p,s.get("checked_tape",{}))
		"impound_register": _impound_register(c,p,s)
		"register_card","storage_tag": _storage_tag(c,p,s.get("storage_tag",{}),page == "register_card")
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
	var pending: Array = s.get("pending_slips",[])
	var index: int = c.desk.slip_index
	var archived := index >= 0 and index < history.size()
	var awaiting := index >= history.size() and index < history.size()+pending.size()
	var active_job: Dictionary = s.get("job",{})
	var caption := "NEXT SLIP" if active_job.is_empty() else "CURRENT SLIP"
	if archived:
		active_job = history[index]
		caption = "FILED  %d / %d" % [index+1,history.size()]
	elif awaiting:
		active_job = pending[index-history.size()]
		caption = "AWAITING FAX  %d / %d" % [index-history.size()+1,pending.size()]
	elif not pending.is_empty():
		caption += "   /   %d TO FAX" % pending.size()
	var num := str(active_job.get("number",s.get("offer",{}).get("number",1001+history.size()+pending.size())))
	var job_kind := str(active_job.get("kind","")).replace("_"," ").capitalize()
	if active_job.has("sheriff_order"):
		job_kind = "Sheriff hold"
	elif active_job.has("field_berm"):
		job_kind = "High-centered car"
	elif active_job.has("field_gate"):
		job_kind = "Pasture gate pull"
	elif active_job.has("wheel_fault"):
		job_kind = "Motor pool repair"
	elif active_job.has("clearance_seconds"):
		job_kind = "Squad pull"
	elif active_job.get("recovery") == "semi":
		job_kind = "Freight recovery"
	elif active_job.get("recovery") == "milk":
		job_kind = "Milk transfer"
	elif active_job.get("vin") == Dispatch.Snowplow.VIN:
		job_kind = "Plow pull"
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
	if (archived or awaiting) and active_job.has("checked_tape"):
		var strip: Dictionary = active_job.checked_tape
		c.fitted(Rect2(x+w*.66,y+108,w*.34,30),"TAPE   %s  #%s" % [strip.date,strip.badge],c.MONO,14,GREEN,HORIZONTAL_ALIGNMENT_RIGHT)
	c.rule(x,y+140,w,LINE)
	var col := w/3.0
	var values := []
	for key in ["pickup_odo","drop_odo","loaded"]:
		values.append("%.1f mi" % float(active_job[key]) if active_job.has(key) and float(active_job[key]) >= 0.0 else "—")
	for i in 3:
		_entry(c,Rect2(x+i*col,y+155,col-14,48),["ODOMETER / PICKUP","ODOMETER / DROP","BILLABLE LOADED MI"][i],values[i])
	var note := ""
	if archived or awaiting:
		note = "County schedule    $%.2f" % float(active_job.get("pay",0))
		var shoulder: String = str(active_job.get("run","")).get_slice("/",1)
		if not shoulder.is_empty():
			note += "    /    %s shoulder" % shoulder.capitalize()
		if active_job.has("field_berm"): note += "\n"+str(active_job.handling)
		if active_job.has("field_gate"): note += "\n"+str(active_job.pull)
		if active_job.has("finding"):
			note += "\n"+str(active_job.finding)
		if active_job.get("kind","") == "passenger":
			note += "\nPassenger delivered to " + str(active_job.get("destination","Esker Fuel & Food"))
		if float(active_job.get("heavy_fee",0)) > 0:
			note += "    /    Heavy recovery +$%.2f" % float(active_job.heavy_fee)
		if active_job.get("recovery") == "semi":
			note += "\nReceived by River Lanes Truck Stop"
		elif active_job.has("wheel_fault"):
			note += "\nREPAIR 03   /   " + str(active_job.handling)
		elif active_job.get("recovery") == "milk":
			note += "\nBrzezinski  /  %d gal   ·   Seal %s" % [int(active_job.gallons),active_job.seal]
		if float(active_job.get("rate_fee",0)) > 0:
			note += "\n%s   +$%.2f" % [active_job.rate_name,active_job.rate_fee]
	else:
		note = str(s.get("progress",""))
		if note.is_empty():
			note = str(active_job.get("dispatch",active_job.get("directions","Dispatch calls come in on the county radio.")))
	c.text(Vector2(x,y+231),"OPERATOR NOTES",c.MONO,12,FADED)
	if active_job.has("clearance_seconds"):
		var elapsed := Dispatch.Squad.clock(active_job.clearance_seconds)
		var imprint := "SCENE CLOCK   %s / 2:00   •   $%d PREMIUM" % [elapsed,Dispatch.Squad.PREMIUM]
		if archived or awaiting:
			imprint = "CLEARED   %s   •   PREMIUM $%.2f" % [elapsed,active_job.get("clearance_bonus",0.0)]
		c.fitted(Rect2(x+132,y+214,w-132,24),imprint,c.MONO,14,FORM_BLUE,HORIZONTAL_ALIGNMENT_RIGHT)
	c.multiline(Vector2(x,y+257),note,c.HAND,24,FORM_BLUE,w,2)
	var touch: bool = c.desk.is_touch_mode()
	var archive_button := Vector2(82,80) if touch else Vector2(52,36)
	var footer_top := p.end.y-(87 if touch else 53)
	c.rule(x,footer_top-(5 if touch else 13),w,LINE)
	if not history.is_empty() or not pending.is_empty():
		c.button("prev_slip",Rect2(Vector2(x,footer_top),archive_button),"‹")
		c.button("next_slip",Rect2(Vector2(x+archive_button.x+8,footer_top),archive_button),"›")
		c.text(Vector2(x+2*archive_button.x+21,p.end.y-29),caption,c.MONO,13,FADED)
	else:
		c.text(Vector2(x,p.end.y-29),"COPY  2    /    OPERATOR",c.MONO,14,FADED)
	if s.get("can_fax",false) and not archived:
		c.button("send_fax",Rect2(p.end.x-185,p.end.y-(87 if touch else 56),154,80 if touch else 41),_fax_label(s),true)

func _entry(c, r: Rect2, title: String, value: String) -> void:
	c.text(r.position+Vector2(0,12),title,c.MONO,12,FADED)
	c.fitted(Rect2(r.position+Vector2(1,13),r.size-Vector2(2,13)),value,c.HAND,27,FORM_BLUE,HORIZONTAL_ALIGNMENT_LEFT)
	c.rule(r.position.x,r.end.y,r.size.x,LINE)

func _fax_label(s: Dictionary) -> String:
	var count := int(s.get("fax_count",1))
	return "Fax %d slips" % count if count > 1 else "Fax slip"

func _track_label(s: Dictionary) -> String:
	if not str(s.get("tracked_lead","")).is_empty():
		return "Defer stop"
	return "Track unpaid stop" if s.get("favor_available",false) else "Track county case"

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
	var reporting: bool = c.desk.sighting_page >= 0
	var in_cab: bool = s.get("can_radio",s.get("in_cab",true))
	var scanning: bool = in_cab and c.desk.scanner_open
	var listening: bool = scanning and c.desk.broadcast_open
	var receiver := "VHF SCANNING RECEIVER" if scanning else "VHF TRANSCEIVER"
	c.text(Vector2(x,y),"AM / FM RECEIVER" if listening else receiver,c.MONO,13,Color("#b9c1ad"))
	c.text(Vector2(p.end.x-242,y),"BRANDT  /  UNIT 01",c.MONO,14,c.WHITE,208,HORIZONTAL_ALIGNMENT_RIGHT)
	var lcd := Rect2(x,y+18,w*(.46 if in_cab and not reporting else .66),67)
	var button_height := 80 if c.desk.is_touch_mode() else 52
	var report_key := Rect2(lcd.end.x+12,lcd.get_center().y-button_height*.5,w-lcd.size.x-12,button_height)
	c.switch_face(lcd,Color("#171e1b"),true)
	c.draw_rect(lcd.grow(-7),Color("#c1ac75"))
	var display := "SIGHTING REPORT" if reporting else "COUNTY DISPATCH"
	if c.desk.page == "deputy_call":
		display = "COUNTY SHERIFF"
	if scanning:
		display = Scanner.CHANNELS.get(s.get("scanner_channel","highway"),"OFF")
	if listening:
		var station: Dictionary = Broadcast.STATIONS.get(s.get("broadcast_station","off"),{})
		display = station.get("dial","OFF")
	c.fitted(lcd.grow(-16),display,c.LCD,26,Color("#322d22"),HORIZONTAL_ALIGNMENT_LEFT)
	if c.desk.page == "deputy_call":
		var copy := Rect2(x,y+112,w,150)
		c.switch_face(copy,Color("#27342e"),true)
		c.text(copy.position+Vector2(18,35),"J. KOWALSKI   /   TC-96-031",c.MONO,17,c.AMBER)
		c.multiline(copy.position+Vector2(18,79),"Brandt, one more thing about Thirty-eight. Did you go through the pickup?",c.print_face,25,c.CREAM,copy.size.x-36,3)
		var half := (w-12)*.5
		c.button("told_open",Rect2(x,y+301,half,88),"I opened it.")
		c.button("told_closed",Rect2(x+half+12,y+301,half,88),"I left it alone.")
		return
	if scanning:
		var selector := report_key
		selector.size.x = floorf((report_key.size.x-8)*.48)
		report_key.position.x = selector.end.x+8
		report_key.size.x = x+w-report_key.position.x
		c.button("close_scanner",report_key,"Dispatch",true)
		c.button("open_scanner" if listening else "open_broadcast",selector,"Scanner" if listening else "AM / FM")
		if listening:
			_broadcast_panel(c,p,s,button_height)
		else:
			_scanner(c,p,s,button_height)
		return
	var scanner_key := Rect2()
	if in_cab and not reporting:
		report_key.size.x = floorf((report_key.size.x-8)*.58)
		scanner_key = Rect2(report_key.end.x+8,report_key.position.y,x+w-report_key.end.x-8,button_height)
	if in_cab and reporting:
		_sighting_choices(c,p,s.get("sighting_reports",[]),button_height)
		c.button("back_to_radio",report_key,"Back to dispatch",true)
		return
	if not in_cab:
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
	var lead: String = s.get("case_lead","")
	var case_lock := str(s.get("case_lock",""))
	if available and not case_lock.is_empty():
		lead = case_lock
	var fuel_eta := int(s.get("fuel_eta",0))
	if fuel_eta > 0:
		lead = "COUNTY PLOW / The relief driver is bringing a can to your wrecker."
	elif s.get("fuel_help",false):
		lead = "OUT OF DIESEL / A relief plow can bring %d%% of a tank in %d minutes. Roadside diesel is double the pump price." % [roundi(ShopAccount.CAN_FILL*100),ShopAccount.CAN_ETA_MINUTES]
		var due := maxf(0.0, ShopAccount.CAN_PRICE - float(s.get("paid",0)))
		if due > 0.0:
			lead += " $%.2f on delivery. The county takes the $%.2f IOU from your next payment." % [ShopAccount.CAN_PRICE-due,due]
		else:
			lead += " $%.2f on delivery." % ShopAccount.CAN_PRICE
	var lines: Array = records.duplicate()
	var trackable: bool = s.get("can_track_lead",false) and s.get("can_radio",true) and fuel_eta == 0 and not s.get("fuel_help",false)
	var track_width := 200.0
	if available and not offer.is_empty():
		lines.append(("I’ll hold the wrecker call. " if s.get("wrecker_waiting",false) else "")+str(offer.dispatch))
	if not lead.is_empty():
		c.multiline(Vector2(x,ry+31),lead,c.subtle,19,c.CREAM,w-track_width-18 if trackable else w,4)
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
	var key := Rect2(x,p.end.y-32-button_height,w,button_height)
	if not in_cab:
		c.fitted(key,"Get in the cab to use the radio.",c.subtle,23,c.CREAM)
	elif fuel_eta > 0:
		c.fitted(key,"Fuel delivery in %d min" % fuel_eta,c.subtle,23,c.CREAM)
	elif s.get("fuel_help",false):
		c.button("roadside_fuel",key,"Request a fuel can  ·  $%.2f" % ShopAccount.CAN_PRICE,true)
	else:
		var buttons: Array[Array] = []
		if available:
			buttons.append(["respond","Keep me on rotation" if s.get("pending_case",false) else "Take contract"])
		if available and not (s.get("visit_offer",{}) as Dictionary).is_empty():
			buttons.append(["visit_call","County look-see"])
		if not available or not str(s.get("tracked_lead","")).is_empty():
			buttons.append(["directions","Ask for directions"])
		var contact: Dictionary = s.get("radio_contact",{})
		if not contact.is_empty():
			buttons.append([contact.id,contact.label])
		key.size.x = (w-10*(buttons.size()-1))/buttons.size()
		for choice in buttons:
			c.button(choice[0],key,choice[1],true)
			key.position.x += key.size.x+10
		if trackable:
			c.button("toggle_lead",Rect2(x+w-track_width,y+126,track_width,button_height),_track_label(s),true)
	if in_cab:
		c.button("report_sighting",report_key,"Report a sighting",true)
		c.button("open_scanner",scanner_key,"Receivers",s.get("scanner_rx",false))

func _west_custody(c, p: Rect2, s: Dictionary) -> void:
	var row: Dictionary = s.get("west_card",{})
	var source := str(s.get("west_source",""))
	var status := str(row.get("status",""))
	var x := p.position.x+32
	var w := p.size.x-64
	var y := p.position.y+106
	var button := Rect2(x,p.end.y-98,w,78)
	c._sheet(p,ORIGINAL)
	_header(c,p,"TAMARACK COUNTY SHERIFF   /   BRANDT YARD","West hold orders",status,c.print_face)
	if row.has("sheriff_order"):
		_entry(c,Rect2(x,y,w*.49,42),"SHERIFF ORDER",row.sheriff_order)
		_entry(c,Rect2(x+w*.52,y,w*.48,42),"LICENSE PLATE",row.plate)
		c.text(Vector2(x,y+77),row.vehicle+"   /   "+row.vin,c.MONO,18,PAPER_INK)
		c.text(Vector2(x,y+106),row.location,c.print_face,22,PAPER_INK)
		var narrative := str(row.get("reason",""))
		if status=="RELEASED": narrative = "Released at %s by %s. %s received the keys and vehicle." % [row.released,row.released_by,row.release_signature]
		elif status=="RELEASE AUTHORIZED": narrative = "The sheriff has authorized release to Deputy Pelz. Unlock the chain, then meet the deputy outside the bay to countersign."
		elif status=="FILED": narrative = "Hold order filed. Keep the chain locked. Check the next service receipt for the sheriff’s release."
		elif status=="IN YARD": narrative = "Lock West Hold 2 from outside and send the signed carbon with the tow slip."
		c.multiline(Vector2(x,y+146),narrative,c.print_face,22,PAPER_INK,w,3)
		if row.has("pickup_signature"):
			c.text(Vector2(x,y+234),"TRANSFER   %s    /    Brandt    %s" % [row.pickup_signature,row.custody_start],c.MONO,17,FORM_BLUE)
		elif status=="ORDER AVAILABLE":
			c.text(Vector2(x,y+232),"County tow rates plus $20.00 for secured custody.",c.MONO,17,GREEN)
		if row.has("arrived"):
			c.text(Vector2(x,y+264),"WEST HOLD 2   %s    /    ODO %.1f" % [row.arrived,row.arrival_odo],c.MONO,17,FORM_BLUE)
	else:
		c.text(Vector2(x,y+48),"The sheriff has no fresh hold for this bay.",c.print_face,24,PAPER_INK)
		c.text(Vector2(x,y+92),"The county tow rotation is open on the cab radio.",c.print_face,20,FADED)
	var action := ""
	var words := ""
	if source=="west_pickup_card" and status=="AWAITING SIGNATURE":
		action="west_sign_pickup"
		words="Sign transfer · take keys"
	elif source=="west_release_card" and status=="RELEASE AUTHORIZED" and not row.locked:
		action="west_sign_release"
		words="Countersign · release vehicle"
	elif source=="west_order_book" and status=="ORDER AVAILABLE":
		action="west_accept"
		words="Accept this order"
	if source=="west_order_book" and int(row.get("archive_count",0))>0:
		var history_rect := button
		if not action.is_empty() or row.archive_open:
			button.size.x = (w-12)*.5
			history_rect = Rect2(button.end.x+12,button.position.y,button.size.x,button.size.y)
		if row.archive_open:
			c.button("west_current",button,"Current orders")
			if int(row.archive_count)>1:
				history_rect.size.x=(history_rect.size.x-8)*.5
				c.button("west_archive_prev",history_rect,"Previous")
				history_rect.position.x+=history_rect.size.x+8
				c.button("west_archive_next",history_rect,"Next")
		else:
			c.button("west_archive",history_rect,"Signed releases")
	if not action.is_empty(): c.button(action,button,words,true)

func _visit_call(c, p: Rect2, s: Dictionary) -> void:
	var call: Dictionary = s.get("visit_offer",{})
	c._sheet(p,ORIGINAL)
	_header(c,p,"TAMARACK COUNTY  /  DISPATCH","Field visit","",c.print_face)
	var x := p.position.x+32
	var y := p.position.y+115
	var width := p.size.x-64
	if call.is_empty():
		c.text(Vector2(x,y),"County has passed the check to another unit.",c.print_face,20,PAPER_INK)
	else:
		_entry(c,Rect2(x,y,width,49),"SERVICE LOCATION",call.location)
		c.multiline(Vector2(x,y+87),call.dispatch,c.print_face,22,PAPER_INK,width,4)
		c.text(Vector2(x,p.end.y-116),"County call-out  $38.00",c.MONO,17,GREEN)
		var half := (width-12)*.5
		c.button("take_visit",Rect2(x,p.end.y-96,half,80),"Take field visit",true)
		c.button("radio",Rect2(x+half+12,p.end.y-96,half,80),"Back to dispatch")

func _broadcast_panel(c, p: Rect2, s: Dictionary, button_height: float) -> void:
	var x := p.position.x+34
	var width := p.size.x-68
	var y := p.position.y+150
	var id := str(s.get("broadcast_station","off"))
	var station: Dictionary = Broadcast.STATIONS.get(id,{})
	var signal_level := float(s.get("broadcast_signal",0.)) if not station.is_empty() else 0.
	c.text(Vector2(x,y),"TUNER",c.MONO,14,Color("#bac2b3"))
	c.text(Vector2(x+width-155,y),"SIGNAL",c.MONO,14,Color("#bac2b3"))
	for lamp in 5:
		var strength := (lamp+1)*.2
		c.draw_rect(Rect2(x+width-88+lamp*18,y-4-lamp*2,12,5+lamp*2),c.AMBER if signal_level+.01 >= strength else Color("#536054"))
	var dial := Rect2(x,y+15,width,61)
	c.switch_face(dial,Color("#1b2421"),true)
	var low := 540. if id == "am" else 88.
	var high := 1660. if id == "am" else 108.
	var step := 20. if id == "am" else .5
	for mark in roundi((high-low)/step)+1:
		var frequency := low+mark*step
		var at := dial.position.x+19+(width-38)*inverse_lerp(low,high,frequency)
		var major := int(frequency)%200 == 0 if id == "am" else mark%8 == 0
		c.draw_line(Vector2(at,dial.position.y+12),Vector2(at,dial.position.y+(31 if major else 22)),Color("#a5ac9b"),2)
		if major:
			c.text(Vector2(at-13,dial.end.y-9),str(int(frequency)),c.MONO,13,c.CREAM)
	if not station.is_empty():
		var fraction := inverse_lerp(low,high,760. if id == "am" else 99.7)
		var needle := dial.position.x+19+(width-38)*fraction
		c.draw_rect(Rect2(needle-2,dial.position.y+7,4,dial.size.y-15),c.AMBER)
		c.text(Vector2(x,y+115),station.name,c.scaled,28,c.CREAM)
		var usable := signal_level >= .20
		var label := str(s.get("broadcast_label","")) if usable else "Signal fading"
		c.text(Vector2(x,y+145),label,c.MONO,16,c.WHITE)
		var words := str(s.get("broadcast_words",""))
		if not words.is_empty():
			c.multiline(Vector2(x,y+176),words,c.subtle,18,c.CREAM,width,2)
	else:
		c.text(Vector2(x,y+120),"Receiver off",c.subtle,22,c.CREAM)
	var key := Rect2(x,p.end.y-32-button_height,(width-20)/3.,button_height)
	for choice: Array in [["am","760 AM  ·  Farm"],["fm","99.7 FM  ·  Country"],["off","Off"]]:
		c.button("broadcast_"+choice[0],key,choice[1],id == choice[0])
		key.position.x += key.size.x+10

func _scanner(c, p: Rect2, s: Dictionary, button_height: float) -> void:
	var x := p.position.x+34
	var width := p.size.x-68
	var y := p.position.y+153
	c.text(Vector2(x,y),"LAST RECEIVED",c.MONO,13,Color("#b9c1ad"))
	var lamp := Rect2(x+width-49,y-11,12,9)
	c.draw_rect(lamp,c.AMBER if s.get("scanner_rx",false) else Color("#555f55"))
	c.text(Vector2(lamp.end.x+6,y),"RX",c.MONO,13,c.CREAM)
	var records: Array = s.get("scanner_history",[])
	if records.is_empty():
		var words := "Receiver off." if s.get("scanner_channel","highway") == "off" else "Listening for county traffic."
		if s.get("scanner_available",false) and not s.get("scanner_fitted",false):
			words += " Kowalski's garage and sheriff channels are in the yard parts catalog."
		c.multiline(Vector2(x,y+44),words,c.subtle,20,c.CREAM,width,3)
	for i in records.size():
		var record: Dictionary = records[i]
		var row_y := y + i*70 + 26
		var station := str(Scanner.CHANNELS.get(record.channel,"")).substr(0,2)
		c.text(Vector2(x,row_y),"%s    CH %s    %s" % [record.clock,station,record.who],c.MONO,13,Color("#bbbfae"))
		c.multiline(Vector2(x,row_y+23),record.words,c.subtle,19,c.WHITE,width,2)
	var channels := ["highway","garage","sheriff","off"] if s.get("scanner_fitted",false) else ["highway","off"]
	var key := Rect2(x,p.end.y-32-button_height,(width-(channels.size()-1)*10)/channels.size(),button_height)
	for id: String in channels:
		var label: String = {"highway":"Highway", "garage":"Garage", "sheriff":"Sheriff", "off":"Off"}[id]
		c.button("scanner_"+id,key,label,id == s.get("scanner_channel","highway"))
		key.position.x += key.size.x+10

func _sighting_choices(c, p: Rect2, reports: Array, button_height: int) -> void:
	var x := p.position.x+34
	var width := p.size.x-68
	if reports.is_empty():
		c.multiline(Vector2(x,p.position.y+178),"Nothing to call in yet. If something catches your eye, look at it for a moment, then check back here.",c.subtle,22,c.CREAM,width,3)
		return
	var pages := ceili(float(reports.size()) / SIGHTINGS_PER_PAGE)
	var page := clampi(c.desk.sighting_page,0,pages-1)
	var first := page*SIGHTINGS_PER_PAGE
	for i in range(first,mini(first+SIGHTINGS_PER_PAGE,reports.size())):
		var item: Dictionary = reports[i]
		var top := p.position.y+132+(i-first)*(button_height+8)
		c.button("sighting:"+str(item.key),Rect2(x,top,width,button_height),item.label,true)
	if pages > 1:
		var nav := Rect2(x,p.end.y-8-button_height,150,button_height)
		if page > 0:
			c.button("prev_sightings",nav,"Previous",true)
		c.fitted(Rect2(x+nav.size.x,nav.position.y,width-2*nav.size.x,button_height),"%d / %d" % [page+1,pages],c.MONO,19,c.CREAM)
		if page+1 < pages:
			nav.position.x = x+width-nav.size.x
			c.button("next_sightings",nav,"Next",true)

func _passenger(c, p: Rect2, s: Dictionary) -> void:
	c._sheet(p,TISSUE)
	_header(c,p,"ALDER CUT  /  RETURN TO ESKER","The ride home","T. VANG",c.MONO)
	var width := (p.size.x-84)*.5
	var asked: Array = s.get("tou_asked",[])
	for i in Campaign.QUESTIONS.size():
		var at := p.position + Vector2(32 + (i%2)*(width+20),103 + floori(i/2.0)*92)
		var label := str(Campaign.QUESTIONS[i][0])
		if i in asked:
			label += "  ✓"
		c.button("tou_%d" % i,Rect2(at,Vector2(width,80)),label,i not in asked)

func _fax(c, p: Rect2, s: Dictionary) -> void:
	c._sheet(p,Color("#e4e4d8"))
	var x := p.position.x+33
	var width := p.size.x-66
	var archive: Array = s.get("faxes",[])
	var number: int = archive.size()-1 if c.desk.fax_index < 0 else c.desk.fax_index
	var filed: Array = s.get("slips",[])
	var receipt: bool = not archive.is_empty() and number == archive.size()-1 and not filed.is_empty() and filed.back().has("number")
	var title := "Slip %d filed" % int(filed.back().number) if receipt else "Fax tray"
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
	var trackable: bool = s.get("can_track_lead",false) and Campaign.matches_memo(s.get("case_chapter",""),body)
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
		c.button("send_fax",Rect2(p.end.x-188,footer_top,156,80 if touch else 39),_fax_label(s),true)
	var caption_x := x
	var caption := "END OF TRANSMISSION"
	if archive.size()>1:
		c.button("prev_fax",Rect2(Vector2(x,footer_top),key_size),"‹")
		c.button("next_fax",Rect2(Vector2(x+key_size.x+8,footer_top),key_size),"›")
		caption_x += 2*key_size.x+22
		caption = "FILED FAX  %d / %d" % [number+1,archive.size()]
	if trackable:
		var end := p.end.x-(198 if s.get("can_fax",false) else 32)
		var action_width := minf(250,end-caption_x)
		c.button("toggle_lead",Rect2(end-action_width,footer_top,action_width,key_size.y),_track_label(s),true)
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
	if s.get("deputy_callback",false):
		if s.get("in_cab",false) and s.get("truck_stopped",false):
			c.button("return_deputy_call",Rect2(p.end.x-314,p.end.y-90,281,80),"Call Kowalski back")
		else:
			c.fitted(Rect2(x+200,p.end.y-83,p.size.x-275,64),"Call me from the truck.  — J.K.",c.HAND,25,FORM_BLUE,HORIZONTAL_ALIGNMENT_RIGHT)

func _field(c, p: Rect2, s: Dictionary) -> void:
	c._sheet(p,Color("#d3d7b9"))
	c.draw_rect(Rect2(p.position,Vector2(17,p.size.y)),Color("#6b7663"))
	var x := p.position.x+39
	var y := p.position.y+37
	c.text(Vector2(x,y),"FIELD NOTES   /   TAMARACK COUNTY",c.MONO,13,FADED)
	c.text(Vector2(x,y+45),"Corners along Kolpack",c.FIELD,35,FORM_BLUE)
	var w := p.size.x-72
	for i in range(13):
		c.rule(x,y+67+i*25,w,Color("#a7b9a3"))
	for i in range(int(w/25)):
		c.draw_line(Vector2(x+i*25,y+67),Vector2(x+i*25,y+367),Color("#b9c5b0"))
	# Pencil over the printed grid. All the wet circles fall on intersections.
	var grid := Vector2(x+27,y+94)
	var cell := Vector2(w*.124,47)
	for col in 4:
		c.draw_line(grid+Vector2(col*cell.x,0),grid+Vector2(col*cell.x,cell.y*3),FADED,1.8)
	for row in 4:
		c.draw_line(grid+Vector2(0,row*cell.y),grid+Vector2(cell.x*3,row*cell.y),FADED,1.8)
	for corner: Vector2 in [Vector2(1,0),Vector2(0,2),Vector2(2,1),Vector2(3,2)]:
		var mark := grid + corner*cell
		c.draw_arc(mark,10.2,.12,TAU+.17,23,FORM_BLUE,2,true)
		c.draw_arc(mark+Vector2(-1,1),12.1,.2,4.4,21,FORM_BLUE,1,true)
	c.text(grid+Vector2(1,cell.y*3+33),"Wet ground at each corner.",c.FIELD,21,FORM_BLUE)
	var address := grid+Vector2(cell.x*1.65,cell.y*2.85)
	c.text(address,"N5104",c.FIELD,22,FORM_BLUE)
	var circle := PackedVector2Array()
	for i in 36:
		var angle := i*TAU/35.0
		circle.append(address+Vector2(28,-7)+Vector2(cos(angle)*44,sin(angle)*18).rotated(-.08))
	c.draw_polyline(circle,FORM_BLUE,1.6,true)
	var tank := Vector2(x+w*.71,y+150)
	c.draw_arc(tank,40,PI,TAU,30,FORM_BLUE,2,true)
	c.draw_polyline(PackedVector2Array([tank+Vector2(-40,0),tank+Vector2(-36,27),tank+Vector2(0,39),tank+Vector2(36,27),tank+Vector2(40,0),tank+Vector2(-40,0)]),FORM_BLUE,1.8,true)
	for side: float in [-1,1]:
		c.draw_line(tank+Vector2(26*side,30),tank+Vector2(41*side,113),FORM_BLUE,2,true)
		c.draw_line(tank+Vector2(26*side,38),tank+Vector2(-38*side,103),FORM_BLUE,1.4,true)
	c.text(tank+Vector2(-72,147),"see from the tank",c.FIELD,23,FORM_BLUE)
	c.text(Vector2(x,p.end.y-33),"T. Vang",c.FIELD,24,FORM_BLUE)
	if s.get("can_mark_sketch",false):
		c.button("mark_sketch",Rect2(p.end.x-292,p.end.y-90,260,80),"Copy sketch to plat")

func _atlas(c, p: Rect2, s: Dictionary) -> void:
	c._sheet(p,ORIGINAL)
	for i in range(12):
		var hole := Vector2(p.position.x+11,p.position.y+35+i*37)
		c.draw_circle(hole,3.2,Color("#64716b"))
		c.draw_line(hole-Vector2(13,2),hole,Color("#9a9c89"),1.7,true)
	_header(c,p,"OFFICE OF THE COUNTY SURVEYOR","Tamarack County","",c.print_face)
	c.button("fire_index",Rect2(p.end.x-373,p.position.y+6,155,80),"Map key" if c.desk.fire_leaf >= 0 else "Fire numbers")
	c.button("plat_pencil",Rect2(p.end.x-210,p.position.y+6,182,80),"Put pencil away" if c.desk.pencil_open else "Use pencil")
	var map_box := Rect2(p.position+Vector2(30,105), Vector2(p.size.x*.64-35,p.size.y-147))
	_map(c,map_box,s,true)
	if not c.desk.east_sheet and not c.desk.pencil_open and c.desk.fire_leaf < 0:
		c.button("turn_town",Rect2(map_box.position+Vector2(6,map_box.size.y-86),Vector2(142,80)),"County plat" if c.desk.town_sheet else "Esker detail")
	var cx := map_box.end.x+19
	var cy := map_box.position.y+19
	var column_w := p.end.x-cx-25
	if c.desk.fire_leaf >= 0:
		_fire_index(c,Rect2(cx,cy-17,column_w,p.end.y-cy-5))
		return
	if c.desk.pencil_open:
		var heading := "Tap the sheet to mark it." if c.desk.is_touch_mode() else "Click to mark · or arrows + Enter"
		c.fitted(Rect2(cx,cy-17,column_w,26),heading,c.subtle,16,GREEN,HORIZONTAL_ALIGNMENT_LEFT)
		var row := Rect2(cx,cy+18,column_w,80)
		for tool: String in ["return","vehicle","lights","erase"]:
			var title := str(Pencil.LABELS.get(tool,"Eraser"))
			c.button("pencil_"+tool,row,title,tool == c.desk.pencil_tool)
			if tool != "erase":
				_pencil_symbol(c,row.position+Vector2(21,row.size.y*.5),tool,1.1)
			row.position.y += 84
		return
	if c.desk.town_sheet:
		Pencil.Town.directory(c,Rect2(cx,cy,column_w,p.end.y-cy-12))
		return
	if c.desk.east_sheet:
		EastPlat.directory(c,Rect2(cx,cy,column_w,p.end.y-cy-12))
		return
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
	var addresses := ["brandt","bridge","farm","dairy","","","church"]
	var notes := ["","","","","Swamp Rd · state land","Esker, south of Main",""]
	for i in addresses.size():
		if not addresses[i].is_empty():
			var id: String = addresses[i]
			notes[i] = Addresses.number(id)+" · "+str(Addresses.PARCELS[id].road)
	for i in KEY_PLACES.size():
		var row_y := cy+29+i*(35 if not entries.is_empty() else 39)
		c.draw_circle(Vector2(cx+8,row_y-5),8,GREEN)
		c.fitted(Rect2(cx-1,row_y-15,18,19),KEY_PLACES[i][0],c.scaled,12,c.WHITE)
		c.text(Vector2(cx+24,row_y),KEY_PLACES[i][1],c.print_face,16,PAPER_INK)
		c.text(Vector2(cx+24,row_y+18),notes[i],c.print_face,13,FADED)
	c.text(Vector2(p.position.x+33,p.end.y-15),"SECTION LINES    /    ONE MILE PER SECTION",c.MONO,11,FADED)

func _fire_index(c, column: Rect2) -> void:
	var ids: Array = Addresses.PARCELS.keys()
	var first := int(c.desk.fire_leaf)*Addresses.PER_LEAF
	var left := column.position.x
	var top := column.position.y
	c.text(Vector2(left,top+15),"RURAL FIRE NUMBERS",c.scaled,16,GREEN)
	c.rule(left,top+22,column.size.x,LINE)
	c.text(Vector2(left,top+41),"Numbers rise north or west.",c.print_face,15,PAPER_INK)
	c.text(Vector2(left,top+59),"264 numbers to a mile on one road.",c.print_face,14,FADED)
	var last := mini(first+Addresses.PER_LEAF,ids.size())
	var roads := {}
	for i in range(first,last):
		roads[Addresses.PARCELS[ids[i]].road] = true
	var step := minf(23.0,(column.size.y-150.0)/maxi(1,last-first+roads.size()))
	var current_road := ""
	var y := top+63
	for i in range(first,last):
		var id: String = ids[i]
		var entry: Dictionary = Addresses.PARCELS[id]
		if current_road != entry.road:
			current_road = entry.road
			y += step
			c.text(Vector2(left,y),current_road.to_upper(),c.MONO,13,FADED)
		y += step
		c.text(Vector2(left+3,y),Addresses.number(id),c.scaled,17,GREEN)
		c.fitted(Rect2(left+72,y-17,column.size.x-72,22),entry.owner,c.print_face,16,PAPER_INK,HORIZONTAL_ALIGNMENT_LEFT)
		if c.desk.fire_parcel == id:
			c.draw_line(Vector2(left,y+4),Vector2(left+62,y+3),FORM_BLUE,1.8,true)
	var pages := ceili(float(ids.size())/Addresses.PER_LEAF)
	c.button("fire_next",Rect2(left,column.end.y-80,column.size.x,80),"Next leaf    %d / %d" % [c.desk.fire_leaf+1,pages])

func _map(c, box: Rect2, s: Dictionary, detailed: bool) -> void:
	c.draw_rect(box,Color("#d5d7bc"))
	var transform := Pencil.projection(box,12 if detailed else 4,c.desk.east_sheet,c.desk.town_sheet)
	var scale_factor := transform.x.x
	var project := func(v: Vector2) -> Vector2: return transform*v
	if detailed and c.desk.pencil_open:
		pencil_projection = transform
		var bounds: Rect2 = c.desk._pencil_bounds()
		c.hit("pencil_sheet",Rect2(transform*bounds.position,bounds.size*scale_factor))
	if c.desk.town_sheet:
		Pencil.Town.draw_sheet(c,box,transform,detailed)
		_pencil_marks(c,box,s,transform,detailed)
		return
	if c.desk.east_sheet:
		EastPlat.draw_sheet(c,box,transform,detailed)
		_pencil_marks(c,box,s,transform,detailed)
		return
	# Engraved parcel lines and lot numbers on the county plat.
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
		for property in [[Vector2(27,-326),"STATE LAND"],[Vector2(36,-208),"Duda"],[Vector2(465,240),"Lindquist"],[Vector2(104,545),"Brzezinski"]]:
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
	if detailed and c.desk.fire_leaf >= 0:
		var entries: Array = Addresses.PARCELS.keys()
		var first := int(c.desk.fire_leaf)*Addresses.PER_LEAF
		for i in range(first,mini(first+Addresses.PER_LEAF,entries.size())):
			var id: String = entries[i]
			var panel: Vector2 = project.call(Addresses.PARCELS[id].at)
			var selected: bool = c.desk.fire_parcel == id
			c.draw_rect(Rect2(panel-Vector2(2,2),Vector2(4,4)),GREEN)
			if selected:
				c.draw_arc(panel,10,0,TAU,22,FORM_BLUE,1.7,true)
				var offset := Vector2(-48,-10) if panel.x > box.get_center().x else Vector2(9,-5)
				c.text(panel+offset,Addresses.number(id),c.HAND,18,FORM_BLUE)
	var stop: Vector3 = s.get("favor_point",Vector3.INF)
	if stop.is_finite():
		var marked: Vector2 = project.call(Vector2(stop.x,stop.z))
		c.draw_arc(marked,12 if detailed else 5,0,TAU,24,c.OXBLOOD,2,true)
		if detailed:
			c.text(marked+Vector2(-85,-13),"Next stop",c.HAND,21,c.OXBLOOD)
	c.draw_rect(box,Color("#87917a"),false,1)
	if detailed:
		var observed: Dictionary = s.get("observations",{})
		for mark in [["rod",Vector2(331,-460),"prints stop"],["sketch",Vector2(400,336),"T. Vang"]]:
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
		var turn: Vector2 = project.call(Vector2(441,-466))
		c.text(turn+Vector2(10,0),"ALDER CUT RD",c.MONO,9,GREEN)
		c.text(turn+Vector2(10,13),"N5420 · A. Kraemer",c.print_face,11,GREEN)
		var hoffmann: Vector2 = project.call(Vector2(445,326))
		c.text(hoffmann+Vector2(8,-4),"N5104 · Hoffmann",c.print_face,10,GREEN)
		var n := box.position+Vector2(16,23)
		c.text(n,"N",c.scaled,15,GREEN)
		c.draw_colored_polygon(PackedVector2Array([n+Vector2(4,4),n+Vector2(0,16),n+Vector2(4,13),n+Vector2(8,16)]),GREEN)
		var sx := box.end.x - 400*scale_factor - 12
		c.rule(sx,box.end.y-13,400*scale_factor,GREEN,2)
		c.text(Vector2(sx,box.end.y-18),"1 MILE",c.MONO,10,GREEN)

	_pencil_marks(c,box,s,transform,detailed)

func _pencil_marks(c, box: Rect2, s: Dictionary, transform: Transform2D, detailed: bool) -> void:
	for mark: Array in s.get("plat_marks",[]):
		var at := transform*Vector2(mark[0],mark[1])
		if box.grow(-3).has_point(at):
			_pencil_symbol(c,at,mark[2],1.0 if detailed else .54)
	if detailed and c.desk.pencil_open and c.hover == "pencil_sheet":
		var tip: Vector2 = transform*c.desk.pencil_point
		c.draw_arc(tip,11,0,TAU,24,c.OXBLOOD,1.3,true)

func _pencil_symbol(c, at: Vector2, kind: String, scale_factor: float) -> void:
	var strokes: Array
	match kind:
		"return": strokes = [[Vector2(-5,-6),Vector2(5,6)],[Vector2(-5,5),Vector2(6,-6)]]
		"lights": strokes = [[Vector2(-7,0),Vector2(-5,-2),Vector2(-3,0),Vector2(-5,2),Vector2(-7,0)],[Vector2(-2,-3),Vector2(0,-5),Vector2(2,-3),Vector2(0,-1),Vector2(-2,-3)],[Vector2(3,0),Vector2(5,-2),Vector2(7,0),Vector2(5,2),Vector2(3,0)]]
		_: strokes = [[Vector2(-7,3),Vector2(-7,-1),Vector2(-3,-2),Vector2(-1,-5),Vector2(4,-5),Vector2(6,-1),Vector2(8,0),Vector2(8,3),Vector2(-7,3)],[Vector2(-4,3),Vector2(-4,5)],[Vector2(5,3),Vector2(5,5)]]
	for stroke: Array in strokes:
		var points := PackedVector2Array()
		for offset: Vector2 in stroke:
			points.append(at+offset*scale_factor)
		c.draw_polyline(points,FORM_BLUE,1.7*scale_factor,true)

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
		var note := str(job.get("dispatch",s.get("progress","")))
		if job.is_empty() and not s.get("pending_slips",[]).is_empty():
			job = s.pending_slips.back()
			note = "Slip %d awaiting fax" % int(job.number)
		_entry(c,Rect2(x,p.position.y+24,p.size.x-24,46),"SERVICE LOCATION",str(job.get("location","—")))
		c.multiline(Vector2(x,p.position.y+97),note,c.HAND,19,FORM_BLUE,p.size.x-24,2)

func _coffee(c, p: Rect2, s: Dictionary) -> void:
	c._sheet(p,ORIGINAL)
	_header(c,p,"ESKER FUEL & FOOD   /   NIGHT COUNTER","Counter check","CUSTOMER COPY",c.print_face)
	var x := p.position.x+34
	var w := p.size.x-68
	c.text(Vector2(x,p.position.y+145),"QTY      DESCRIPTION",c.MONO,15,FADED)
	c.text(Vector2(x,p.position.y+145),"AMOUNT",c.MONO,15,FADED,w,HORIZONTAL_ALIGNMENT_RIGHT)
	c.rule(x,p.position.y+161,w,LINE)
	c.text(Vector2(x,p.position.y+202)," 1       Coffee, to go",c.MONO,23,PAPER_INK)
	c.text(Vector2(x,p.position.y+202),"$%.2f" % ShopAccount.COFFEE_PRICE,c.MONO,23,PAPER_INK,w,HORIZONTAL_ALIGNMENT_RIGHT)
	c.rule(x,p.position.y+224,w,LINE)
	var cash := float(s.get("paid",0))
	var buy: bool = s.get("at_counter",false) and cash >= ShopAccount.COFFEE_PRICE and float(s.get("coffee_left",0)) <= 0
	var status := "Cash on hand  $%.2f" % cash
	if float(s.get("coffee_left",0)) > 0:
		status = "Your last cup is still warm."
	elif cash < ShopAccount.COFFEE_PRICE:
		status = "Cash on hand  $%.2f   ·   A cup costs 75¢." % cash
	c.text(Vector2(x,p.position.y+268),status,c.HAND,26,FORM_BLUE)
	var key := Rect2(x,p.end.y-116,(w-12)*.5,80)
	if buy:
		c.button("buy_coffee",key,"Buy coffee  ·  75¢",true)
	key.position.x += key.size.x+12
	if s.get("at_counter",false):
		c.button("talk_mai",key,"Ask about the lot lights" if s.get("mai_lot",false) else "Talk to Mai")

func _mirror_tape(c, p: Rect2, mark: Dictionary) -> void:
	var strip := Rect2(p.position+Vector2(34,103),Vector2(p.size.x-68,245))
	# The knot holds a torn, doubled strip. Leave the actual vehicle visible behind it.
	var fold := PackedVector2Array([strip.position+Vector2(7,41),strip.position+Vector2(-23,24),strip.position+Vector2(-21,218),strip.position+Vector2(47,191)])
	c.draw_colored_polygon(fold,Color("#9f8c1d"))
	var points := PackedVector2Array([strip.position,Vector2(strip.end.x,strip.position.y+9)])
	for i in range(1,11):
		points.append(Vector2(strip.end.x-(9 if i%2 else 1),strip.position.y+i*strip.size.y/10.))
	points.append(Vector2(strip.position.x+4,strip.end.y-11))
	c.draw_colored_polygon(points,Color("#eed549"))
	var x := strip.position.x+27
	var y := strip.position.y
	var w := strip.size.x-60
	var ink := Color("#343623")
	c.fitted(Rect2(x,y+15,w,35),"TAMARACK COUNTY   /   SHERIFF",c.MONO,20,ink,HORIZONTAL_ALIGNMENT_LEFT)
	c.rule(x,y+57,w,ink,2)
	c.text(Vector2(x,y+84),"DATE CHECKED",c.MONO,14,ink)
	c.text(Vector2(x+w*.33,y+84),"DEPUTY   /   BADGE",c.MONO,14,ink)
	c.fitted(Rect2(x,y+87,w*.29,55),str(mark.get("date","")),c.HAND,40,ink,HORIZONTAL_ALIGNMENT_LEFT)
	c.fitted(Rect2(x+w*.33,y+87,w*.67,55),"%s   #%d" % [mark.get("deputy",""),int(mark.get("badge",0))],c.HAND,40,ink,HORIZONTAL_ALIGNMENT_LEFT)
	c.rule(x,y+151,w,ink)
	c.text(Vector2(x,y+177),"CHECKED AT",c.MONO,14,ink)
	var road := str(mark.get("road",""))
	c.fitted(Rect2(x,y+178,w,54),road if not road.is_empty() else "—",c.HAND,36,ink,HORIZONTAL_ALIGNMENT_LEFT)

func _impound_register(c, p: Rect2, s: Dictionary) -> void:
	c._sheet(p,ORIGINAL)
	var x := p.position.x+35
	var width := p.size.x-70
	_header(c,p,"BRANDT TOWING & RECOVERY","Impound register","YARD COPY",c.MONO)
	var rows: Array = s.get("impound_rows",[])
	if rows.is_empty():
		c.text(Vector2(x,p.position.y+182),"No vehicles received.",c.HAND,28,FORM_BLUE)
	for i in rows.size():
		var row: Dictionary = rows[i]
		var r := Rect2(x,p.position.y+108+i*85,width,80)
		var id := "impound_%d" % i
		c.draw_rect(r,Color("#d5d3bd") if c.hover != id else Color("#ead3a3"))
		c.rule(x,r.end.y-1,width,LINE)
		c.fitted(Rect2(x+16,r.position.y+5,width*.51-16,36),str(row.get("vehicle","Prior impound")),c.HAND,26,FORM_BLUE,HORIZONTAL_ALIGNMENT_LEFT)
		c.fitted(Rect2(x+16,r.position.y+41,width*.51-16,30),str(row.get("location",row.get("route",""))),c.print_face,20,PAPER_INK,HORIZONTAL_ALIGNMENT_LEFT)
		c.fitted(Rect2(x+width*.52,r.position.y+7,width*.47-10,31),str(row.get("stall","")),c.MONO,18,GREEN,HORIZONTAL_ALIGNMENT_RIGHT)
		var ticket := "#"+str(row.number) if row.has("number") else "Prior ledger"
		c.fitted(Rect2(x+width*.52,r.position.y+43,width*.47-10,28),ticket+"   "+str(row.get("plate","")),c.MONO,16,FADED,HORIZONTAL_ALIGNMENT_RIGHT)
		c.hit(id,r)
	var pages := int(s.get("impound_pages",1))
	var leaf := int(s.get("impound_leaf",0))
	var foot := Rect2(x,p.end.y-87,width*.28,80)
	if leaf > 0:
		c.button("impound_prev",foot,"Newer entries")
	if leaf < pages-1:
		foot.position.x = p.end.x-35-foot.size.x
		c.button("impound_next",foot,"Older entries")
	c.fitted(Rect2(x+width*.3,foot.position.y,width*.4,80),"SHEET  %d / %d" % [leaf+1,pages],c.MONO,17,FADED)

func _storage_tag(c, p: Rect2, record: Dictionary, register_copy: bool) -> void:
	c._sheet(p,TISSUE)
	_header(c,p,"BRANDT TOWING & RECOVERY","Impound tag",str(record.get("stall","STORAGE")),c.MONO)
	var x := p.position.x+35
	var width := p.size.x-70
	var y := p.position.y+125
	var number := int(record.get("number",0))
	var fields := [["TOW SLIP",str(number) if number else "Prior ledger"],["TIME IN",record.get("time","—")],
		["VEHICLE",record.get("vehicle","Prior impound")],["REGISTRATION",record.get("plate","—")],
		["PICKUP",record.get("location",record.get("route","—"))],["VIN",record.get("vin","—")]]
	for i in fields.size():
		_entry(c,Rect2(x+(i%2)*(width*.5+5),y+floori(i/2.0)*97,width*.5-10,71),fields[i][0],str(fields[i][1]))
	var tape: Dictionary = record.get("checked_tape",{})
	if not tape.is_empty():
		var imprint := "Tape  %s  #%s   %s" % [tape.date,tape.badge,tape.get("road","")]
		c.fitted(Rect2(x,p.end.y-90,width-203,52),imprint,c.HAND,22,FORM_BLUE,HORIZONTAL_ALIGNMENT_LEFT)
	if register_copy:
		c.button("impound_index",Rect2(p.end.x-222,p.end.y-85,190,80),"Back to register")
		c.text(Vector2(x,p.end.y-26),"CARBON   /   YARD OFFICE",c.MONO,13,FADED)
	else:
		c.text(Vector2(x,p.end.y-20),"YARD COPY   /   RETAIN WITH VEHICLE",c.MONO,13,FADED)

func _bulk_pump(c, p: Rect2, s: Dictionary, transfer := false) -> void:
	c.switch_face(p,Color("#445447") if transfer else Color("#823e36"))
	var face := p.grow(-18)
	c.draw_rect(face,Color("#e0d7bb"))
	var x := face.position.x+30
	var width := face.size.x-60
	var esker := bool(s.get("nozzle_esker",false))
	var title := "CURB-SIDE   /   DIESEL TRANSFER" if transfer else ("ESKER   /   HIGHWAY DIESEL" if esker else "BRANDT   /   BULK DIESEL")
	c.text(Vector2(x,face.position.y+42),title,c.scaled,26,PAPER_INK)
	c.rule(x,face.position.y+59,width,c.OXBLOOD,3)
	var reserve := bool(s.get("aux_tank",false) and s.get("nozzle_reserve",false))
	var main := float(s.get("fuel",0))
	var auxiliary := float(s.get("reserve_pct",0))
	var level := auxiliary if reserve else main
	var totals := [["THIS SALE","$ %06.2f" % s.get("nozzle_sale",0.0)],["RESERVE TANK" if reserve else "WRECKER TANK","%03d %%" % roundi(100*level)]]
	if transfer:
		totals = [["RESERVE TANK","%03d %%" % roundi(100*auxiliary)],["MAIN TANK","%03d %%" % roundi(100*main)]]
	for i in totals.size():
		var box := Rect2(x+width*.5*i,face.position.y+96,width*.5-12,75)
		c.text(box.position+Vector2(0,-10),totals[i][0],c.MONO,15,FADED)
		c.switch_face(box,Color("#343a34"),true)
		c.fitted(box.grow(-10),totals[i][1],c.LCD,36,c.CREAM)
	var status := "Cash in till   $%.2f" % float(s.get("paid",0))
	var ready := bool(s.get("nozzle_ready",false))
	var flow: bool = ready and level < .9999 and s.get("paid",0.0) >= .01
	if transfer:
		status = "Transfer reserve diesel into the main tank."
		if main >= .9999: status = "Main tank full."
		elif auxiliary <= .0001: status = "Reserve empty."
		flow = main < .9999 and auxiliary > .0001
	elif not ready: status = "Park the wrecker beside the pump."
	elif level >= .9999: status = "Tank full."
	elif s.get("paid",0.0) < .01: status = "Till empty."
	var status_y := face.position.y+193
	if s.get("aux_tank",false) and not transfer:
		var key := Rect2(x,face.position.y+181,(width-8)*.5,72)
		c.button("tank_main",key,"Main tank   %d%%" % roundi(100*main),not reserve)
		key.position.x += key.size.x+8
		c.button("tank_reserve",key,"Reserve   %d%%" % roundi(100*auxiliary),reserve)
		status_y = key.end.y+1
	c.fitted(Rect2(x,status_y,width,35),status,c.MONO,18,PAPER_INK,HORIZONTAL_ALIGNMENT_LEFT)
	var handle := Rect2(x,face.end.y-124,width,89)
	if flow:
		var caption := "Hold switch to transfer" if transfer else "Hold nozzle to fill"
		if not c.desk.is_touch_mode(): caption += "   /   Space"
		c.button("nozzle",handle,caption,true)
	else:
		c.switch_face(handle,Color("#62665d"),true)
		c.fitted(handle,"NO FLOW",c.MONO,22,c.CREAM)

func _parts(c, p: Rect2, s: Dictionary) -> void:
	c._sheet(p,Color("#d9d9c5"))
	var at_office := bool(s.get("at_office",false))
	var at_pump := bool(s.get("at_pump",false))
	var scanner_available := bool(s.get("scanner_available",false) or s.get("scanner_fitted",false))
	var station := "ESKER PUMPS" if at_pump else ("YARD COUNTER" if at_office else "FIELD COPY")
	var leaf: int = c.desk.parts_page
	var fleet_leaf: bool = c.desk.parts_labels()[leaf] == "Fleet keys"
	var titles := ["Fuel & equipment","Cab & rig equipment","Yard fittings","Auxiliary diesel"]
	_header(c,p,"BRANDT TOWING   /   "+station,"Fleet keys" if fleet_leaf else titles[leaf],"",c.print_face)
	var x := p.position.x+32
	var width := p.size.x-64
	var money := float(s.get("paid",0))
	var totals := [
		["AVAILABLE",money],["PENDING PAYMENT",float(s.get("pending",0))],
		["LIFETIME EARNED",float(s.get("earned",0))]]
	if float(s.get("fuel_due",0)) > 0:
		totals.append(["FUEL IOU",float(s.fuel_due)])
	if float(s.get("recovery_due",0)) > 0:
		totals.append(["YARD TOW IOU",float(s.recovery_due)])
	var column := width/totals.size()
	for i in totals.size():
		var left := x+i*column
		c.fitted(Rect2(left,p.position.y+101,column-8,25),totals[i][0],c.MONO,13,FADED,HORIZONTAL_ALIGNMENT_LEFT)
		c.fitted(Rect2(left,p.position.y+123,column-10,27),"$%.2f" % totals[i][1],c.MONO,23,FORM_BLUE,HORIZONTAL_ALIGNMENT_LEFT)
	var gap := 12.0
	var size := Vector2((width-gap)*0.5,126)
	var left := Rect2(Vector2(x,p.position.y+183),size)
	var right := Rect2(left.position+Vector2(size.x+gap,0),size)
	c.text(left.position-Vector2(0,8),"USED TRUCK INVENTORY" if fleet_leaf else ["FUEL & MAINTENANCE","WINTER EQUIPMENT","YARD INSTALLATION","LONG-HAUL EQUIPMENT"][leaf],c.MONO,13,GREEN)
	if fleet_leaf:
		var owned: bool = s.get("rollback_owned",false)
		_equipment_card(c,left,"buy_rollback","Steel-deck car carrier","Light cars ride on the bed. Half tank on delivery. 126,804 miles.",ShopAccount.PRICES.rollback,
			"Buy carrier","Paid in full" if owned else "",money,s.get("can_order",false),"Visit yard office")
		if owned:
			var standby: Dictionary = s.get("standby",{})
			var driving := "car carrier" if s.get("rollback_active",false) else "35-ton wrecker"
			var parked := "35-ton wrecker" if s.get("rollback_active",false) else "car carrier"
			c.text(right.position+Vector2(6,24),"KEY REGISTER",c.MONO,17,GREEN)
			c.multiline(right.position+Vector2(6,55),"Out    %s\nYard  %s" % [driving,parked],c.print_face,19,FORM_BLUE,right.size.x-12,3)
			if not standby.is_empty():
				left.position.y += size.y+34
				c.multiline(left.position,"Parked truck  •  %s miles  /  %d%% diesel" % [str(snappedf(standby.odo,.1)),roundi(standby.fuel*100)],c.MONO,17,FORM_BLUE,width,2)
		_parts_nav(c,p,leaf)
		var instructions := str(s.get("shop_receipt",""))
		if instructions.is_empty(): instructions = "Finish the current ticket, park at the yard and walk to the other driver’s door."
		c.fitted(Rect2(x,p.end.y-38,width,32),instructions,c.subtle,18,FORM_BLUE,HORIZONTAL_ALIGNMENT_LEFT)
		return
	if leaf == 0:
		c.text(right.position-Vector2(0,8),"RECOVERY EQUIPMENT",c.MONO,13,GREEN)
	if leaf == 1:
		var can_fit := bool(s.get("can_order",false))
		var location := "Park wrecker in yard" if at_office else "At Brandt yard office"
		_equipment_card(c,left,"buy_mirrors","Heated mirrors","Electric elements clear the glass on long winter hauls.",ShopAccount.PRICES.mirrors,
			"Fit heated glass","Fitted" if s.get("heated_mirrors",false) else "",money,can_fit,location)
		_equipment_card(c,right,"buy_lamps","Driving bar & spot","Wider beams and an aimable pillar lamp for reading fire plates.",ShopAccount.PRICES.lamps,
			"Fit lamps","Fitted" if s.get("aux_lamps",false) else "",money,can_fit,location)
		right.position.y += size.y+8
		var winch_status := "Fitted" if s.get("second_winch",false) else ""
		if s.get("rollback_active",false):
			winch_status = "Bring the wrecker"
		elif winch_status.is_empty() and not s.get("heavy_job_filed",false):
			winch_status = "File a heavy recovery"
		elif winch_status.is_empty() and not s.get("snatch_block",false):
			winch_status = "Fit snatch block first"
		_equipment_card(c,right,"buy_second_winch","Auxiliary winch","Control a trailer on the second line. Opens freight calls on US 59.",ShopAccount.PRICES.second_winch,
			"Fit second winch",winch_status,money,can_fit,location)
		if scanner_available:
			left.position.y += size.y+8
			_equipment_card(c,left,"buy_scanner","Scanner crystals","Hear the sheriff and county garage from the cab.",ShopAccount.PRICES.scanner,
				"Fit crystals","Fitted" if s.get("scanner_fitted",false) else "",money,can_fit,location)
		_parts_nav(c,p,leaf)
		c.fitted(Rect2(x,p.end.y-38,width,32),s.get("shop_receipt",""),c.subtle,18,FORM_BLUE,HORIZONTAL_ALIGNMENT_LEFT)
		return
	if leaf == 2:
		var can_fit := bool(s.get("can_order",false))
		var location := "At Brandt yard office"
		_equipment_card(c,left,"buy_yard_pump","Bulk-tank pump","Meter your own diesel beside the storage stalls.",ShopAccount.PRICES.yard_pump,
			"Install pump","Installed" if s.get("yard_pump",false) else "",money,can_fit,location)
		_equipment_card(c,right,"buy_coffee_maker","Shop coffeemaker","Brew a cup at the office bench before heading out.",ShopAccount.PRICES.coffee_maker,
			"Install brewer","Installed" if s.get("coffee_maker",false) else "",money,can_fit,location)
		left.position.y += size.y+8
		_equipment_card(c,left,"buy_west_lot","West storage lot","Open the gate to twelve more impound spaces.",ShopAccount.PRICES.west_lot,
			"Extend fence","Installed" if s.get("west_lot",false) else "",money,can_fit,location)
		right.position.y += size.y+8
		var gate := "Installed" if s.get("west_hold",false) else ("" if s.get("west_lot",false) else "Extend west lot first")
		_equipment_card(c,right,"buy_west_hold","Second hold bay","Secure a separate sheriff vehicle. Get orders at the west gate book.",ShopAccount.PRICES.west_hold,
			"Install hold bay",gate,money,can_fit,location)
		_parts_nav(c,p,leaf)
		c.fitted(Rect2(x,p.end.y-38,width,32),s.get("shop_receipt",""),c.subtle,18,FORM_BLUE,HORIZONTAL_ALIGNMENT_LEFT)
		return
	if leaf == 3:
		var on_carrier := bool(s.get("rollback_active",false))
		var owned := bool(s.get("aux_tank",false))
		_equipment_card(c,left,"buy_aux_tank","Auxiliary diesel tank","Curb-side transfer pump. Holds half a main tank. Supplied empty.",ShopAccount.PRICES.aux_tank,
			"Fit fuel tank","Bring the wrecker" if on_carrier else ("Fitted" if owned else ""),money,s.get("can_order",false),"Fit at yard office")
		if owned:
			var quote:Dictionary = s.get("reserve_quote",{})
			var cost := float(quote.get("cost",0))
			var pct := roundi(float(s.get("reserve_pct",0))*100.)
			var can_fill := bool(s.get("can_refuel",false)) and cost > 0
			var fill := "Fill reserve   $%.2f" % cost
			if not s.get("can_refuel",false): fill = "Visit yard or pump"
			elif pct == 100 and cost <= 0: fill = "Reserve full"
			elif cost <= 0: fill = "Awaiting funds"
			_shop_card(c,right,"buy_reserve_fuel","Reserve diesel","%d%%" % pct,
				"Same price per gallon. An empty reserve takes $24.00 of diesel.",fill,can_fill)
		_parts_nav(c,p,leaf)
		c.fitted(Rect2(x,p.end.y-38,width,32),s.get("shop_receipt",""),c.subtle,18,FORM_BLUE,HORIZONTAL_ALIGNMENT_LEFT)
		return
	var fuel := clampf(float(s.get("fuel",1.0)),0.0,1.0)
	var quote: Dictionary = s.get("fuel_quote",{})
	var cost := float(quote.get("cost",0))
	var fuel_percent := roundi(fuel*100.0)
	var fill_percent := roundi(float(quote.get("fuel_after",fuel))*100.0)
	var fuel_text := "Yard diesel or Esker pumps. A full tank costs $%.2f." % ShopAccount.TANK_PRICE
	var fill := "Buy diesel  ·  $%.2f" % cost
	var buy_fuel := false
	if fuel >= 1.0 or (cost <= 0.0 and fuel_percent == 100):
		fill = "Tank full"
	elif not s.get("can_refuel",false):
		if at_pump:
			fill = "Park wrecker by pumps"
		elif at_office:
			fill = "Park wrecker in yard"
		else:
			fill = "Visit yard or pumps"
	elif cost <= 0:
		fill = "Awaiting funds"
	else:
		buy_fuel = true
		if fill_percent < 100:
			fuel_text = "Available cash buys a partial fill to %d%%." % fill_percent
		else:
			fuel_text = "Fill the tank to 100%% for $%.2f." % cost
	_shop_card(c,left,"buy_fuel","Diesel fuel","%d%%" % fuel_percent,fuel_text,fill,buy_fuel)
	var service_location := "Park wrecker in yard" if at_office else "At Brandt yard office"
	var can_order := bool(s.get("can_order",false))
	_equipment_card(c,right,"buy_chains","Tire chains","More grip on ice. Required for the Alder Cut survey run.",ShopAccount.PRICES.chains,
		"Fit chains","Fitted" if s.get("chains",false) else "",money,can_order,service_location)
	left.position.y += size.y+8
	right.position.y = left.position.y
	var wear := float(s.get("wear",0.0))
	_equipment_card(c,left,"service_winch","Winch service","Restore pulling speed. Cable and drum wear is %d%%." % ceili(wear*100.0),ShopAccount.REPAIR_PRICE,
		"Service winch","Serviced" if wear <= 0.001 else "",money,can_order,service_location)
	_equipment_card(c,right,"buy_snatch_block","Snatch block set","Rig heavier recoveries, including the Unit 38 pickup.",ShopAccount.PRICES.snatch_block,
		"Fit snatch block","Bring the wrecker" if s.get("rollback_active",false) else ("Fitted" if s.get("snatch_block",false) else ""),money,can_order,service_location)
	_parts_nav(c,p,leaf)
	var note := str(s.get("shop_receipt",""))
	if note.is_empty():
		if at_pump:
			note = "For equipment, visit the office fax at Brandt’s yard."
		elif at_office:
			note = "Accounts payable releases a batch every third filed slip."
		else:
			note = "Order at Brandt’s office fax. Diesel is also available at Esker Fuel & Food."
	c.fitted(Rect2(x,p.end.y-38,width,32),note,c.subtle,18,FORM_BLUE,HORIZONTAL_ALIGNMENT_LEFT)

func _parts_nav(c, p: Rect2, leaf: int) -> void:
	var labels: Array = c.desk.parts_labels()
	var x := p.end.x-258
	c.button("parts_prev",Rect2(x,p.position.y+6,80,80),"‹")
	c.button("parts_leaf",Rect2(x+86,p.position.y+6,148,80),labels[(leaf+1)%labels.size()]+" ›")

func _equipment_card(c, r: Rect2, id: String, title: String, description: String, price: float,
		order: String, fitted_status: String, money: float, can_order: bool, location: String) -> void:
	var status := fitted_status
	if status.is_empty() and not can_order:
		status = location
	if status.is_empty() and money < price:
		status = "Need $%.2f more" % (price-money)
	_shop_card(c,r,id,title,"$%.2f" % price,description,order if status.is_empty() else status,status.is_empty())

func _shop_card(c, r: Rect2, id: String, title: String, price: String, description: String, status: String, enabled: bool) -> void:
	var focus: bool = enabled and (c.hover == id or c.desk._is_down(id))
	c.draw_rect(r,Color("#e9e5ce") if focus else Color("#e1dfc9"))
	var ink: Color = c.OXBLOOD if enabled else FADED
	c.draw_rect(r,ink if focus else LINE,false,2 if focus else 1)
	var inset := 12.0
	var amount_width: float = c.MONO.get_string_size(price,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+3
	c.fitted(Rect2(r.position+Vector2(inset,4),Vector2(r.size.x-2*inset-amount_width-9,30)),title,c.scaled,23,PAPER_INK,HORIZONTAL_ALIGNMENT_LEFT)
	c.fitted(Rect2(r.end.x-inset-amount_width,r.position.y+4,amount_width,30),price,c.MONO,16,FORM_BLUE,HORIZONTAL_ALIGNMENT_RIGHT)
	var sketch := Rect2(r.position+Vector2(9,39),Vector2(72,47))
	match id:
		"buy_mirrors":
			var center := sketch.get_center()
			c.draw_rect(Rect2(center-Vector2(12,19),Vector2(24,36)),PAPER_INK,false,2)
			for i in range(-1,2):
				var at := center+Vector2(4*i,0)
				c.draw_polyline(PackedVector2Array([at+Vector2(0,10),at+Vector2(-1,5),at+Vector2(1,1),at+Vector2(-1,-4),at+Vector2(1,-10)]),FORM_BLUE,1.2,true)
		"buy_lamps":
			c.draw_rect(sketch.grow_individual(-3,-16,-3,-16),PAPER_INK,false,2)
			for i in 6:
				c.draw_circle(sketch.position+Vector2(11+i*10,sketch.size.y*.5),3.3,FORM_BLUE)
		"buy_west_lot","buy_west_hold":
			for i in 6:
				var at := sketch.position+Vector2(6+i*8,8)
				c.draw_line(at,at+Vector2(15,29),FORM_BLUE,1,true)
				c.draw_line(at+Vector2(15,0),at+Vector2(0,29),FORM_BLUE,1,true)
			c.draw_rect(sketch.grow(-6),PAPER_INK,false,2)
		"buy_coffee_maker":
			var m := sketch.get_center()
			c.draw_rect(Rect2(m-Vector2(16,19),Vector2(32,8)),PAPER_INK,false,2)
			c.draw_rect(Rect2(m-Vector2(16,11),Vector2(6,28)),PAPER_INK,false,2)
			c.rule(m.x-17,m.y+18,37,PAPER_INK,3)
			c.draw_arc(m+Vector2(3,5),10,deg_to_rad(-42),deg_to_rad(222),20,FORM_BLUE,2,true)
			c.draw_arc(m+Vector2(14,4),4,deg_to_rad(-90),deg_to_rad(90),10,PAPER_INK,2,true)
		"buy_scanner":
			c.draw_rect(sketch.grow(-5),PAPER_INK,false,2)
			c.draw_rect(Rect2(sketch.position+Vector2(10,13),Vector2(30,13)),FORM_BLUE,false,1.8)
			c.draw_arc(sketch.position+Vector2(54,21),6,0,TAU,18,PAPER_INK,2,true)
			for i in 3:
				c.rule(sketch.position.x+12,sketch.position.y+30+i*3,35,PAPER_INK)
		"buy_chains": _chain_illustration(c,sketch)
		"buy_rollback":
			var corner := sketch.position
			var cab := PackedVector2Array()
			for point: Vector2 in [Vector2(4,30),Vector2(5,21),Vector2(15,19),Vector2(19,11),Vector2(30,11),Vector2(30,31),Vector2(4,31)]:
				cab.append(corner+point)
			c.draw_polyline(cab,PAPER_INK,1.8,true)
			c.draw_line(corner+Vector2(31,20),corner+Vector2(70,28),FORM_BLUE,2,true)
			c.draw_line(corner+Vector2(29,31),corner+Vector2(67,31),PAPER_INK,1.7,true)
			for axle: int in [12,49,59]:
				c.draw_arc(corner+Vector2(axle,32),4,0,TAU,15,PAPER_INK,1.7,true)
		"service_winch","buy_second_winch": _drum_illustration(c,sketch)
		"buy_aux_tank","buy_reserve_fuel","buy_fuel","buy_yard_pump": _diesel_illustration(c,sketch)
		"buy_snatch_block": _block_illustration(c,sketch)
	c.multiline(r.position+Vector2(90,56),description,c.print_face,16,PAPER_INK,r.size.x-102,2)
	var strip := Rect2(r.position+Vector2(1,92),Vector2(r.size.x-2,33))
	c.draw_rect(strip,ink if enabled else Color("#d4d5c0"))
	c.fitted(strip.grow_individual(-inset,0,-30,0),status,c.scaled,17,c.CREAM if enabled else GREEN,HORIZONTAL_ALIGNMENT_LEFT)
	if enabled:
		c._arrow(Vector2(strip.end.x-16,strip.get_center().y),8,c.CREAM,true)
		c.hit(id,r)

func _diesel_illustration(c, r: Rect2) -> void:
	var mid := r.get_center()
	var pump := Rect2(mid-Vector2(18,20),Vector2(25,38))
	c.draw_rect(pump,PAPER_INK,false,1.8)
	c.draw_rect(Rect2(pump.position+Vector2(4,4),Vector2(17,11)),PAPER_INK,false,1.5)
	c.rule(mid.x-22,mid.y+19,34,PAPER_INK,2)
	c.draw_polyline(PackedVector2Array([mid+Vector2(7,-8),mid+Vector2(12,-7),mid+Vector2(13,11),mid+Vector2(17,14),mid+Vector2(22,10),mid+Vector2(22,-8),mid+Vector2(16,-16)]),PAPER_INK,2,true)
	c.draw_line(mid+Vector2(13,-16),mid+Vector2(18,-10),PAPER_INK,3,true)

func _block_illustration(c, r: Rect2) -> void:
	var mid := r.get_center()
	var wheel := mid+Vector2(5,4)
	c.draw_arc(wheel,13,0,TAU,28,PAPER_INK,1.7,true)
	c.draw_arc(wheel,9,0,TAU,24,PAPER_INK,1.0,true)
	c.draw_circle(wheel,2.2,PAPER_INK)
	c.draw_polyline(PackedVector2Array([mid+Vector2(-17,-12),mid+Vector2(-10,-17),mid+Vector2(10,-10),mid+Vector2(19,1),mid+Vector2(16,12),mid+Vector2(5,20),mid+Vector2(-9,13),mid+Vector2(-17,-12)]),PAPER_INK,1.8,true)
	c.draw_arc(mid+Vector2(-20,-16),6.2,.26*PI,1.94*PI,18,PAPER_INK,2,true)

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
