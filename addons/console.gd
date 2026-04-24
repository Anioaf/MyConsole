extends CanvasLayer

const MIN_SIZE       := Vector2(320.0, 180.0)
const DEFAULT_SIZE   := Vector2(1020.0, 820.0)
const DEFAULT_POS    := Vector2(0.0, 0.0)
const TITLE_HEIGHT   := 28.0
const INPUT_HEIGHT   := 30.0
const EDGE_THRESHOLD := 6.0
const MAX_HISTORY    := 200
const FONT_DIR       := "res://addons/Console/font/"

const C_BG       := Color("232323")
const C_TITLEBAR := Color("343434")
const C_INPUT_BG := Color("121212ff")
const C_BORDER   := Color("474747ff")
const C_TEXT     := Color("e0e0e0ff")
const C_CMD      := Color("8cd98cff")
const C_ERROR    := Color("f26161ff")
const C_WARNING  := Color("f2cc4dff")
const C_INFO     := Color("73bff2ff")
const C_HINT     := Color("999999ff")

var _panel      : Panel
var _title_bar  : Panel
var _output     : RichTextLabel
var _cmd_field  : LineEdit
var _hint_label : Label
var _font       : FontFile

var _is_open        := false
var _dragging       := false
var _drag_offset    := Vector2.ZERO
var _resizing       := false
var _resize_edge    := Vector2.ZERO
var _resize_start_m := Vector2.ZERO
var _resize_start_r : Rect2 = Rect2()

var _commands       : Dictionary = {}
var _history        : Array[String] = []
var _history_idx    := -1
var _suggestions    : Array[String] = []
var _suggestion_idx := -1

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = _load_font()
	_build_ui()
	_register_default_commands()
	_panel.visible = false

func _load_font() -> FontFile:
	var dir := DirAccess.open(FONT_DIR)
	if dir == null:
		return null
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		var ext := file.get_extension().to_lower()
		if ext == "ttf" or ext == "otf" or ext == "woff" or ext == "woff2":
			var loaded = load(FONT_DIR + file)
			if loaded is FontFile:
				return loaded
		file = dir.get_next()
	return null

func _apply_font(control: Control) -> void:
	if _font == null:
		return
	if control is Label or control is Button or control is LineEdit:
		control.add_theme_font_override("font", _font)
	elif control is RichTextLabel:
		control.add_theme_font_override("normal_font", _font)
		control.add_theme_font_override("bold_font", _font)
		control.add_theme_font_override("italics_font", _font)
		control.add_theme_font_override("mono_font", _font)

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.name = "ConsolePanel"
	_panel.position = DEFAULT_POS
	_panel.size = DEFAULT_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _make_style(C_BG, C_BORDER, 1))
	_panel.gui_input.connect(_on_panel_gui_input)
	_panel.resized.connect(_on_panel_resized)
	add_child(_panel)

	_title_bar = Panel.new()
	_title_bar.name = "TitleBar"
	_title_bar.position = Vector2(0, 0)
	_title_bar.size = Vector2(_panel.size.x, TITLE_HEIGHT)
	_title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_bar.add_theme_stylebox_override("panel", _make_style(C_TITLEBAR))
	_title_bar.gui_input.connect(_on_titlebar_gui_input)
	_panel.add_child(_title_bar)

	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = "CONSOLE"
	title_lbl.position = Vector2(10, 4)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	_apply_font(title_lbl)
	_title_bar.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "x"
	close_btn.flat = true
	close_btn.size = Vector2(TITLE_HEIGHT, TITLE_HEIGHT)
	close_btn.position = Vector2(_panel.size.x - TITLE_HEIGHT, 0)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	close_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.4))
	close_btn.pressed.connect(close)
	_apply_font(close_btn)
	_title_bar.add_child(close_btn)

	_output = RichTextLabel.new()
	_output.name = "Output"
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.selection_enabled = true
	_output.focus_mode = Control.FOCUS_CLICK
	_output.position = Vector2(0, TITLE_HEIGHT)
	_output.size = Vector2(_panel.size.x, _panel.size.y - TITLE_HEIGHT - INPUT_HEIGHT - 1)
	_output.add_theme_color_override("default_color", C_TEXT)
	_output.add_theme_stylebox_override("normal", _make_style(Color(0, 0, 0, 0), Color.TRANSPARENT, 0, 6))
	_output.add_theme_stylebox_override("focus",  _make_style(Color(0, 0, 0, 0), Color.TRANSPARENT, 0, 6))
	_apply_font(_output)
	_panel.add_child(_output)

	var sep := Panel.new()
	sep.name = "Separator"
	sep.position = Vector2(0, _panel.size.y - INPUT_HEIGHT - 1)
	sep.size = Vector2(_panel.size.x, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.add_theme_stylebox_override("panel", _make_style(C_BORDER, Color.TRANSPARENT, 0, 0))
	_panel.add_child(sep)

	_cmd_field = LineEdit.new()
	_cmd_field.name = "CmdField"
	_cmd_field.placeholder_text = "Type a command..."
	_cmd_field.position = Vector2(0, _panel.size.y - INPUT_HEIGHT)
	_cmd_field.size = Vector2(_panel.size.x, INPUT_HEIGHT)
	_cmd_field.add_theme_color_override("font_color", C_TEXT)
	_cmd_field.add_theme_color_override("font_placeholder_color", C_HINT)
	_cmd_field.add_theme_color_override("caret_color", C_CMD)
	_cmd_field.add_theme_stylebox_override("normal", _make_style(C_INPUT_BG, Color.TRANSPARENT, 0, 8))
	_cmd_field.add_theme_stylebox_override("focus",  _make_style(C_INPUT_BG, Color.TRANSPARENT, 0, 8))
	_cmd_field.text_changed.connect(_on_input_changed)
	_cmd_field.text_submitted.connect(_on_input_submitted)
	_cmd_field.gui_input.connect(_on_input_gui_input)
	_apply_font(_cmd_field)
	_panel.add_child(_cmd_field)

	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.position = Vector2(4, _panel.size.y - INPUT_HEIGHT - 18)
	_hint_label.size = Vector2(_panel.size.x - 8, 18)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.add_theme_color_override("font_color", C_HINT)
	_hint_label.visible = false
	_apply_font(_hint_label)
	_panel.add_child(_hint_label)

func _on_panel_resized() -> void:
	var w := _panel.size.x
	var h := _panel.size.y

	if _title_bar:
		_title_bar.size = Vector2(w, TITLE_HEIGHT)
		var cb := _title_bar.get_node_or_null("CloseBtn")
		if cb:
			cb.position.x = w - TITLE_HEIGHT

	if _output:
		_output.size = Vector2(w, h - TITLE_HEIGHT - INPUT_HEIGHT - 1)

	var sep := _panel.get_node_or_null("Separator")
	if sep:
		sep.position.y = h - INPUT_HEIGHT - 1
		sep.size.x = w

	if _cmd_field:
		_cmd_field.position.y = h - INPUT_HEIGHT
		_cmd_field.size = Vector2(w, INPUT_HEIGHT)

	if _hint_label:
		_hint_label.position = Vector2(4, h - INPUT_HEIGHT - 18)
		_hint_label.size.x = w - 8

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_QUOTELEFT:
		get_viewport().set_input_as_handled()
		toggle()
		return
	if not _is_open:
		return
	match event.keycode:
		KEY_UP:
			get_viewport().set_input_as_handled()
			_navigate_history(-1)
		KEY_DOWN:
			get_viewport().set_input_as_handled()
			_navigate_history(1)
		KEY_TAB:
			get_viewport().set_input_as_handled()
			_autocomplete()
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()

func _on_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()

func _on_input_changed(text: String) -> void:
	_suggestion_idx = -1
	_suggestions.clear()
	_hint_label.visible = false
	if text.strip_edges().is_empty():
		return
	var parts := text.split(" ", false)
	if parts.size() == 1:
		var prefix := parts[0].to_lower()
		for cmd_name in _commands.keys():
			if cmd_name.begins_with(prefix):
				_suggestions.append(cmd_name)
		_suggestions.sort()
		if _suggestions.size() > 0:
			_hint_label.text = "  " + "  |  ".join(_suggestions)
			_hint_label.visible = true

func _on_input_submitted(text: String) -> void:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	if _history.is_empty() or _history[0] != trimmed:
		_history.push_front(trimmed)
		if _history.size() > MAX_HISTORY:
			_history.pop_back()
	_history_idx = -1
	_cmd_field.clear()
	_hint_label.visible = false
	_print_raw("[color=#%s]> %s[/color]" % [C_CMD.to_html(false), _escape_bbcode(trimmed)])
	_execute(trimmed)

func _navigate_history(dir: int) -> void:
	if _history.is_empty():
		return
	_history_idx = clampi(_history_idx + dir, -1, _history.size() - 1)
	_cmd_field.text = "" if _history_idx == -1 else _history[_history_idx]
	_cmd_field.caret_column = _cmd_field.text.length()

func _autocomplete() -> void:
	if _suggestions.is_empty():
		return
	_suggestion_idx = (_suggestion_idx + 1) % _suggestions.size()
	_cmd_field.text = _suggestions[_suggestion_idx]
	_cmd_field.caret_column = _cmd_field.text.length()

func _execute(full_text: String) -> void:
	var parts := Array(full_text.split(" ", false))
	if parts.is_empty():
		return
	var cmd_name : String = (parts[0] as String).to_lower()
	var args     : Array  = parts.slice(1)
	if not _commands.has(cmd_name):
		print_error("Unknown command: '%s'. Type help for a list." % cmd_name)
		return
	var cmd : Dictionary = _commands[cmd_name]
	cmd["callable"].call(args)

func _on_titlebar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_drag_offset = get_viewport().get_mouse_position() - _panel.position
	elif event is InputEventMouseMotion and _dragging:
		var vp_size := get_viewport().get_visible_rect().size
		var new_pos := get_viewport().get_mouse_position() - _drag_offset
		new_pos.x = clampf(new_pos.x, 0.0, vp_size.x - _panel.size.x)
		new_pos.y = clampf(new_pos.y, 0.0, vp_size.y - _panel.size.y)
		_panel.position = new_pos

func _on_panel_gui_input(event: InputEvent) -> void:
	var local_mouse := _panel.get_local_mouse_position()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var edge := _get_edge(local_mouse, _panel.size)
			if edge != Vector2.ZERO:
				_resizing = true
				_resize_edge = edge
				_resize_start_m = get_viewport().get_mouse_position()
				_resize_start_r = Rect2(_panel.position, _panel.size)
		else:
			if _resizing:
				_resizing = false
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	elif event is InputEventMouseMotion:
		if _resizing:
			_do_resize()
		else:
			_set_cursor(_get_edge(local_mouse, _panel.size))

func _get_edge(mp: Vector2, sz: Vector2) -> Vector2:
	var e := Vector2.ZERO
	if mp.x < EDGE_THRESHOLD:          e.x = -1
	elif mp.x > sz.x - EDGE_THRESHOLD: e.x = 1
	if mp.y > sz.y - EDGE_THRESHOLD:   e.y = 1
	return e

func _do_resize() -> void:
	var delta := get_viewport().get_mouse_position() - _resize_start_m
	var r     := _resize_start_r
	if _resize_edge.x < 0:
		r.position.x = _resize_start_r.position.x + delta.x
		r.size.x     = _resize_start_r.size.x     - delta.x
	elif _resize_edge.x > 0:
		r.size.x = _resize_start_r.size.x + delta.x
	if _resize_edge.y > 0:
		r.size.y = _resize_start_r.size.y + delta.y
	r.size = r.size.max(MIN_SIZE)
	_panel.position = r.position
	_panel.size     = r.size

func _set_cursor(edge: Vector2) -> void:
	if edge == Vector2.ZERO:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	elif edge.x != 0 and edge.y != 0:
		Input.set_default_cursor_shape(Input.CURSOR_FDIAGSIZE)
	elif edge.x != 0:
		Input.set_default_cursor_shape(Input.CURSOR_HSIZE)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_VSIZE)

func toggle() -> void:
	if _is_open:
		close()
	else:
		open()

func open() -> void:
	_is_open = true
	_panel.visible = true
	_cmd_field.grab_focus()

func close() -> void:
	_is_open = false
	_panel.visible = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func register_command(name: String, callable: Callable,
					  description: String = "", usage: String = "") -> void:
	_commands[name.to_lower()] = {
		"callable":    callable,
		"description": description,
		"usage":       usage if not usage.is_empty() else name,
	}

func unregister_command(name: String) -> void:
	_commands.erase(name.to_lower())

func print_line(text: String, color: Color = C_TEXT) -> void:
	_print_raw("[color=#%s]%s[/color]" % [color.to_html(false), _escape_bbcode(text)])

func print_error(text: String) -> void:
	_print_raw("[color=#%s][ERROR] %s[/color]" % [C_ERROR.to_html(false), _escape_bbcode(text)])

func print_warning(text: String) -> void:
	_print_raw("[color=#%s][WARN]  %s[/color]" % [C_WARNING.to_html(false), _escape_bbcode(text)])

func print_info(text: String) -> void:
	_print_raw("[color=#%s][INFO]  %s[/color]" % [C_INFO.to_html(false), _escape_bbcode(text)])

func print_bbcode(bbcode: String) -> void:
	_print_raw(bbcode)

func clear_output() -> void:
	_output.clear()

func is_open() -> bool:
	return _is_open

func _print_raw(bbcode: String) -> void:
	_output.append_text(bbcode + "\n")

func _escape_bbcode(text: String) -> String:
	return text.replace("[", "\\[").replace("]", "\\]")

func _make_style(bg: Color, border: Color = Color.TRANSPARENT,
				 bw: int = 0, content_margin: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(content_margin)
	return s

func _register_default_commands() -> void:
	register_command("help",      _cmd_help,      "List all available commands")
	register_command("clear",     _cmd_clear,     "Clear the console output")
	register_command("echo",      _cmd_echo,      "Print text to console",     "echo <text...>")
	register_command("quit",      _cmd_quit,      "Quit the game")
	register_command("exit",      _cmd_quit,      "Quit the game (alias)")
	register_command("fps",       _cmd_fps,       "Show current FPS")
	register_command("timescale", _cmd_timescale, "Get/set time scale",        "timescale [value]")
	register_command("version",   _cmd_version,   "Show Godot engine version")
	register_command("scene",     _cmd_scene,     "Change scene",              "scene <res://path>")
	register_command("pause",     _cmd_pause,     "Pause or unpause the game")

func _cmd_help(_args: Array) -> void:
	_print_raw("[color=#%s]=== Available Commands ===[/color]" % C_WARNING.to_html(false))
	var names := _commands.keys()
	names.sort()
	for n in names:
		var cmd : Dictionary = _commands[n]
		_print_raw("  [color=#%s]%-16s[/color][color=#%s]%s[/color]" % [
			C_CMD.to_html(false), n,
			C_HINT.to_html(false), cmd.get("description", "")
		])

func _cmd_clear(_args: Array) -> void:
	clear_output()

func _cmd_echo(args: Array) -> void:
	print_line(" ".join(args))

func _cmd_quit(_args: Array) -> void:
	get_tree().quit()

func _cmd_fps(_args: Array) -> void:
	print_info("FPS: %.1f  |  Max FPS: %d" % [Engine.get_frames_per_second(), Engine.max_fps])

func _cmd_timescale(args: Array) -> void:
	if args.is_empty():
		print_info("Current time_scale: %.4f" % Engine.time_scale)
		return
	var val := float(args[0])
	if val < 0.0:
		print_error("time_scale must be >= 0")
		return
	Engine.time_scale = val
	print_info("time_scale set to %.4f" % Engine.time_scale)

func _cmd_version(_args: Array) -> void:
	print_info("Godot Engine %s" % Engine.get_version_info().string)

func _cmd_scene(args: Array) -> void:
	if args.is_empty():
		print_info("Current scene: %s" % get_tree().current_scene.scene_file_path)
		return
	var path : String = args[0]
	if not ResourceLoader.exists(path):
		print_error("Scene not found: %s" % path)
		return
	get_tree().change_scene_to_file(path)
	print_info("Loading scene: %s" % path)

func _cmd_pause(_args: Array) -> void:
	get_tree().paused = not get_tree().paused
	print_info("Game %s" % ("PAUSED" if get_tree().paused else "RESUMED"))
