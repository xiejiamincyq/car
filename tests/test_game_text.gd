extends SceneTree

const GameText = preload("res://scripts/game_text.gd")

func _init() -> void:
	assert(GameText.catalog_keys_match(), "Chinese and English catalogs must expose the same keys")
	assert(GameText.resolve_language(GameText.LANGUAGE_SYSTEM, "zh_CN") == GameText.LANGUAGE_ZH, "Chinese system locales must resolve to Chinese")
	assert(GameText.resolve_language(GameText.LANGUAGE_SYSTEM, "en_US") == GameText.LANGUAGE_EN, "Non-Chinese system locales must resolve to English")
	assert(GameText.resolve_language(GameText.LANGUAGE_ZH, "en_US") == GameText.LANGUAGE_ZH, "An explicit Chinese preference must override the system locale")
	assert(GameText.resolve_language(GameText.LANGUAGE_EN, "zh_CN") == GameText.LANGUAGE_EN, "An explicit English preference must override the system locale")
	assert(GameText.get_text("title.start", GameText.LANGUAGE_ZH) == "开始比赛", "Chinese UI text must be available by key")
	assert(GameText.get_text("title.start", GameText.LANGUAGE_EN) == "START RACE", "English UI text must be available by key")
	assert(GameText.get_text("missing.key", GameText.LANGUAGE_EN) == "[missing.key]", "Missing UI keys must remain visible for diagnosis")
	quit()
