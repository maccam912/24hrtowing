extends RefCounted
## A fifth of a tank by county plow when the wrecker runs dry away from a pump.
## The 18-minute radio ETA passes at a shift minute per second while the
## operator waits, and the plow drives up to the truck to hand over the can.

const FuelPlow := preload("res://scripts/fuel_plow.gd")
const ShopAccount := preload("res://scripts/shop_account.gd")

## Minutes until the plow arrives. Zero when nothing is on order.
var wait_left := 0.0
var plow: FuelPlow

## A stopped, dry wrecker with nothing on order can call for a can.
func needed(game) -> bool:
	return wait_left <= 0.0 and game.rig.in_cab and game.rig.is_stopped() and game.rig.fuel <= 0.0

func en_route() -> bool:
	return wait_left > 0.0

func eta_text() -> String:
	return "County plow en route · %d min to fuel delivery" % ceili(wait_left)

func request(game) -> bool:
	if not needed(game):
		return false
	clear_plow()
	wait_left = ShopAccount.CAN_ETA_MINUTES
	game.speak("COUNTY PLOW","Copy, Brandt. Relief plow here. I have a can in the box. Give me %d minutes." % ShopAccount.CAN_ETA_MINUTES)
	return true

## Runs alongside the shift clock. While a can is on order the wait also adds
## 59 shift seconds for every second played, and the delivery lands at zero.
func advance(game, dt: float) -> void:
	var at: Vector3 = game.rig.get_truck_position()
	if wait_left <= 0.0:
		if is_instance_valid(plow) and plow.leave(dt,at):
			clear_plow()
		return
	if not is_instance_valid(plow):
		plow = FuelPlow.new()
		plow.setup(game.county,at)
	var elapsed := minf(dt, wait_left)
	game.shift_seconds += elapsed * 59.0
	wait_left -= elapsed
	plow.approach(wait_left)
	if wait_left <= 0.0:
		_deliver(game)

func _deliver(game) -> void:
	var account = game.account
	var previous_due: float = account.fuel_due
	game.rig.fuel = minf(1.0, game.rig.fuel + account.roadside_can())
	game.rig.info_timer = 0.0
	var iou := snappedf(account.fuel_due - previous_due, 0.01)
	var receipt := "$%.2f paid." % (ShopAccount.CAN_PRICE - iou)
	if iou > 0.0:
		receipt += " $%.2f on the county IOU." % iou
	game.speak("COUNTY PLOW","Can's in, Brandt. You've got a fifth of a tank. " + receipt)
	game.save()

## Diesel from a pump or the reserve makes an undelivered can unnecessary.
func cancel_after_refuel(game) -> void:
	if wait_left > 0.0 and game.rig.fuel > 0.0:
		wait_left = 0.0
		game.speak("DISPATCH","Copy, Brandt. I'll cancel that fuel delivery.")

## Drops any order without a delivery, as when the county brings the truck in.
func reset() -> void:
	wait_left = 0.0
	clear_plow()

func clear_plow() -> void:
	if is_instance_valid(plow):
		plow.hide()
		plow.queue_free()
	plow = null

func restore(minutes: float) -> void:
	clear_plow()
	wait_left = clampf(minutes, 0.0, ShopAccount.CAN_ETA_MINUTES)
