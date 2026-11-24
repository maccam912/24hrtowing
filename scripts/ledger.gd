extends RefCounted

const FILE := "user://brandt-operations.json"
const VERSION := 3

static func read() -> Dictionary:
	for name in [FILE, FILE+".previous"]:
		if not FileAccess.file_exists(name):
			continue
		var f := FileAccess.open(name, FileAccess.READ)
		if f:
			var value = JSON.parse_string(f.get_as_text())
			if value is Dictionary and int(value.get("version",0)) in [1,2,VERSION] and value.has("rig") and value.has("completed"):
				return value
	return {}

static func write(state: Dictionary) -> bool:
	var path := ProjectSettings.globalize_path(FILE)
	var f := FileAccess.open(path+".new",FileAccess.WRITE)
	if not f:
		return false
	state.version = VERSION
	f.store_string(JSON.stringify(state))
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	if not ok:
		return false
	if FileAccess.file_exists(path):
		if DirAccess.rename_absolute(path,path+".previous") != OK:
			return false
	return DirAccess.rename_absolute(path+".new",path) == OK
