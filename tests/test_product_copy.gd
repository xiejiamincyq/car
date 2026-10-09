extends SceneTree
## Small copy contract; Main is instantiated off-tree, so _ready cannot open a save.
const Text = preload("res://scripts/game_text.gd")
const MainScene = preload("res://scenes/main.tscn")
var failures := 0

func _init() -> void:
	for locale in ["zh", "en"]:
		var objective: String = Text.get_text("title.objective", locale)
		_check(not objective.contains("3200") and not objective.contains("检查点") and not objective.to_lower().contains("checkpoint"), "title goal applies to every track: " + locale)
		_check(objective.contains("20%") and (objective.contains("燃油") if locale == "zh" else objective.to_lower().contains("fuel")), "title keeps fuel and integrity failure rules: " + locale)
		_check(objective.length() <= 160, "title goal stays compact: " + locale)
		var hint: String = Text.get_text("garage.hint", locale)
		_check(hint.length() <= 40 and hint.to_lower().contains("esc"), "garage hint is a short navigation cue: " + locale)
		_check(hint.contains("方向键") if locale == "zh" else hint.contains("ARROW"), "garage hint names keyboard selection: " + locale)
		var confirm: String = Text.get_text("garage.confirm", locale)
		_check(confirm.contains("开始比赛") if locale == "zh" else confirm.contains("START RACE"), "confirm button keeps its race-start meaning: " + locale)
		for key in ["settings.audio.session_hint", "settings.audio.failed_hint", "persistence.recovered", "persistence.load_blocked", "persistence.save_failed", "garage.locked_short", "pause.heading", "confirm.restart", "result.reason.integrity"]:
			_check(not Text.get_text(key, locale).is_empty() and not Text.get_text(key, locale).begins_with("["), "necessary feedback remains available: " + key + "/" + locale)
		var controls: String = Text.get_text("controls.body", locale)
		_check(controls.contains("W / ↑") and controls.contains("S / ↓") and controls.to_lower().contains("esc"), "controls retain driving and exit instructions: " + locale)
	var main := MainScene.instantiate()
	_check(main.has_method("_fast_entry_warning_text"), "red pre-entry label reads the configured speed")
	if main.has_method("_fast_entry_warning_text"):
		for locale in ["zh","en"]:
			main.language = locale
			_check(main.call("_fast_entry_warning_text") == ("高速来车 · 450" if locale == "zh" else "INCOMING · 450"), "localized red pre-entry label displays 450: " + locale)
	_check(not main.get_node("CanvasLayer/TitleScreen/Center/Card/Content/Version").visible, "development version label is hidden without removing internal metadata")
	main.free()
	_check(ProjectSettings.get_setting("application/config/name") == "Neon Coast Rush", "copy polish preserves the application and save identity; version is checked by the metadata gate")
	var chart_source := FileAccess.get_file_as_string("res://scripts/ui/vehicle_performance_chart.gd")
	_check(not chart_source.contains("六车归一化") and not chart_source.contains("NORMALIZED ACROSS SIX CARS"), "radar exposes vehicle stats without implementation commentary")
	_check(Text.catalog_keys_match(), "localized key sets stay complete")
	print("PRODUCT_COPY failures=%d" % failures)
	print("TEST_COMPLETE test_product_copy.gd")
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("PRODUCT_COPY " + message)
