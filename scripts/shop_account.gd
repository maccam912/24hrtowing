extends RefCounted

const OPENING_CASH := 35.0
const PRICES := {"chains":95.0, "snatch_block":175.0}
const REPAIR_PRICE := 24.0
const TANK_PRICE := 48.0
const CAN_PRICE := 18.0
const CAN_FILL := 0.20

var cash := OPENING_CASH
var pending := 0.0
var earned := 0.0
var fuel_due := 0.0
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
	cash = snappedf(cash + batch - withheld, 0.01)
	fuel_due = snappedf(fuel_due - withheld, 0.01)
	pending = 0.0
	return batch

func _spend(price: float) -> bool:
	if cash < price:
		return false
	cash = snappedf(cash - price, 0.01)
	return true

func buy(id: String) -> bool:
	if not PRICES.has(id) or owns(id) or not _spend(PRICES[id]):
		return false
	equipment[id] = true
	return true

func pay_repair() -> bool:
	return _spend(REPAIR_PRICE)

func fuel_quote(fuel: float) -> Dictionary:
	var level := clampf(fuel, 0.0, 1.0)
	var fill_price := snappedf((1.0 - level) * TANK_PRICE, 0.01)
	var cost := minf(cash, fill_price)
	var fuel_after := level
	if cost > 0.0:
		fuel_after = 1.0 if cost == fill_price else level + cost / TANK_PRICE
	return {"cost":cost, "fuel_after":fuel_after}

func buy_fuel(fuel: float) -> Dictionary:
	var sale := fuel_quote(fuel)
	_spend(sale.cost)
	return sale

func roadside_can() -> float:
	var charge := minf(cash, CAN_PRICE)
	_spend(charge)
	fuel_due = snappedf(fuel_due + CAN_PRICE - charge, 0.01)
	return CAN_FILL

func save_state() -> Dictionary:
	return {"cash":cash, "pending":pending, "earned":earned, "fuel_due":fuel_due,
		"equipment":equipment.duplicate()}

func restore(save: Dictionary) -> void:
	equipment.clear()
	if save.has("account"):
		var account: Dictionary = save.account
		cash = snappedf(float(account.cash), 0.01)
		pending = snappedf(float(account.pending), 0.01)
		earned = snappedf(float(account.earned), 0.01)
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
