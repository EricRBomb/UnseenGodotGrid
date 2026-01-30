@tool
extends GridContainer

const GRID_SIZE := 16
var cell_size: int = 16

var cells: Array = []
var node_map: Dictionary = {}  # Maps cell coordinates to array of node references
var current_focused_cell: Vector2i = Vector2i(-1, -1)  # Track currently focused cell
var clipboard_nodes: Array[Node] = []
var clipboard_is_cut := false

signal cell_focused(node: Node)
signal paste_at_position(position: Vector2)
signal cell_size_changed()

var paste_key = KEY_V
var cut_key = KEY_X
var copy_key = KEY_C

func _ready() -> void:
	columns = GRID_SIZE
	_build_grid()

func _build_grid() -> void:
	for child in get_children():
		child.queue_free()

	cells.clear()
	var focus_map =[]
	for y in range(GRID_SIZE):
		var row: Array = []
		for x in range(GRID_SIZE):
			var line_edit := Label.new()
			line_edit.focus_mode = Control.FOCUS_ALL
			line_edit.custom_minimum_size = Vector2(48, 24)
			line_edit.focus_entered.connect(_on_cell_focused.bind(x, y))
			line_edit.gui_input.connect(_on_cell_input.bind(x, y))
			add_child(line_edit)
			row.append(line_edit)
			line_edit.accessibility_description = type_convert(x, TYPE_STRING) + ' ' + type_convert(y, TYPE_STRING)
			#hard coding neighbors for left/right
			if x!=0:
				focus_map[-1].focus_neighbor_right =line_edit.get_path()
				line_edit.focus_neighbor_left = focus_map[-1].get_path()
			#hard coding up/down neighbors
			if y!=0:
				focus_map[-GRID_SIZE].focus_neighbor_bottom=line_edit.get_path()
				line_edit.focus_neighbor_top = focus_map[-GRID_SIZE].get_path()
			focus_map.append(line_edit)
		cells.append(row)

func refresh_from_scene(scene_root: Node) -> void:
	if scene_root == null:
		return

	# Clear grid and node map
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			cells[y][x].text = ""
	
	node_map.clear()

	var nodes: Array[Node] = []
	_collect_nodes(scene_root, nodes,scene_root)

	for node in nodes:
		if not node is CanvasItem:
			continue

		var pos: Vector2

		if node is Node2D:
			pos = node.global_position
		elif node is Control:
			pos = node.global_position
		else:
			continue

		var gx := int(floor(pos.x / cell_size))
		var gy := int(floor(pos.y / cell_size))

		if gx < 0 or gy < 0 or gx >= GRID_SIZE or gy >= GRID_SIZE:
			continue

		var key := Vector2i(gx, gy)
		var cell: Label = cells[gy][gx]
		
		# Initialize array if this is the first node at this position
		if not node_map.has(key):
			node_map[key] = []
		
		# Add node to the array
		node_map[key].append(node)
		
		# Update cell text
		if cell.text.is_empty():
			cell.text = node.name
		else:
			cell.text += ", " + node.name

func _on_cell_focused(x: int, y: int) -> void:
	current_focused_cell = Vector2i(x, y)
	# Don't auto-select anything, just track which cell is focused
func select_cell(event: InputEvent, x: int, y: int) -> void:
	var key := Vector2i(x, y)
	if not node_map.has(key):
		return
	var nodes_at_cell: Array = node_map[key] as Array
	
	if nodes_at_cell.size() == 1:
		# Single node - select it
		cell_focused.emit(nodes_at_cell[0])
	elif nodes_at_cell.size() > 1:
		# Multiple nodes - show popup menu
		_show_node_selection_popup(nodes_at_cell, x, y)
	
	# Accept the event so it doesn't type a space
	cells[y][x].accept_event()
	
func _on_cell_input(event: InputEvent, x: int, y: int) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_SPACE:
			select_cell(event, x, y)
			
		elif event.pressed and event.keycode == paste_key and event.ctrl_pressed:
			# Ctrl+V - paste at current cell position
			var world_pos := Vector2(x * cell_size, y * cell_size)
			paste_at_position.emit(world_pos)
			# Accept the event
			cells[y][x].accept_event()
		elif event.pressed and event.ctrl_pressed and event.keycode == copy_key:
			var key := Vector2i(x, y)
			if node_map.has(key):
				clipboard_nodes.clear()
				for node in node_map[key]:
					clipboard_nodes.append(node)
				clipboard_is_cut = false
			cells[y][x].accept_event()

		elif event.pressed and event.ctrl_pressed and event.keycode == cut_key:
			var key := Vector2i(x, y)
			if node_map.has(key):
				clipboard_nodes.clear()
				for node in node_map[key]:
					clipboard_nodes.append(node)
				clipboard_is_cut = true
			cells[y][x].accept_event()
			
func _on_cell_size_changed(new_value: float) -> void:
	cell_size = int(new_value)
	cell_size_changed.emit()

func _show_node_selection_popup(nodes: Array, x: int, y: int) -> void:
	var popup := PopupMenu.new()
	popup.transparent_bg = true
	
	# Add each node as a menu item
	for i in range(nodes.size()):
		var node: Node = nodes[i]
		popup.add_item(node.name, i)
	
	# Connect to selection
	popup.index_pressed.connect(func(index: int):
		if index < nodes.size():
			cell_focused.emit(nodes[index])
		popup.queue_free()
	)
	
	# Position popup near the cell
	add_child(popup)
	var cell_rect: Rect2 = cells[y][x].get_global_rect()
	popup.position = cell_rect.position + Vector2(0, cell_rect.size.y)
	popup.popup()
	
	# Clean up when popup closes
	popup.popup_hide.connect(func():
		if is_instance_valid(popup):
			popup.queue_free()
	)

func _collect_nodes(node: Node, out: Array[Node], scene_root: Node) -> void:
	if node != scene_root:
		out.append(node)

	for child in node.get_children():
		#We do not want to print out children of instanced nodes, this filters them out.
		if child.get_scene_file_path() != '':
			_collect_nodes(child, out, scene_root)

func set_cell_size(new_size: int) -> void:
	cell_size = new_size

func get_cell_size() -> int:
	return cell_size
	
func focus_cell_for_node(node: Node) -> void:
	if not node is CanvasItem:
		return

	var pos: Vector2
	if node is Node2D or node is Control:
		pos = node.global_position
	else:
		return

	var gx := int(floor(pos.x / cell_size))
	var gy := int(floor(pos.y / cell_size))

	if gx < 0 or gy < 0 or gx >= GRID_SIZE or gy >= GRID_SIZE:
		return

	var cell: Control = cells[gy][gx]
	cell.grab_focus()

	current_focused_cell = Vector2i(gx, gy)
