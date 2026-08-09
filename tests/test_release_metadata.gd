extends SceneTree

const RELEASE_VERSION := "0.2.0"

func _init() -> void:
	var project := ConfigFile.new()
	assert(project.load("res://project.godot") == OK, "Release validation must read project metadata")
	assert(project.get_value("application", "config/version", "") == RELEASE_VERSION, "Project version must match the local 0.2.0 release")

	var export_presets := ConfigFile.new()
	assert(export_presets.load("res://export_presets.cfg") == OK, "Release validation must read Windows export metadata")
	assert(export_presets.get_value("preset.0.options", "application/product_version", "") == RELEASE_VERSION, "Windows product version must match the project version")
	assert(export_presets.get_value("preset.0.options", "application/file_version", "") == "0.2.0.0", "Windows file version must remain numeric and identify the final local release")
	var excluded_resources := str(export_presets.get_value("preset.0", "exclude_filter", ""))
	assert("tests/*" in excluded_resources, "Release exports must not ship the automated test scripts")

	var readme := FileAccess.get_file_as_string("res://README.md")
	assert(RELEASE_VERSION in readme, "README must name the exact candidate version")
	assert(not "0.2.0-rc.1" in readme, "README must not describe the signed local release as RC1")
	var checklist := FileAccess.get_file_as_string("res://docs/release-checklist.md")
	assert(RELEASE_VERSION in checklist, "Release checklist must name the exact candidate version")
	assert(checklist.begins_with("# 0.2.0 本机发布"), "Release checklist must identify 0.2.0 as the active local release")
	quit()
