extends VBoxContainer
## UI adapter only: AudioDirector and SaveStore remain the audio/settings owners.

signal volume_changed(channel: StringName, value: float)

const GameText = preload("res://scripts/game_text.gd")
const CHANNELS := [&"Master", &"Music", &"Effects"]
var sliders: Array[HSlider] = []

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	for channel in CHANNELS:
		var row := HBoxContainer.new()
		row.name = channel
		row.custom_minimum_size = Vector2(490, 32)
		row.add_theme_constant_override("separation", 14)
		add_child(row)
		var label := Label.new()
		label.name = "Name"
		label.custom_minimum_size.x = 92
		row.add_child(label)
		var slider := HSlider.new()
		slider.name = "Slider"
		slider.custom_minimum_size.x = 260
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 5
		slider.value_changed.connect(func(value: float): volume_changed.emit(channel, value / 100.0))
		row.add_child(slider)
		var value := Label.new()
		value.name = "Value"
		value.custom_minimum_size.x = 58
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		slider.focus_entered.connect(_set_focus_style.bind(slider, value, true))
		slider.focus_exited.connect(_set_focus_style.bind(slider, value, false))
		_set_focus_style(slider, value, false)
		sliders.append(slider)
	var hint := Label.new()
	hint.name = "Hint"
	hint.add_theme_font_size_override("font_size", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	var controls: Array[Control] = []
	controls.append_array(sliders)
	for sibling in get_parent().get_children():
		if sibling is Button:
			controls.append(sibling)
	for index in controls.size():
		var control := controls[index]
		var previous := controls[posmod(index - 1, controls.size())]
		var next := controls[(index + 1) % controls.size()]
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next)

func synchronize(master: float, music: float, effects: float, language: String, persistent: bool = true) -> void:
	var values := [master, music, effects]
	for index in CHANNELS.size():
		var channel: StringName = CHANNELS[index]
		get_node("%s/Name" % channel).text = GameText.get_text("settings.audio.%s" % String(channel).to_lower(), language)
		sliders[index].set_value_no_signal(values[index] * 100.0)
		get_node("%s/Value" % channel).text = "%d%%" % roundi(values[index] * 100.0)
		# Accessible name also conveys the control's channel when its label is not focused.
		sliders[index].tooltip_text = get_node("%s/Name" % channel).text
	get_node("Hint").text = GameText.get_text("settings.audio.hint" if persistent else "settings.audio.session_hint", language)

func focus_first_channel() -> void:
	sliders[0].grab_focus()

func _set_focus_style(slider: HSlider, value: Label, focused: bool) -> void:
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color("233e52")
	rail.border_color = Color("ffd16b") if focused else Color("3a6478")
	rail.set_border_width_all(2 if focused else 1)
	rail.set_corner_radius_all(4)
	rail.content_margin_top = 5
	rail.content_margin_bottom = 5
	slider.add_theme_stylebox_override("slider", rail)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ffd16b") if focused else Color("49e6df")
	fill.set_corner_radius_all(4)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	value.add_theme_color_override("font_color", Color("ffd16b") if focused else Color("e5f1f7"))
