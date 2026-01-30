@tool
extends EditorPlugin

var panel: Control
var grid: GridContainer
var cell_size_control: SpinBox
var jump_to_node_shortcut: Shortcut
var open_grid: = KEY_F2
var jump_focused := KEY_U
var cell_sizer := KEY_5

func _enter_tree() -> void:
	# Create a container for the whole panel
	var vbox := VBoxContainer.new()
	panel = vbox
	
	# Create header with cell size control
	var header := HBoxContainer.new()
	vbox.add_child(header)
	
	var label := Label.new()
	label.text = "CELL SIZE:"
	header.add_child(label)
	
	cell_size_control = SpinBox.new()
	cell_size_control.min_value = 1
	cell_size_control.max_value = 256
	cell_size_control.value = 16
	cell_size_control.step = 1
	cell_size_control.focus_mode =Control.FOCUS_ALL
	cell_size_control.select_all_on_focus = true

	
	cell_size_control.value_changed.connect(_on_cell_size_changed)
	cell_size_control.accessibility_description = "Size of each cell"
	header.add_child(cell_size_control)
	
	# Create the grid from script
	var grid_panel_script = load("res://addons/unseen_grid_editor/grid_panel.gd")
	grid = grid_panel_script.new()
	vbox.add_child(grid)

	# Listen for scene changes
	get_editor_interface().get_selection().connect("selection_changed", _on_selection_changed)
	
	# Connect to the grid's signals
	if grid:
		grid.cell_focused.connect(_on_cell_focused)
		grid.paste_at_position.connect(_on_paste_at_position)
		grid.cell_size_changed.connect(scene_refresh)
		# Create shortcut (example: Ctrl+J)
	jump_to_node_shortcut = Shortcut.new()
	var ev := InputEventKey.new()
	ev.keycode = KEY_J
	ev.ctrl_pressed = true
	jump_to_node_shortcut.events.append(ev)
	
	var main_screen := get_editor_interface().get_editor_main_screen()
	main_screen.add_child(panel)
	panel.visible = false

func _exit_tree() -> void:
	if get_editor_interface().get_selection().is_connected("selection_changed", _on_selection_changed):
		get_editor_interface().get_selection().disconnect("selection_changed", _on_selection_changed)
	
	if grid:
		if grid.cell_focused.is_connected(_on_cell_focused):
			grid.cell_focused.disconnect(_on_cell_focused)
		if grid.paste_at_position.is_connected(_on_paste_at_position):
			grid.paste_at_position.disconnect(_on_paste_at_position)
		if grid.cell_size_changed.is_connected(scene_refresh):
			grid.cell_size_changed.disconnect(scene_refresh)
	
	if is_instance_valid(panel):
		panel.queue_free()

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "Unseen Grid"

func _make_visible(visible: bool) -> void:
	panel.visible = visible
	if visible:
		call_deferred("_on_grid_editor_shown")

# --- SAFE REFRESH ---
func _on_grid_editor_shown() -> void:
	if not is_instance_valid(panel):
		return
	scene_refresh()


func _on_selection_changed():
	# Only refresh when the Grid Editor is visible
	if panel.get_parent():
		scene_refresh()

func scene_refresh():
	if not grid:
		return
	if not grid.is_inside_tree():
		return
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root and is_instance_valid(scene_root):
		grid.refresh_from_scene(scene_root)


# --- NODE SELECTION ---

func _on_cell_focused(node: Node) -> void:
	if node and is_instance_valid(node):
		var selection := get_editor_interface().get_selection()
		selection.clear()
		selection.add_node(node)

func _on_paste_at_position(position: Vector2) -> void:
	if not grid or grid.clipboard_nodes.is_empty():
		print("Clipboard is empty")
		return

	var scene_root: Node = get_editor_interface().get_edited_scene_root()
	if not scene_root:
		return

	var undo_redo: EditorUndoRedoManager = get_undo_redo()

	if grid.clipboard_is_cut:
		# --- MOVE (CUT + PASTE) ---
		undo_redo.create_action("Move Node(s) to Grid Position")

		for node: Node in grid.clipboard_nodes:
			if not is_instance_valid(node):
				continue

			if node is Node2D or node is Control:
				var old_pos: Vector2 = node.global_position
				undo_redo.add_do_property(node, "global_position", position)
				undo_redo.add_undo_property(node, "global_position", old_pos)

		undo_redo.commit_action()

	else:
		# --- COPY + PASTE ---
		undo_redo.create_action("Paste Node(s) at Grid Position")

		for node: Node in grid.clipboard_nodes:
			if not is_instance_valid(node):
				continue

			var duplicate: Node = node.duplicate() as Node

			# Generate unique name
			var base_name: String = node.name
			var counter: int = 2
			var new_name: String = base_name + str(counter)
			while scene_root.has_node(new_name):
				counter += 1
				new_name = base_name + str(counter)

			duplicate.name = new_name

			if duplicate is Node2D or duplicate is Control:
				duplicate.global_position = position

			undo_redo.add_do_method(scene_root, "add_child", duplicate)
			undo_redo.add_do_method(duplicate, "set_owner", scene_root)
			undo_redo.add_do_reference(duplicate)
			undo_redo.add_undo_method(scene_root, "remove_child", duplicate)

		undo_redo.commit_action()

	scene_refresh()

func _on_cell_size_changed(new_value: float) -> void:
	if grid:
		grid.set_cell_size(int(new_value))
		scene_refresh()

func _shortcut_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		#Jumps to the grid square if you have one focused and editor is opened. ctrl J by default
		if event.ctrl_pressed and event.keycode == jump_focused:
			if not panel.get_parent():
				return # Grid Editor not visible
			_jump_to_selected_node()
		#ctrl + F2 by default opens the grid editor
		if event.ctrl_pressed and event.keycode == open_grid:
			_focus_grid_editor_tab()
		#ctrl + 5 by default jumps to cell sizer
		if event.ctrl_pressed and event.keycode == cell_sizer:
			cell_size_control.get_line_edit().grab_focus()
			
func _focus_grid_editor_tab() -> void:
	var editor := get_editor_interface()
	editor.set_main_screen_editor(_get_plugin_name())

func _jump_to_selected_node() -> void:
	if not grid:
		return

	var selection := get_editor_interface().get_selection()
	var selected := selection.get_selected_nodes()

	if selected.is_empty():
		return

	var node := selected[0]
	if not is_instance_valid(node):
		return
	grid.focus_cell_for_node(node)
