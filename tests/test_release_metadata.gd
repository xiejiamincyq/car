extends SceneTree

const RELEASE_VERSION := "0.4.0-dev"

func _init() -> void:
	var project := ConfigFile.new()
	assert(project.load("res://project.godot") == OK, "Release validation must read project metadata")
	assert(project.get_value("application", "config/version", "") == RELEASE_VERSION, "The active branch must identify the 0.4.0 tour-development version")

	var export_presets := ConfigFile.new()
	assert(export_presets.load("res://export_presets.cfg") == OK, "Release validation must read Windows export metadata")
	assert(export_presets.get_value("preset.0.options", "application/product_version", "") == RELEASE_VERSION, "Windows product version must match the project version")
	assert(export_presets.get_value("preset.0.options", "application/file_version", "") == "0.4.0.0", "Windows file version must remain numeric during 0.4.0 development")
	assert(export_presets.get_value("preset.0.options", "application/file_description", "") == "Neon Coast Rush tour development build", "Windows metadata must identify the development build")
	assert(export_presets.get_value("preset.0", "export_path", "") == "exports/0.4.0-dev/package/NeonCoastRush.exe", "The default development export path must be versioned")
	var excluded_resources := str(export_presets.get_value("preset.0", "exclude_filter", ""))
	assert("tests/*" in excluded_resources, "Release exports must not ship the automated test scripts")
	assert("art/source/*" in excluded_resources, "Release exports must not ship high-resolution generated art sources")

	var readme := FileAccess.get_file_as_string("res://README.md")
	assert(RELEASE_VERSION in readme, "README must name the exact candidate version")
	assert("v0.2.0" in readme, "README must retain the stable rollback tag")
	var main_scene := FileAccess.get_file_as_string("res://scenes/main.tscn")
	assert('text = "v0.4.0-dev"' in main_scene, "The title screen must show the active development version")
	var checklist := FileAccess.get_file_as_string("res://docs/release-checklist.md")
	assert("v0.2.0" in checklist, "Release checklist must retain the stable rollback tag")
	assert(checklist.begins_with("# 0.3.0 本机发布"), "The frozen release checklist must remain an accurate 0.3.0 record during development")
	quit()
