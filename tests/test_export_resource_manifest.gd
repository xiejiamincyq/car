extends SceneTree
## Static pre-export gate only. Never exports a pack or opens player saves.
const Audit = preload("res://scripts/tests/ExportResourceAudit.gd")
var failures := 0

func _init() -> void:
	var config := ConfigFile.new()
	_check(config.load("res://export_presets.cfg") == OK, "read the active preset")
	_check(config.get_value("preset.0", "export_filter", "") == "resources", "use selected resources, not all_resources")
	_check(config.get_value("preset.0", "export_files", PackedStringArray()).size() > 0, "selected resources must be an explicit nonempty list")
	_check(config.get_value("preset.0", "include_filter", "") == "", "no broad non-resource include filters")
	_check(not config.get_value("preset.0.options", "binary_format/embed_pck", true), "EXE and PCK must remain separate")
	var exclusions := String(config.get_value("preset.0", "exclude_filter", ""))
	for pattern in ["tests/*", "tmp/*", "docs/*", "scripts/tests/*", "scripts/tools/*", "scripts/art/*", "art/*", "assets/environment/*", "assets/tracks/*"]:
		_check(pattern in exclusions.split(","), "defense-in-depth exclusion: " + pattern)
	var manifest := Audit.runtime_manifest()
	var errors := Audit.validate(config, manifest)
	for message in errors:
		_check(false, message)
	_check(manifest.has("res://scripts/main.gd") and manifest.has("res://scripts/ui/persistence_notice.gd") and manifest.has("res://scenes/vehicle_select.tscn"), "direct nested scene and script dependencies belong to the closure")
	var counts := {"environment_sequences": 0, "vehicles": 0, "pavement": 0, "music": 0}
	for path in manifest:
		for group in counts:
			if path.begins_with("res://assets/" + group + "/"):
				counts[group] += 1
	_check(counts == {"environment_sequences": 40, "vehicles": 11, "pavement": 4, "music": 4}, "all 40 panels, 6 C players, 5 NPCs, 4 surfaces, and 4 scores must be selected")
	for vehicle_id in ["pulse_gt", "driftwing", "flashpoint", "comet_rs", "tidebreaker", "aurora_x"]:
		_check(manifest.has("res://assets/vehicles/player_%s_c.png" % vehicle_id), "current C player asset is mandatory: " + vehicle_id)
	_check(Audit.forbidden("res://.godot/imported/development.png") and Audit.forbidden("user://save.cfg"), "raw development caches and private saves cannot be selected")
	_check(Audit.dynamic_resources().size() == 54, "dynamic catalogs enumerate 40 backgrounds, 6 players, 4 surfaces, and 4 music files")
	_check(Audit.literal_script_dependencies('const A = preload("res://scripts/game_text.gd")\n# preload("res://tmp/not-runtime.gd")\nextends "res://scripts/main.gd"') == PackedStringArray(["res://scripts/game_text.gd", "res://scripts/main.gd"]), "script closure includes literal preloads/extends but ignores comments")
	var selected := PackedStringArray(config.get_value("preset.0", "export_files", PackedStringArray()))
	for path in ["res://assets/music/freight_harbor.ogg", "res://assets/environment_sequences/storm_ridge/right_04.png", "res://assets/vehicles/player_aurora_x_c.png", "res://assets/pavement/sunrise_express.png", "res://scripts/game_text.gd"]:
		var incomplete := selected.duplicate()
		if incomplete.has(path):
			incomplete.remove_at(incomplete.find(path))
		var mutated := _copy_config(config)
		mutated.set_value("preset.0", "export_files", incomplete)
		_check(Audit.validate(mutated, manifest).has("Missing selection: " + path), "gate rejects omitted dynamic/direct dependency: " + path)
	for path in ["res://tmp/debug.png", "res://scripts/tests/ExportResourceAudit.gd", "res://art/source/music/generate_course_music.py", "res://assets/vehicles/player_car.png"]:
		var mutated := _copy_config(config)
		var extra := selected.duplicate()
		extra.append(path)
		mutated.set_value("preset.0", "export_files", extra)
		_check(not Audit.validate(mutated, manifest).is_empty(), "gate rejects test/source/obsolete additions: " + path)
	var missing_manifest := manifest.duplicate()
	missing_manifest.append("res://assets/music/not_a_real_runtime_track.ogg")
	_check(Audit.validate(config, missing_manifest).has("Missing/unrecognized runtime resource: res://assets/music/not_a_real_runtime_track.ogg"), "nonexistent dependency cannot pass")
	var broad := _copy_config(config)
	broad.set_value("preset.0", "include_filter", "*")
	_check(Audit.validate(broad, manifest).has("include_filter must remain empty"), "broad raw-file inclusion cannot swallow private data")
	var duplicate := _copy_config(config)
	var duplicated := selected.duplicate()
	duplicated.append("res://scenes/main.tscn")
	duplicate.set_value("preset.0", "export_files", duplicated)
	_check(Audit.validate(duplicate, manifest).has("Duplicate selection: res://scenes/main.tscn"), "repeated whitelist entries are rejected")
	var conflicting := _copy_config(config)
	conflicting.set_value("preset.0", "exclude_filter", exclusions + ",assets/music/*")
	_check(Audit.validate(conflicting, manifest).has("Required resource excluded: res://assets/music/neon_coast.ogg"), "exclusion rules cannot silently remove a whitelisted dependency")
	print("EXPORT_MANIFEST_LOGICAL_RESOURCES %d exported_pack_checked=false" % manifest.size())
	print("EXPORT_MANIFEST_CHECKS_COMPLETE failures=%d" % failures)
	print("TEST_COMPLETE test_export_resource_manifest.gd")
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("EXPORT_MANIFEST_FAIL " + message)

func _copy_config(source: ConfigFile) -> ConfigFile:
	var result := ConfigFile.new()
	for section in source.get_sections():
		for key in source.get_section_keys(section):
			result.set_value(section, key, source.get_value(section, key))
	return result
