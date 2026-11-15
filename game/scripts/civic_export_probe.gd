## 文件用途：在真实Windows导出包内跨进程验证税率满意度、午夜结算和政务账单持久化。
extends RefCounted

# 验收模块：写进程选择低税并保存午夜前，读进程续接后改高税，验证两种政策收益不可混用。
static func run(main: Control, mode: String) -> int:
	if mode == "write":
		main._set_tax_policy("low")
		main.world.paused = false
		main.clock.advance(119)
		main.world.paused = true
		if main.world.resources["gold"] != 300 or main.world.satisfaction != 50 or not main.store.save_world(main.world):
			return 1
	else:
		main._load()
		if main.world.tax_policy != "low" or main.world.satisfaction != 50 or main.world.tick != 119:
			return 1
		main.world.paused = false
		main.clock.advance(1)
		if main.world.resources["gold"] != 315 or main.world.satisfaction != 52 or main.world.last_civic_ledger["policy"] != "low":
			return 1
		main._set_tax_policy("high")
		main.clock.advance(120)
		main.world.paused = true
		main._refresh()
		if main.world.resources["gold"] != 346 or main.world.satisfaction != 49 or not main.civic_bill_label.text.contains("税收入库31") or not main.store.save_world(main.world):
			return 1
		var reopened: RefCounted = main.store.load_world()
		if reopened == null or reopened.last_civic_ledger != main.world.last_civic_ledger:
			return 1
	print("EXPORT_CIVIC_PASS: ", mode)
	return 0
