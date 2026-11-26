extends SceneTree

const Account := preload("res://scripts/shop_account.gd")
const Dispatch := preload("res://scripts/dispatch.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr(message)

func _initialize() -> void:
	var account := Account.new()
	check(is_equal_approx(Account.CAN_PRICE, Account.TANK_PRICE * Account.CAN_FILL * 2) and Account.CAN_PRICE == 19.2, "a county can costs exactly double the same volume at the pump")
	check(account.earned == 0 and account.cash == Account.OPENING_CASH, "opening till is separate from earned income")
	check(account.file_invoice(60.0, 1) == 0.0 and not account.buy("chains"), "pending money cannot buy parts")
	account.file_invoice(76.23, 2)
	var batch := account.file_invoice(60.0, 3)
	check(is_equal_approx(batch, 196.23) and account.pending == 0.0 and is_equal_approx(account.earned, batch), "three carbon copies deposit their exact total")
	check(account.buy("snatch_block") and not account.buy("snatch_block") and not account.buy("bad stock number"), "only a first valid order charges")
	var before_fill := account.cash
	var sale := account.buy_fuel(.625)
	check(sale.cost == 18.0 and sale.fuel_after == 1.0 and is_equal_approx(account.cash, before_fill - sale.cost), "yard diesel bills the missing fuel")
	check(account.buy_fuel(1.0).cost == 0.0, "a full tank costs nothing")
	check(account.pay_repair(), "operator can book service with cleared funds")
	before_fill = account.cash
	var quote := account.fuel_quote(0.0)
	check(account.cash == before_fill and quote.cost == before_fill and is_equal_approx(quote.fuel_after, before_fill/Account.TANK_PRICE), "short funds quote precisely the affordable fuel")
	check(account.buy_fuel(0) == quote and account.cash == 0 and account.buy_fuel(.2).fuel_after == .2, "partial refill cannot overdraw the till")
	check(account.roadside_can() == Account.CAN_FILL and account.fuel_due == Account.CAN_PRICE and account.cash == 0, "county advances a can to a broke operator")
	var restored := Account.new()
	restored.restore({"account":JSON.parse_string(JSON.stringify(account.save_state()))})
	check(restored.save_state() == account.save_state(), "gear, cleared funds, pending charges and earnings survive resume")
	restored.file_invoice(60, 4)
	restored.file_invoice(60, 5)
	check(restored.file_invoice(60, 6) == 180 and restored.cash == 180 - Account.CAN_PRICE and restored.fuel_due == 0, "next batch settles the county advance")
	check(is_equal_approx(restored.earned, 376.23), "spending and county advances never reduce gross earned")
	restored.restore({"paid":11.25, "pending":63.25, "slips":[{"pay":130.0},{"pay":63.25}], "rig":{"chains":true}})
	check(restored.cash == 11.25 and restored.pending == 63.25 and restored.earned == 193.25 and restored.owns("chains") and not restored.owns("snatch_block"), "migrate historic income from invoices, keeping actual available cash and fitted gear")
	check(restored.roadside_can() == Account.CAN_FILL and restored.cash == 0.0 and is_equal_approx(restored.fuel_due,7.95), "roadside fuel first uses remaining cash")
	test_heavy_dispatch()
	if not failures:
		print("CHECKS PASSED — earned, batched and spent dollars, fuel advances, save migration and heavy rotation premiums")
	quit(int(failures > 0))

func test_heavy_dispatch() -> void:
	var slips := []
	var heavy_calls := 0
	var milk_calls := 0
	for i in 40:
		var base := Dispatch.ordinary(i, 22, slips)
		check(not base.has("heavy_recovery") and base.variant not in [Dispatch.HEAVY_VARIANT,Dispatch.Snowplow.VARIANT], "the standard line can serve every base rotation")
		var job := Dispatch.ordinary(i, 22, slips, true)
		var slip := Dispatch.issue_slip(job, 100, 101, 102, 5, "03:35")
		var ordinary := Dispatch.issue_slip(base, 100, 101, 102, 5, "03:35")
		if job.id == "stuck_plow":
			check(job.kind == "ditch" and job.variant == Dispatch.Snowplow.VARIANT and slip.heavy_fee == Dispatch.HEAVY_FEE, "county plow is a heavy ditch pull")
		elif job.id == "milk_tanker":
			milk_calls += 1
			check(job.kind == "hazard" and slip.heavy_fee == Dispatch.HEAVY_FEE and slip.storage == 0 and slip.gallons == job.gallons,"milk recovery pays the heavy rate and carries its transfer in lieu of yard storage")
		elif job.get("heavy_recovery", false):
			heavy_calls += 1
			check(job.kind == "hazard" and job.variant == Dispatch.HEAVY_VARIANT and "snatch block" in job.dispatch and job.vin != Dispatch.Legacy.JOBS.hold.vin, "upgraded dispatch can issue a separate heavy pickup")
			check(slip.heavy_fee == Dispatch.HEAVY_FEE and is_equal_approx(slip.pay - ordinary.pay, slip.heavy_fee), "heavy recovery is itemized and paid")
		else:
			check(slip.heavy_fee == 0 and slip.pay == ordinary.pay, "ordinary calls keep their county rate")
		slips.append(slip)
	check(heavy_calls >= 3, "heavy work recurs alongside ordinary paid calls")
	check(milk_calls >= 1, "the fitted block also opens farm transfer work")
