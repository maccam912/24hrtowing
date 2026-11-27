extends RefCounted

enum { OFF, LOW, HIGH }
const CLOSED_TARGETS := [0.12,1.0,1.0]
const OPEN_TARGETS := [0.0,0.50,0.76]
const CLOSED_RATES := [0.0025,0.012,0.027]
const OPEN_RATES := [0.008,0.016,0.030]
var blower := LOW
var cracked := false
var air := 1.0
var warned := false

func advance(rig, dt: float) -> void:
	var power: int = blower if rig.fuel > 0 else OFF
	var target := OPEN_TARGETS if cracked else CLOSED_TARGETS
	var rate := OPEN_RATES if cracked else CLOSED_RATES
	var warm_lane: float = rig.road_contact.y
	var cabin_target := lerpf(float(target[power]),1.,warm_lane)
	air = move_toward(air,cabin_target,dt*maxf(float(rate[power]),warm_lane*.05))
	if rig.in_cab:
		rig.warmth = move_toward(rig.warmth,maxf(air,rig.sighting_calm),dt*(0.023 if power == HIGH else 0.014))
	elif rig.world and rig.world.has_method("is_heated_shelter") and rig.world.is_heated_shelter(rig.foot):
		rig.warmth = minf(1,rig.warmth+dt*.014)
	else:
		var cooling := lerpf(-.0017,.017,maxf(rig.sighting_calm,warm_lane*.65))
		if rig.coffee_left > 0:
			rig.coffee_left = maxf(0,rig.coffee_left-dt)
			cooling = maxf(0,cooling)
		rig.warmth = clampf(rig.warmth+dt*cooling,0,1)
	if rig.warmth > .32:
		warned = false
	elif rig.warmth < .16 and not rig.in_cab and not warned and rig.info_timer <= 0:
		warned = true
		rig.show_note("Fingers are getting stiff. Could use the cab heater.",6.)

func save_state() -> Dictionary:
	return {"blower":blower,"cracked":cracked,"air":air}

func restore(data: Dictionary) -> void:
	blower = clampi(int(data.get("blower",LOW)),OFF,HIGH)
	cracked = bool(data.get("cracked",false))
	air = clampf(float(data.get("air",1.0)),0.,1.)

static func draw_panel(c, p: Rect2, s: Dictionary) -> void:
	var size := Vector2(minf(686,p.size.x-36),362)
	var face := Rect2(p.get_center()-size*.5,size)
	var cream := Color("#ded8b8")
	var enamel := Color("#37403e")
	var metal := Color("#a39b83")
	c.switch_face(face.grow(7),metal)
	c.switch_face(face,enamel)
	for x: float in [face.position.x+16,face.end.x-16]:
		for y: float in [face.position.y+16,face.end.y-16]:
			c.draw_circle(Vector2(x,y),6,metal)
			c.draw_line(Vector2(x-3,y+2),Vector2(x+3,y-2),enamel,2)
	var x := face.position.x+36
	var y := face.position.y+30
	var w := face.size.x-72
	c.fitted(Rect2(x,y,w,38),"CAB HEATER",c.scaled,26,cream,HORIZONTAL_ALIGNMENT_LEFT)
	c.rule(x,y+44,w,metal)
	var slot := Rect2(x+5,y+130,w-10,10)
	c.switch_face(slot,Color("#171d1d"),true)
	var fan := int(s.get("blower",LOW))
	var ids := ["blower_off","blower_low","blower_high"]
	for i in 3:
		var button := Rect2(x+i*w/3.,y+51,w/3.,108)
		var center := button.get_center().x
		var focused: bool = c.hover == ids[i]
		c.fitted(Rect2(button.position+Vector2(0,5),Vector2(button.size.x,38)),["OFF","LOW","HIGH"][i],c.MONO,23,c.AMBER if focused or fan == i else cream)
		c.draw_line(Vector2(center,y+103),Vector2(center,y+122),cream,2)
		if i == fan:
			var lever := Rect2(center-22,y+113,44,35)
			c.switch_face(lever,metal)
			for bar in range(-1,2):
				c.draw_line(lever.get_center()+Vector2(bar*7,-10),lever.get_center()+Vector2(bar*7,10),enamel,2)
		if focused:
			c.draw_rect(button.grow(-3),c.AMBER,false,2)
		c.hit(ids[i],button)
	c.rule(x,y+177,w,metal)
	var latch := Rect2(x,y+193,w*.54,78)
	c.button("window_latch",latch,"Close window" if s.get("window_open",false) else "Crack window")
	var air := float(s.get("cab_air",1.0))
	var state := "WARM" if air > .68 else ("COOL" if air > .35 else "COLD")
	var panel := Rect2(latch.end.x+16,latch.position.y,w-latch.size.x-16,78)
	c.switch_face(panel,Color("#202821"),true)
	c.fitted(Rect2(panel.position+Vector2(3,5),Vector2(panel.size.x-6,29)),"CAB AIR",c.MONO,14,cream)
	c.fitted(Rect2(panel.position+Vector2(3,29),Vector2(panel.size.x-6,38)),state,c.scaled,23,c.AMBER)
	c.fitted(Rect2(x,y+276,w,33),"DRIVER WINDOW   /   "+("OPEN" if s.get("window_open",false) else "SHUT"),c.MONO,15,cream,HORIZONTAL_ALIGNMENT_LEFT)

## The blower switch, window latch and cab air the heater page draws.
func view() -> Dictionary:
	return {"blower":blower,"window_open":cracked,"cab_air":air}
