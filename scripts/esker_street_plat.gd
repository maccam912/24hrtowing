extends RefCounted
const INK := Color("#344e43")
const ROAD := Color("#f6edce")
const FADED := Color("#647565")
const NW := Vector2(-199,-108)
const SE := Vector2(147,109)
const INDEX := [
	["A","Cheese works","Boarded dock",Vector2(-164,-20)],
	["B","Fuel & Food","Pumps and coffee",Vector2(-71,18)],
	["C","Esker Tap","Lit blade · doors shut",Vector2(-30,20)],
	["D","Feed co-op","Twin bins",Vector2(37,-23)],
	["E","Fire hall","Hose tower · Tanker 2",Vector2(105,26)],
	["F","Zion Lutheran","Single belfry · west of K",Vector2(-24,73)],
	["G","St. Hedwig’s","Twin steeples · east of K",Vector2(22,80)]]

static func draw_sheet(c, box: Rect2, transform: Transform2D, detailed: bool) -> void:
	c.draw_rect(box,Color("#dddbc2"))
	for x in range(-176,134,23):
		c.draw_line(transform*Vector2(x,-88),transform*Vector2(x,91),Color("#c6c8aa"),.8)
	for z in range(-78,90,22):
		c.draw_line(transform*Vector2(-184,z),transform*Vector2(133,z),Color("#c6c8aa"),.8)
	for line: Array in [[Vector2(-191,0),Vector2(139,0)],[Vector2(0,-100),Vector2(0,101)],[Vector2(-36,-64),Vector2(0,-64)]]:
		c.draw_line(transform*line[0],transform*line[1],INK,6.5 if detailed else 3.2)
		c.draw_line(transform*line[0],transform*line[1],ROAD,4.7 if detailed else 1.9)
	for row: Array in INDEX:
		var at: Vector2 = transform*row[3]
		c.draw_rect(Rect2(at-Vector2(7,5),Vector2(14,10)),Color("#a9b398"))
		if detailed:
			c.draw_circle(at,8.1,INK)
			c.fitted(Rect2(at-Vector2(8,9),Vector2(16,18)),row[0],c.scaled,12,c.WHITE)
	if detailed:
		c.text(box.position+Vector2(13,20),"ESKER  /  VILLAGE CENTER",c.scaled,15,INK)
		c.text(transform*Vector2(-120,-5),"MAIN STREET  •  HWY 64",c.MONO,11,INK)
		c.text(transform*Vector2(4,44),"COUNTY K",c.MONO,11,INK)
		c.text(transform*Vector2(-58,-71),"Brandt yard",c.print_face,13,INK)
		c.text(transform*Vector2(31,-68),"Water tower",c.print_face,13,INK)
		c.draw_circle(transform*Vector2(44,-63),2.5,INK)
		c.text(box.end-Vector2(33,15),"N ↑",c.scaled,13,INK)
	c.draw_rect(box,Color("#87917a"),false,1)

static func directory(c, column: Rect2) -> void:
	var x := column.position.x
	var y := column.position.y
	c.text(Vector2(x,y),"MAIN STREET  /  WEST TO EAST",c.scaled,16,INK)
	c.rule(x,y+7,column.size.x,FADED)
	for i in INDEX.size():
		if i==5:
			c.text(Vector2(x,y+218),"SOUTH ON COUNTY K",c.scaled,15,INK)
			c.rule(x,y+225,column.size.x,FADED)
		var row := y+29+i*38+(25 if i>=5 else 0)
		c.draw_circle(Vector2(x+7,row-3),7.1,INK)
		c.fitted(Rect2(x-1,row-12,16,18),INDEX[i][0],c.scaled,11,c.WHITE)
		c.text(Vector2(x+22,row),INDEX[i][1],c.print_face,16,INK)
		c.text(Vector2(x+22,row+16),INDEX[i][2],c.print_face,12,FADED)
