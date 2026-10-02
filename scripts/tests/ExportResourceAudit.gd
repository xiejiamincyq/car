extends SceneTree
## Read-only logical resource audit. This is NOT an exported-PCK inspection.
const TrackCatalog = preload("res://scripts/catalog/track_catalog.gd")
const VehicleCatalog = preload("res://scripts/catalog/vehicle_catalog.gd")
const MusicCatalog = preload("res://scripts/audio/music_catalog.gd")
const EXCLUDED_DIRS := ["tests", "tmp", "docs", "scripts/tests", "scripts/tools", "scripts/art", "art", "tasks", "exports", "build", "assets/environment", "assets/tracks"]

func _init() -> void:
	var config := ConfigFile.new()
	var error := config.load("res://export_presets.cfg")
	var manifest := runtime_manifest()
	var errors := validate(config, manifest) if error == OK else PackedStringArray(["Cannot read export_presets.cfg"])
	for message in errors:
		print("EXPORT_RESOURCE_AUDIT_FAIL " + message)
	print("EXPORT_RESOURCE_AUDIT_COMPLETE logical_resources=%d failures=%d exported_pack_checked=false" % [manifest.size(), errors.size()])
	quit(0 if errors.is_empty() else 1)

static func dynamic_resources() -> PackedStringArray:
	var paths := PackedStringArray()
	for track in TrackCatalog.all():
		for side in ["left", "right"]:
			for path in track["environment_%s_sequence_paths" % side]:
				paths.append(String(path))
		paths.append("res://assets/pavement/%s.png" % track.surface_id)
	for vehicle in VehicleCatalog.all():
		paths.append(String(vehicle.texture_path))
	for track_id in MusicCatalog.TRACKS:
		# source_path describes reproducibility, not a runtime dependency.
		paths.append(String(MusicCatalog.TRACKS[track_id].path))
	return paths

static func runtime_manifest() -> PackedStringArray:
	var pending := PackedStringArray(["res://scenes/main.tscn", "res://default_bus_layout.tres"])
	pending.append_array(dynamic_resources())
	var seen: Dictionary = {}
	var cursor := 0
	while cursor < pending.size():
		var path := pending[cursor]
		cursor += 1
		if seen.has(path):
			continue
		seen[path] = true
		if not FileAccess.file_exists(path):
			continue # validate() reports it without provoking a loader error.
		# Godot 4.7 resource direct dependencies; scripts need the scan below.
		# UID dependencies use section 2 as their fallback res:// path:
		# https://docs.godotengine.org/en/stable/classes/class_resourceloader.html#class-resourceloader-method-get-dependencies
		for dependency in ResourceLoader.get_dependencies(path):
			pending.append(dependency.get_slice("::", 2) if dependency.contains("::") else dependency)
		if path.get_extension() == "gd":
			# Runtime get_dependencies() does not enumerate GDScript preloads in
			# this 4.7 build. Scan only literal preload/load/extends operands;
			# catalogs with computed load paths are enumerated above.
			pending.append_array(literal_script_dependencies(FileAccess.get_file_as_string(path)))
	var manifest := PackedStringArray()
	for path in seen:
		manifest.append(String(path))
	manifest.sort()
	return manifest

static func literal_script_dependencies(source: String) -> PackedStringArray:
	var expression := RegEx.new()
	expression.compile("(?:\\b(?:preload|load)\\s*\\(\\s*|\\bextends\\s+)[\"'](res://[^\"']+)[\"']")
	var paths := PackedStringArray()
	for line in source.split("\n"):
		# Current runtime scripts have no multiline load operands or '#' paths.
		for result in expression.search_all(line.get_slice("#", 0)):
			paths.append(result.get_string(1))
	return paths

static func validate(config: ConfigFile, manifest: PackedStringArray) -> PackedStringArray:
	var errors := PackedStringArray()
	# Schema verified against the installed engine's upstream commit:
	# https://github.com/godotengine/godot/blob/5b4e0cb0f/editor/export/editor_export.cpp
	if config.get_value("preset.0", "export_filter", "") != "resources":
		errors.append("export_filter must be resources (selected resources)")
	if config.get_value("preset.0", "include_filter", "") != "":
		errors.append("include_filter must remain empty")
	if config.get_value("preset.0.options", "binary_format/embed_pck", true):
		errors.append("embed_pck must be false for EXE + PCK")
	var exclusions := String(config.get_value("preset.0", "exclude_filter", "")).split(",")
	for directory in EXCLUDED_DIRS:
		if not (directory + "/*") in exclusions:
			errors.append("Missing exclusion: " + directory)
	var selected = config.get_value("preset.0", "export_files", PackedStringArray())
	if not selected is PackedStringArray:
		errors.append("export_files must be a PackedStringArray")
		return errors
	var selected_set: Dictionary = {}
	for path in selected:
		if selected_set.has(path):
			errors.append("Duplicate selection: " + path)
		selected_set[path] = true
		if forbidden(path):
			errors.append("Forbidden selection: " + path)
		elif not manifest.has(path):
			errors.append("Not in runtime dependency closure: " + path)
	for path in manifest:
		if forbidden(path):
			errors.append("Forbidden runtime dependency: " + path)
		if not selected_set.has(path):
			errors.append("Missing selection: " + path)
		if not FileAccess.file_exists(path) or not ResourceLoader.exists(path):
			errors.append("Missing/unrecognized runtime resource: " + path)
		for exclusion in exclusions:
			if path.trim_prefix("res://").match(exclusion.strip_edges()):
				errors.append("Required resource excluded: " + path)
	return errors

static func forbidden(path: String) -> bool:
	if not path.begins_with("res://") or path.simplify_path() != path or path.contains("/."):
		return true
	for directory in EXCLUDED_DIRS:
		if path.begins_with("res://" + directory + "/"):
			return true
	return path.get_extension() not in ["gd", "tscn", "tres", "png", "ogg"]
