extends RefCounted

const OPENING_CASH := 35.0
const PRICES := {"chains":95.0, "snatch_block":175.0, "scanner":65.0, "mirrors":55.0, "lamps":115.0, "yard_pump":145.0, "coffee_maker":39.0, "west_lot":245.0, "west_hold":185.0, "second_winch":340.0, "aux_tank":155.0}
const REPAIR_PRICE := 24.0
const YARD_RECOVERY_PRICE := 24.0
const COFFEE_PRICE := 0.75
const TANK_PRICE := 48.0
const CAN_FILL := 0.20
const CAN_PRICE := snappedf(TANK_PRICE * CAN_FILL * 2.0, 0.01)
const CAN_ETA_MINUTES := 18

var cash := OPENING_CASH
var pending := 0.0
var earned := 0.0
var fuel_due := 0.0
var recovery_due := 0.0
var equipment := {}

func owns(id: String) -> bool:
	return equipment.has(id)

func file_invoice(pay: float, completed_after: int) -> float:
	earned = snappedf(earned + pay, 0.01)
	pending = snappedf(pending + pay, 0.01)
	if completed_after % 3 != 0:
		return 0.0
	var batch := pending
	var withheld := minf(batch, fuel_due)
	var recovery_payment := minf(batch - withheld, recovery_due)
	cash = snappedf(cash + batch - withheld - recovery_payment, 0.01)
	fuel_due = snappedf(fuel_due - withheld, 0.01)
	recovery_due = snappedf(recovery_due - recovery_payment, 0.01)
	pending = 0.0
	return batch

func _spend(price: float) -> bool:
	if cash < price:
		return false
	cash = snappedf(cash - price, 0.01)
	return true

func charge_with_credit(price: float) -> float:
	var paid := minf(cash, price)
	_spend(paid)
	return snappedf(price - paid, 0.01)

func pay_yard_recovery() -> float:
	var unpaid := charge_with_credit(YARD_RECOVERY_PRICE)
	recovery_due = snappedf(recovery_due + unpaid, 0.01)
	return unpaid

func buy(id: String) -> bool:
	if not PRICES.has(id) or owns(id) or not _spend(PRICES[id]):
		return false
	equipment[id] = true
	return true

func pay_repair() -> bool:
	return _spend(REPAIR_PRICE)

func buy_coffee() -> bool:
	return _spend(COFFEE_PRICE)

func fuel_quote(fuel: float, budget := INF, capacity := 1.0) -> Dictionary:
	var level := clampf(fuel, 0.0, capacity)
	var fill_price := snappedf((capacity - level) * TANK_PRICE, 0.01)
	var cost := minf(minf(cash,fill_price),maxf(0.0,budget))
	var fuel_after := level
	if cost > 0.0:
		fuel_after = capacity if cost == fill_price else level + cost / TANK_PRICE
	return {"cost":cost, "fuel_after":fuel_after}

func buy_fuel(fuel: float, budget := INF, capacity := 1.0) -> Dictionary:
	var sale := fuel_quote(fuel,budget,capacity)
	_spend(sale.cost)
	return sale

func roadside_can() -> float:
	fuel_due = snappedf(fuel_due + charge_with_credit(CAN_PRICE), 0.01)
	return CAN_FILL

func save_state() -> Dictionary:
	return {"cash":cash, "pending":pending, "earned":earned, "fuel_due":fuel_due,
		"equipment":equipment.duplicate(), "recovery_due":recovery_due}

func restore(save: Dictionary) -> void:
	equipment.clear()
	recovery_due = 0.0
	if save.has("account"):
		var account: Dictionary = save.account
		cash = snappedf(float(account.cash), 0.01)
		pending = snappedf(float(account.pending), 0.01)
		earned = snappedf(float(account.earned), 0.01)
		recovery_due = snappedf(float(account.get("recovery_due", 0.0)), 0.01)
		fuel_due = snappedf(float(account.get("fuel_due", 0.0)), 0.01)
		for id: String in PRICES:
			if account.get("equipment", {}).get(id, false):
				equipment[id] = true
		return
	# The old paid figure was the till after expenses. Filed slips retain their
	# original invoice amounts, including money still waiting on the county.
	cash = snappedf(float(save.get("paid", 0.0)), 0.01)
	pending = snappedf(float(save.get("pending", 0.0)), 0.01)
	fuel_due = 0.0
	var billed := 0.0
	for slip: Dictionary in save.get("slips", []):
		billed += float(slip.get("pay", 0.0))
	earned = snappedf(maxf(billed, cash + pending), 0.01)
	if save.get("rig", {}).get("chains", false):
		equipment["chains"] = true
