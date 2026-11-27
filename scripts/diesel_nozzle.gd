extends RefCounted
## The metered nozzle at Esker's pumps and at Brandt's bulk tank, and the
## reserve tank's transfer switch behind the cab. Holding a nozzle rings up
## whole cents at $3.60 a second from cash on hand.

const Fittings := preload("res://scripts/yard_fittings.gd")
const Reserve := preload("res://scripts/reserve_tank.gd")
const CENTS_PER_SECOND := 360.0

## Dollars rung up since the pump page opened.
var sale := 0.0
## Fractional cents not yet on the rollers.
var cents := 0.0
var at_esker := false
var reserve := false

func open(esker: bool) -> void:
	at_esker = esker
	reserve = false
	sale = 0.0
	cents = 0.0

## The tank selector turns between squeezes once the reserve is fitted.
func select_tank(game, id: String) -> void:
	if game.desk.page == "bulk_pump" and game.account.owns("aux_tank") and not game.rig.rollback_active and not game.desk.nozzle_held():
		reserve = id == "tank_reserve"
		cents = 0.0

static func at_yard_nozzle(game) -> bool:
	return game.county.yard_dispenser and not game.rig.in_cab and game.is_facing(Fittings.NOZZLE,2.9)

func can_dispense(game) -> bool:
	if at_esker:
		return game.at_pump() and game.can_refuel()
	return at_yard_nozzle(game) and game.rig.is_stopped() and game.rig.get_truck_position().distance_to(Fittings.NOZZLE) < 13.0

## Sells diesel into the main or reserve tank, up to [param budget] dollars.
## The office counter fills by the tank; the nozzle buys a few cents at a time.
static func buy(game, to_reserve: bool, budget := INF) -> Dictionary:
	var rig = game.rig
	var initial: float = rig.reserve_fuel if to_reserve else rig.fuel
	var capacity: float = Reserve.CAPACITY if to_reserve else 1.0
	var bought: Dictionary = game.account.buy_fuel(initial,budget,capacity)
	if bought.cost > 0.0:
		if to_reserve:
			rig.reserve_fuel = bought.fuel_after
			rig.aux_tank.set_reading(rig.reserve_fuel)
		else:
			rig.fuel = bought.fuel_after
			game.fuel_can.cancel_after_refuel(game)
	return bought

## Meters the held nozzle. Returns true when diesel went into a tank.
func pump(game, dt: float) -> bool:
	if not game.desk.nozzle_held() or not can_dispense(game) or (reserve and (not game.account.owns("aux_tank") or game.rig.rollback_active)):
		return false
	cents += dt*CENTS_PER_SECOND
	var whole := floori(cents)
	cents -= whole
	if whole <= 0:
		return false
	var bought := buy(game,reserve,whole/100.0)
	if bought.cost <= 0.0:
		return false
	sale = snappedf(sale+bought.cost,.01)
	return true

## Moves diesel from the reserve into the main tank while the switch is held.
## Returns true when diesel moved.
static func transfer(game, dt: float) -> bool:
	var rig = game.rig
	if not rig.aux_tank:
		return false
	var amount := 0.0
	if game.desk.nozzle_held() and rig.reserve_valve_in_reach():
		amount = minf(Reserve.TRANSFER_RATE*dt,minf(1.0-rig.fuel,rig.reserve_fuel))
	if amount > 0.0:
		rig.fuel += amount
		rig.reserve_fuel -= amount
		game.fuel_can.cancel_after_refuel(game)
	rig.aux_tank.set_reading(rig.reserve_fuel,amount>0.0)
	return amount > 0.0

## What the pump page draws.
func view(game) -> Dictionary:
	return {"nozzle_ready":can_dispense(game),"nozzle_sale":sale,"nozzle_esker":at_esker,"nozzle_reserve":reserve}
