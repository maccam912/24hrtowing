extends RefCounted
## East approach insert. Both sheets use the survey coordinates written in the save.
const INK := Color("#344e43")
const BLUE := Color("#5c757f")
const LINE := Color("#a4ab91")

static func draw_sheet(c, box: Rect2, transform: Transform2D, detailed: bool) -> void:
	var grid := Color("#b6bda4")
	for x in range(800,2160,200):
		c.draw_line(transform*Vector2(x,-380),transform*Vector2(x,410),grid,1)
	for z in range(-200,401,200):
		c.draw_line(transform*Vector2(730,z),transform*Vector2(2176,z),grid,1)
	var stream := PackedVector2Array()
	for point: Vector2 in [Vector2(1285,-375),Vector2(1347,-215),Vector2(1315,-102),Vector2(1325,0),Vector2(1311,122),Vector2(1355,255),Vector2(1342,410)]:
		stream.append(transform*point)
	c.draw_polyline(stream,Color("#91a5a9"),4 if detailed else 2,true)
	for leg: Array in [[Vector2(728,0),Vector2(2130,0)],[Vector2(800,0),Vector2(800,410)]]:
		c.draw_line(transform*leg[0],transform*leg[1],INK,5 if detailed else 3)
		c.draw_line(transform*leg[0],transform*leg[1],Color("#f2e8cc"),3 if detailed else 1)
	for x in [852,1325,2000]:
		c.draw_circle(transform*Vector2(x,0),3.8,INK)
	if detailed:
		c.text(box.position+Vector2(13,19),"TAMARACK  /  EAST APPROACH",c.scaled,15,INK)
		for row: Array in [[Vector2(755,-103),"COUNTY FF"],[Vector2(844,100),"Memorial"],[Vector2(1200,-76),"CEDAR CREEK"],[Vector2(1564,-24),"HWY 64"],[Vector2(1713,101),"County Highway Garage"]]:
			c.text(transform*row[0],row[1],c.print_face,13,INK)
		c.text(transform*Vector2(985,290),"County Line Farms",c.print_face,11,Color("#748168"))
		var lower := box.end-Vector2(15,13)
		var mile := 400*transform.x.x
		c.rule(lower.x-mile,lower.y,mile,INK,2)
		c.text(lower-Vector2(mile,6),"1 MILE",c.MONO,10,INK)
		c.text(box.position+Vector2(12,box.size.y-14),"N ↑",c.scaled,15,INK)
	c.draw_rect(box,LINE,false,1)

static func directory(c, column: Rect2) -> void:
	var x := column.position.x
	var y := column.position.y
	c.text(Vector2(x,y),"EAST OF COUNTY FF",c.scaled,17,INK)
	c.rule(x,y+8,column.size.x,LINE)
	for row: Array in [[0,"0.1","Tamarack Memorial","Blue H · south side"],[1,"1.3","Cedar Creek","Steel rails · culvert 64–18"],[2,"3.0","County Highway Garage","Crew door · south apron"]]:
		var at := y+38+int(row[0])*62
		c.text(Vector2(x,at),"MI "+row[1],c.MONO,13,BLUE)
		c.text(Vector2(x+60,at),row[2],c.print_face,16,INK)
		c.text(Vector2(x+60,at+19),row[3],c.print_face,13,BLUE)
	c.rule(x,y+214,column.size.x,LINE)
	c.text(Vector2(x,y+241),"COUNTY SERVICE CENTER",c.scaled,15,INK)
	c.text(Vector2(x,y+266),"Highway bays 01–03",c.print_face,15,INK)
	c.text(Vector2(x,y+287),"Sheriff radio annex · east end",c.print_face,15,INK)
