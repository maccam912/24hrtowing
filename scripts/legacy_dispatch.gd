extends RefCounted

# Version-one ledgers kept the contract index only. This reconstructs their active job.
const JOBS := {
	"angie": {"kind":"ditch","location":"County K · St. Hedwig’s","vehicle":"Blue compact sedan","plate":"KRM 612","vin":"1BTCL42A8WN118274","point":Vector3(-8,0,146),"angle":0.29,"person":"Angie Kraemer"},
	"dairy": {"kind":"hazard","location":"Hendricks Rd · Brzezinski Dairy","vehicle":"Gray station wagon","plate":"BTN 701","vin":"2BRWK15P7PB226310","point":Vector3(112,0,394),"angle":1.47},
	"farm": {"kind":"ditch","location":"Kolpack Rd · Lindquist place","vehicle":"Gary’s winter sedan","plate":"GKL 283","vin":"1BTCM82B1TN185903","point":Vector3(409,0,246),"angle":-0.34,"person":"Gary Lindquist"},
	"bridge": {"kind":"hazard","location":"Highway 64 · river bridge","vehicle":"Taped four-door sedan","plate":"EWG 044","vin":"2BTDL42P2RJ704450","point":Vector3(-435,0,6),"angle":1.45},
	"hold": {"kind":"hold","location":"Swamp Rd · Section 3 corner","vehicle":"White county survey pickup","plate":"WI CO 038","vin":"1BTPK18S4VK044506","point":Vector3(314,0,-409),"angle":0.38,"person":"Deputy J. Kowalski"},
}
const OPENING := ["angie","dairy","farm","bridge","hold"]
const ORDINARY := {
	"student":{"base":"angie","vehicle":"Compact sedan","person":"Stranded student","reply":"student"},
	"rural":{"base":"farm","vehicle":"Two-door sedan","person":"Delivery driver","reply":"rural"},
	"river":{"base":"bridge","vehicle":"Checked sedan"},
	"milk":{"base":"dairy","vehicle":"Checked station wagon"},
}

static func ticket(completed: int, lines: Dictionary) -> Dictionary:
	var id: String
	var base: String
	var job: Dictionary
	if completed < OPENING.size():
		id = OPENING[completed]
		base = id
		job = JOBS[base].duplicate()
	else:
		var since_hold := completed - OPENING.size()
		var rng := RandomNumberGenerator.new()
		rng.seed = 241991 + since_hold * 79571
		var choice := rng.randi_range(0,1)
		id = ["student","rural"][choice] if since_hold%2 == 0 else ["river","milk"][choice]
		var variation: Dictionary = ORDINARY[id]
		base = variation.base
		job = JOBS[base].duplicate()
		job.merge(variation,true)
		job.plate = "%s %03d" % [["ETK","AKP","JRG","WFS"][rng.randi_range(0,3)],rng.randi_range(101,998)]
		job.vin = "1BTRS39C5WJ%06d" % rng.randi_range(1000,998000)
	job.id = id
	job.route = base
	job.reply = job.get("reply","angie" if base == "angie" else "gary")
	job.number = 1001 + completed
	job.dispatch = lines[id + "_call"][1]
	job.directions = lines[base + "_dir"][1]
	return job
