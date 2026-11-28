extends RefCounted
## Brandt's office counter: diesel by the tank, winch service and equipment
## from the yard catalog. The shop account moves the money; the counter
## decides what it will sell right now and writes the receipt.

const DieselNozzle := preload("res://scripts/diesel_nozzle.gd")
const Reserve := preload("res://scripts/reserve_tank.gd")
const RECEIPTS := {
	"rollback":"Keys in the carrier. Walk to its driver’s door by the office.",
	"aux_tank":"Reserve fitted behind the cab. Fill it here or at the pumps.",
	"second_winch":"Auxiliary winch fitted. Arlene can dispatch freight calls on US 59.",
	"west_hold":"West Hold 2 ready. Sheriff’s order book is under the metal hood beside its chain.",
	"west_lot":"West gate open. Twelve numbered storage spaces on the back lot.",
	"yard_pump":"Meter and hose fitted to the bulk tank by storage.",
	"coffee_maker":"Coffee’s on at the bench beside the office.",
	"mirrors":"Heater elements fitted to both mirrors.",
	"lamps":"Driving bar and pillar spot fitted. Aim the spot by looking.",
	"chains":"Drive-axle chains fitted.",
	"snatch_block":"Snatch block fitted. Heavy pulls cleared for dispatch.",
	"scanner":"Crystals fitted. Tune the cab scanner to Sheriff or Garage.",
}
# Parts that hang on the wrecker, so the counter won't fit them to the carrier.
const WRECKER_ONLY := ["second_winch","aux_tank","snatch_block"]
const SERVICE_THRESHOLD := 0.10

## The last sale's receipt, cleared when the catalog opens.
var receipt := ""

func open() -> void:
	receipt = ""

## The carrier joins the catalog with the twelfth ordinary job.
static func fleet_offered(game) -> bool:
	return game.account.owns("rollback") or game.completed >= 12

## Scanner crystals are offered once the operator has worked with the sheriff.
static func scanner_available(game) -> bool:
	return game.signed_card or game.held or game.campaign.released or game.account.owns("scanner")

## Whether the catalog will sell [param part] to this operator now.
static func offered(game, part: String) -> bool:
	if part == "rollback" and not fleet_offered(game): return false
	if part in WRECKER_ONLY and game.rig.rollback_active: return false
	if part == "scanner" and not scanner_available(game): return false
	if part == "aux_tank" and game.campaign.stage < 1: return false
	if part == "west_hold" and not game.account.owns("west_lot"): return false
	if part == "second_winch" and (not game.heavy_job_filed or not game.account.owns("snatch_block")): return false
	return true

## Rings up one catalog line. Returns true when money changed hands.
func purchase(game, id: String) -> bool:
	var rig = game.rig
	var account = game.account
	if id in ["buy_fuel","buy_reserve_fuel"]:
		var reserve := id == "buy_reserve_fuel"
		if not game.can_refuel() or (reserve and (not account.owns("aux_tank") or rig.rollback_active)): return false
		var sale := DieselNozzle.buy(game,reserve)
		if sale.cost <= 0: return false
		var pct := roundi(100*float(sale.fuel_after)/(Reserve.CAPACITY if reserve else 1.0))
		receipt = "Diesel   $%.2f   ·   %s %d%%" % [sale.cost,"Reserve" if reserve else "Tank",pct]
		return true
	if not game.at_office() or not game.truck_in_yard():
		return false
	if id == "service_winch":
		if rig.wear < SERVICE_THRESHOLD or not account.pay_repair():
			return false
		rig.wear = 0.0
		receipt = "Winch serviced. Cable and drum ready."
		return true
	var part := id.trim_prefix("buy_")
	if not offered(game,part) or not account.buy(part):
		return false
	game.fit_equipment()
	if part == "rollback":
		game.fleet.receive(rig)
	receipt = RECEIPTS.get(part,"")
	return true
