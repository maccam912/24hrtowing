extends RefCounted

const FILE := "user://brandt-operations.json"
const VERSION := 5

## True when the newest readable save was written by a later build. This build
## cannot load it, and its autosave would rotate that shift out of the backup
## within two writes, so it plays without saving and leaves the file alone.
static var newer_build := false

static func read(file := FILE) -> Dictionary:
	newer_build = false
	for name in [file, file+".previous"]:
		if not FileAccess.file_exists(name):
			continue
		var f := FileAccess.open(name, FileAccess.READ)
		if f:
			# A damaged file falls through to the backup without logging an engine error.
			var json := JSON.new()
			if json.parse(f.get_as_text()) != OK or not json.data is Dictionary:
				continue
			var value: Dictionary = json.data
			var version := int(value.get("version",0))
			if version > VERSION:
				newer_build = true
				return {}
			if version in range(1,VERSION+1) and value.has("rig") and value.has("completed"):
				return value
	return {}

static func write(state: Dictionary, file := FILE) -> bool:
	if newer_build:
		return false
	var path := ProjectSettings.globalize_path(file)
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
