extends Control
## Event-driven profile UI. It never reads files or changes race state itself.
signal load_requested(index: int)
signal save_requested(index: int)
signal delete_requested(index: int)
signal copy_requested(source: int,target: int)
signal back_requested
const Text = preload("res://scripts/game_text.gd")
const Presentation = preload("res://scripts/ui/menu_presentation.gd")
var cards: Array[Dictionary] = []
var entries: Array = []
var active := 0
var writable := false
var locale := "zh"
var modal: Control
var heading: Label
var notice: Label
var prompt: Label
var back_button: Button
var target_picker: OptionButton
var confirm_button: Button
var cancel_button: Button
var pending_action := ""
var pending_source := 0
var return_focus: Button

func _ready() -> void:
	name="SaveSlotsScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=Presentation._theme()
	var shade := ColorRect.new()
	shade.color=Color(0.015,0.04,0.075,0.94)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := _centered_card(self,1000)
	heading=_label(content,30)
	var grid := GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",16)
	content.add_child(grid)
	for index in range(1,5):
		var panel := PanelContainer.new()
		panel.custom_minimum_size=Vector2(470,180)
		panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		grid.add_child(panel)
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation",10)
		panel.add_child(rows)
		var title := _label(rows,22)
		title.add_theme_color_override("font_color",Presentation.CYAN)
		var summary := _label(rows,17)
		summary.custom_minimum_size.y=50
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation",8)
		rows.add_child(actions)
		var card := {"title":title,"summary":summary,"panel":panel}
		for action in ["load","save","copy","delete"]:
			var button := _button(actions)
			button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size",16)
			card[action]=button
		card.load.pressed.connect(func():load_requested.emit(index))
		card.save.pressed.connect(func():save_requested.emit(index))
		card.copy.pressed.connect(func():_open_copy(index))
		card.delete.pressed.connect(func():_open_delete(index))
		cards.append(card)
	notice=_label(content,16)
	notice.custom_minimum_size.y=24
	back_button=_button(content)
	back_button.pressed.connect(func():back_requested.emit())
	modal=Control.new()
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color=Color(0,0,0,0.7)
	modal.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dialog := _centered_card(modal,640)
	prompt=_label(dialog,22)
	prompt.custom_minimum_size=Vector2(590,100)
	prompt.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	target_picker=OptionButton.new()
	target_picker.custom_minimum_size.y=44
	dialog.add_child(target_picker)
	target_picker.item_selected.connect(func(_index):_refresh_copy_prompt())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation",12)
	dialog.add_child(buttons)
	cancel_button=_button(buttons)
	confirm_button=_button(buttons)
	for button in [cancel_button,confirm_button]:button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	confirm_button.theme_type_variation=&"DangerButton"
	cancel_button.pressed.connect(cancel_modal)
	confirm_button.pressed.connect(_confirm)
	modal.hide()
	hide()

func _centered_card(parent: Control,width: int) -> VBoxContainer:
	var center := CenterContainer.new()
	parent.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x=width
	center.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",14)
	panel.add_child(rows)
	return rows

func _label(parent: Node,font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size",font_size)
	parent.add_child(label)
	return label

func _button(parent: Node) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y=44
	parent.add_child(button)
	return button

func _text(key: String,values: Array=[]) -> String:return Text.get_text(key,locale,values)

func present(records: Array,current: int,language: String,can_write: bool,message := "") -> void:
	entries=records
	active=current
	locale=language
	writable=can_write
	heading.text=_text("slots.heading")
	back_button.text=_text("settings.back")
	cancel_button.text=_text("slots.cancel")
	confirm_button.text=_text("confirm.yes")
	notice.text=message if not message.is_empty() else _text("slots.no_active" if active==0 else "slots.current",[active])
	if not writable:notice.text=_text("slots.blocked")
	for position in cards.size():
		var card := cards[position]
		var entry: Dictionary=entries[position]
		var status: String=String(entry.status)
		var healthy := status in ["primary","backup"]
		var current_card := active==position+1
		var state_text := _text("slots."+status)
		if current_card:state_text=_text("slots.active")+" · "+state_text
		card.title.text=_text("slots.card",[position+1,state_text])
		if healthy:
			var best := 0
			for score in entry.data.top_scores:best=maxi(best,int(score.score))
			card.summary.text=_text("slots.summary",[entry.data.career.runs,best])
		else:card.summary.text=""
		for action in ["load","save","copy","delete"]:
			card[action].text=_text("slots."+action)
		card.load.disabled=not writable or not (healthy or status=="missing")
		card.save.disabled=not writable or not current_card or not (healthy or status=="missing")
		card.copy.disabled=not writable or not healthy
		card.delete.disabled=not writable or status in ["missing","io_error"]
	_update_focus_route()
	if is_visible_in_tree() and not modal.visible:
		var focused := get_viewport().gui_get_focus_owner()
		if focused==null or not focused.is_visible_in_tree() or (focused is BaseButton and focused.disabled):
			_focus_first_available()

func open() -> void:
	show()
	_focus_first_available()

func _focus_first_available() -> void:
	for card in cards:
		if not card.load.disabled:card.load.grab_focus();return
	back_button.grab_focus()

func _update_focus_route() -> void:
	var buttons: Array[Control]=[]
	for card in cards:
		for action in ["load","save","copy","delete"]:
			if not card[action].disabled:buttons.append(card[action])
	buttons.append(back_button)
	for index in buttons.size():
		buttons[index].focus_next=buttons[index].get_path_to(buttons[(index+1)%buttons.size()])
		buttons[index].focus_previous=buttons[index].get_path_to(buttons[(index+buttons.size()-1)%buttons.size()])

func _begin_modal(action: String,index: int,button: Button) -> void:
	pending_action=action
	pending_source=index
	return_focus=button
	# Disable all underlying actions: neither focus traversal nor clicks can escape.
	for card in cards:
		for key in ["load","save","copy","delete"]:card[key].disabled=true
	back_button.disabled=true
	modal.show()
	cancel_button.grab_focus()

func _open_copy(index: int) -> void:
	_begin_modal("copy",index,cards[index-1].copy)
	target_picker.clear()
	for target in range(1,5):
		target_picker.add_item(_text("slots.target",[target]),target)
		target_picker.set_item_disabled(target-1,target==index or entries[target-1].status==&"io_error")
	target_picker.select(1 if index==1 else 0)
	target_picker.show()
	_refresh_copy_prompt()
	_modal_focus([cancel_button,target_picker,confirm_button])

func _refresh_copy_prompt() -> void:
	var target := target_picker.get_selected_id()
	confirm_button.disabled=target==pending_source or target<1 or target>4 or entries[target-1].status==&"io_error"
	prompt.text=_text("slots.confirm_copy",[pending_source,target])
	if target>=1 and target<=4 and entries[target-1].status!=&"missing":prompt.text+="\n"+_text("slots.overwrite")

func _open_delete(index: int) -> void:
	_begin_modal("delete",index,cards[index-1].delete)
	target_picker.hide()
	confirm_button.disabled=false
	prompt.text=_text("slots.confirm_delete",[index])
	_modal_focus([cancel_button,confirm_button])

func _modal_focus(controls: Array) -> void:
	for index in controls.size():
		controls[index].focus_next=controls[index].get_path_to(controls[(index+1)%controls.size()])
		controls[index].focus_previous=controls[index].get_path_to(controls[(index+controls.size()-1)%controls.size()])
		controls[index].focus_neighbor_left=controls[index].focus_previous
		controls[index].focus_neighbor_right=controls[index].focus_next
		controls[index].focus_neighbor_top=controls[index].focus_previous
		controls[index].focus_neighbor_bottom=controls[index].focus_next

func cancel_modal() -> void:
	modal.hide()
	pending_action=""
	back_button.disabled=false
	present(entries,active,locale,writable,notice.text)
	if is_instance_valid(return_focus) and not return_focus.disabled:return_focus.grab_focus()
	else:back_button.grab_focus()

func handle_back() -> void:
	if modal.visible:cancel_modal()
	else:back_requested.emit()

func _confirm() -> void:
	var action := pending_action
	var source := pending_source
	var target := target_picker.get_selected_id()
	cancel_modal()
	if action=="copy":copy_requested.emit(source,target)
	elif action=="delete":delete_requested.emit(source)
