extends RefCounted
## Reads and writes small JSON save files, such as lifetime stats (#32),
## settings (#20) and the auto-saved game (#18).
##
## Writes go to a temporary file first and then replace the old one, so a
## crash mid-write leaves the previous save intact.


## Returns the file's top-level object, or {} if the file is missing or is
## not a JSON object.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	var data = json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
	if not data is Dictionary:
		push_warning("Save file %s is not a JSON object; ignoring it" % path)
		return {}
	return data


## Returns true if the file was written.
static func write(path: String, data: Dictionary) -> bool:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write %s: %s" % [temp, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(temp, path)
	if err != OK:
		push_warning("Could not replace %s: %s" % [path, error_string(err)])
		return false
	return true


static func remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
