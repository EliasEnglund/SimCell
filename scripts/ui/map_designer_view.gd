extends Control
class_name MapDesignerView

signal map_saved(message: String)

const MAP_PATH := "res://data/exploration_map.json"
const GRID_SIZE := 160.0
const WORLD_BOUNDS := Rect2(Vector2(-2600.0, -2100.0), Vector2(5200.0, 4200.0))

var _canvas: DesignerCanvas
var _status_label: Label

func _ready() -> void:
	_build_layout()

func _input(event: InputEvent) -> void:
	if _canvas == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _canvas.has_feature_drag():
		var mouse := get_global_mouse_position()
		if _canvas.get_global_rect().has_point(mouse):
			_canvas.place_feature_at_global(mouse)
		else:
			_canvas.cancel_feature_drag()

func _build_layout() -> void:
	var layout := HBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	add_child(layout)

	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(300, 0)
	side.add_theme_stylebox_override("panel", _side_panel_style())
	layout.add_child(side)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	side.add_child(stack)
	stack.add_child(_title("MAP DESIGNER", "Drag features into the map. Mouse-drag the map to pan, wheel to zoom."))

	for feature in _feature_defs():
		stack.add_child(_feature_row(feature))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(spacer)

	var save := Button.new()
	save.text = "SAVE MAP"
	save.custom_minimum_size = Vector2(0, 44)
	save.add_theme_stylebox_override("normal", _button_style(false))
	save.add_theme_stylebox_override("hover", _button_style(true))
	save.add_theme_stylebox_override("pressed", _button_style(true))
	save.pressed.connect(_save_map)
	stack.add_child(save)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.modulate = Color("dbeff2")
	stack.add_child(_status_label)

	_canvas = DesignerCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.clip_contents = true
	_canvas.features = _feature_defs()
	_canvas.load_map()
	layout.add_child(_canvas)

func _feature_defs() -> Array[Dictionary]:
	return [
		{"id": "sugar", "label": "Glucose Deposit", "color": Color("b7ef42"), "variant": 0},
		{"id": "sulfur", "label": "Sulfur Crystals", "color": Color("ffe064"), "variant": 0},
		{"id": "nitrogen", "label": "Nitrogen Source", "color": Color("65a9ff"), "variant": 0},
		{"id": "bacteria", "label": "Neutral Cell", "color": Color("74d6c8"), "variant": 0},
		{"id": "hostile", "label": "Hostile Cell", "color": Color("e95058"), "variant": 1},
		{"id": "dead_cell", "label": "Broken Cell", "color": Color("c8d0a2"), "variant": 0},
		{"id": "virus", "label": "Virus / Debris", "color": Color("b46ce6"), "variant": 0}
	]

func _feature_row(feature: Dictionary) -> Control:
	var row := Button.new()
	row.text = str(feature.get("label", "Feature"))
	row.custom_minimum_size = Vector2(0, 42)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.tooltip_text = "Drag into map"
	row.add_theme_stylebox_override("normal", _button_style(false))
	row.add_theme_stylebox_override("hover", _button_style(true))
	row.add_theme_stylebox_override("pressed", _button_style(true))
	row.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_canvas.begin_feature_drag(feature)
	)
	return row

func _save_map() -> void:
	var result := _canvas.save_map()
	_status_label.text = result
	map_saved.emit(result)

func _title(title_text: String, subtitle: String) -> Control:
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 19)
	title.modulate = Color("76f4ff")
	box.add_child(title)
	var sub := Label.new()
	sub.text = subtitle
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.modulate = Color(0.72, 0.84, 0.82)
	box.add_child(sub)
	return box

func _side_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.080, 0.095, 0.94)
	style.border_color = Color(0.30, 0.78, 0.86, 0.72)
	style.set_border_width(SIDE_RIGHT, 2)
	style.content_margin_left = 14
	style.content_margin_top = 14
	style.content_margin_right = 14
	style.content_margin_bottom = 14
	return style

func _button_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.18, 0.22, 0.92) if active else Color(0.03, 0.12, 0.15, 0.82)
	style.border_color = Color(0.46, 0.96, 1.0, 0.70 if active else 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

class DesignerCanvas:
	extends Control

	var features: Array[Dictionary] = []
	var objects: Array[Dictionary] = []
	var pan := Vector2.ZERO
	var zoom := 0.72
	var _dragging_feature: Dictionary = {}
	var _dragging_object := -1
	var _panning := false
	var _last_mouse := Vector2.ZERO
	var _background_texture: Texture2D
	var _object_texture: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_background_texture = _load_texture("res://assets/art_lab/exploration/exploration-background.png")
		_object_texture = _load_texture("res://assets/art_lab/exploration/exploration-objects-alpha.png")

	func begin_feature_drag(feature: Dictionary) -> void:
		_dragging_feature = feature.duplicate(true)
		_dragging_object = -1
		queue_redraw()

	func has_feature_drag() -> bool:
		return not _dragging_feature.is_empty()

	func cancel_feature_drag() -> void:
		_dragging_feature = {}
		queue_redraw()

	func place_feature_at_global(global_pos: Vector2) -> void:
		_place_feature(global_pos - global_position)
		_dragging_feature = {}
		queue_redraw()

	func load_map() -> void:
		objects = _default_objects()
		var path := ProjectSettings.globalize_path(MAP_PATH)
		if not FileAccess.file_exists(path):
			queue_redraw()
			return
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return
		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			return
		var loaded: Array = parsed.get("objects", [])
		objects = []
		for item in loaded:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			objects.append({
				"type": str(item.get("type", "sugar")),
				"variant": int(item.get("variant", 0)),
				"pos": Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0))),
				"scale": float(item.get("scale", 1.0)),
				"angle": float(item.get("angle", 0.0))
			})
		queue_redraw()

	func save_map() -> String:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data"))
		var payload := {"objects": []}
		for item in objects:
			var pos: Vector2 = item.get("pos", Vector2.ZERO)
			payload["objects"].append({
				"type": str(item.get("type", "sugar")),
				"variant": int(item.get("variant", 0)),
				"x": snappedf(pos.x, 1.0),
				"y": snappedf(pos.y, 1.0),
				"scale": float(item.get("scale", 1.0)),
				"angle": float(item.get("angle", 0.0))
			})
		var path := ProjectSettings.globalize_path(MAP_PATH)
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return "Could not write map file."
		file.store_string(JSON.stringify(payload, "\t"))
		return "Saved %d objects to %s" % [objects.size(), MAP_PATH]

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				_zoom_at(1.08, event.position)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				_zoom_at(1.0 / 1.08, event.position)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_last_mouse = event.position
					var hit := _object_at(event.position)
					if hit >= 0:
						_dragging_object = hit
					elif _dragging_feature.is_empty():
						_panning = true
				else:
					if not _dragging_feature.is_empty():
						_place_feature(event.position)
					_dragging_feature = {}
					_dragging_object = -1
					_panning = false
					queue_redraw()
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				var hit := _object_at(event.position)
				if hit >= 0:
					objects.remove_at(hit)
					queue_redraw()
		elif event is InputEventMouseMotion:
			if _panning:
				pan += event.position - _last_mouse
				_last_mouse = event.position
				queue_redraw()
			elif _dragging_object >= 0:
				objects[_dragging_object]["pos"] = _snap_world(_screen_to_world(event.position))
				queue_redraw()
			elif not _dragging_feature.is_empty():
				queue_redraw()

	func _draw() -> void:
		_draw_background()
		_draw_grid()
		_draw_bounds()
		for item in objects:
			_draw_map_object(item, 1.0)
		if not _dragging_feature.is_empty():
			var preview := {
				"type": str(_dragging_feature.get("id", "sugar")),
				"variant": int(_dragging_feature.get("variant", 0)),
				"pos": _snap_world(_screen_to_world(get_local_mouse_position())),
				"scale": 1.0,
				"angle": 0.0
			}
			_draw_map_object(preview, 0.55)

	func _draw_background() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("07181c"), true)
		if _background_texture == null:
			return
		var source_size := Vector2(_background_texture.get_width(), _background_texture.get_height())
		var target := _cover_rect(source_size, Rect2(Vector2.ZERO, size))
		draw_texture_rect(_background_texture, target, false, Color(1, 1, 1, 0.36))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.05, 0.06, 0.28), true)

	func _draw_grid() -> void:
		var top_left := _screen_to_world(Vector2.ZERO)
		var bottom_right := _screen_to_world(size)
		var start_x: float = floor(top_left.x / GRID_SIZE) * GRID_SIZE
		var start_y: float = floor(top_left.y / GRID_SIZE) * GRID_SIZE
		var x: float = start_x
		while x <= bottom_right.x:
			var sx := _world_to_screen(Vector2(x, 0)).x
			draw_line(Vector2(sx, 0), Vector2(sx, size.y), Color(0.40, 0.95, 1.0, 0.12), 1.0)
			x += GRID_SIZE
		var y: float = start_y
		while y <= bottom_right.y:
			var sy := _world_to_screen(Vector2(0, y)).y
			draw_line(Vector2(0, sy), Vector2(size.x, sy), Color(0.40, 0.95, 1.0, 0.12), 1.0)
			y += GRID_SIZE

	func _draw_bounds() -> void:
		var rect := Rect2(_world_to_screen(WORLD_BOUNDS.position), WORLD_BOUNDS.size * zoom)
		draw_rect(rect, Color(0.46, 0.96, 1.0, 0.22), false, 2.0)

	func _draw_map_object(item: Dictionary, alpha: float) -> void:
		var pos: Vector2 = _world_to_screen(item.get("pos", Vector2.ZERO))
		var kind := str(item.get("type", "sugar"))
		var scale_value := float(item.get("scale", 1.0)) * zoom
		if _object_texture != null:
			var region := _object_sprite_region(kind, int(item.get("variant", 0)))
			var target_size := _object_sprite_size(kind) * scale_value
			_draw_texture_region_centered(_object_texture, region, pos, target_size, float(item.get("angle", 0.0)), Color(1, 1, 1, alpha))
		else:
			var color := _feature_color(kind)
			draw_circle(pos, 36.0 * scale_value, Color(0, 0, 0, 0.58 * alpha))
			draw_circle(pos, 28.0 * scale_value, Color(color.r, color.g, color.b, 0.86 * alpha))

	func _object_at(screen_pos: Vector2) -> int:
		for i in range(objects.size() - 1, -1, -1):
			var item := objects[i]
			var pos := _world_to_screen(item.get("pos", Vector2.ZERO))
			var radius := maxf(_object_sprite_size(str(item.get("type", "sugar"))).x, 120.0) * float(item.get("scale", 1.0)) * zoom * 0.45
			if pos.distance_to(screen_pos) <= radius:
				return i
		return -1

	func _place_feature(screen_pos: Vector2) -> void:
		objects.append({
			"type": str(_dragging_feature.get("id", "sugar")),
			"variant": int(_dragging_feature.get("variant", 0)),
			"pos": _snap_world(_screen_to_world(screen_pos)),
			"scale": 1.0,
			"angle": 0.0
		})

	func _zoom_at(factor: float, screen_pos: Vector2) -> void:
		var before := _screen_to_world(screen_pos)
		zoom = clampf(zoom * factor, 0.25, 2.2)
		var after := _screen_to_world(screen_pos)
		pan += (after - before) * zoom
		queue_redraw()

	func _world_to_screen(world: Vector2) -> Vector2:
		return world * zoom + size * 0.5 + pan

	func _screen_to_world(screen: Vector2) -> Vector2:
		return (screen - size * 0.5 - pan) / zoom

	func _snap_world(world: Vector2) -> Vector2:
		return Vector2(roundf(world.x / GRID_SIZE) * GRID_SIZE, roundf(world.y / GRID_SIZE) * GRID_SIZE)

	func _default_objects() -> Array[Dictionary]:
		return [
			{"type": "sugar", "variant": 0, "pos": Vector2(520, -220), "scale": 1.3, "angle": 0.0},
			{"type": "sulfur", "variant": 0, "pos": Vector2(980, 420), "scale": 1.2, "angle": 0.0},
			{"type": "nitrogen", "variant": 0, "pos": Vector2(-840, 680), "scale": 1.1, "angle": 0.0},
			{"type": "bacteria", "variant": 0, "pos": Vector2(-720, -520), "scale": 0.8, "angle": 0.4},
			{"type": "dead_cell", "variant": 0, "pos": Vector2(-360, 1150), "scale": 0.92, "angle": 0.25}
		]

	func _feature_color(kind: String) -> Color:
		for feature in features:
			if str(feature.get("id", "")) == kind:
				return feature.get("color", Color("76f4ff"))
		return Color("76f4ff")

	func _object_sprite_region(kind: String, variant: int) -> Rect2:
		var tex_size := Vector2(_object_texture.get_width(), _object_texture.get_height())
		var cell_w := tex_size.x / 4.0
		var cell_h := tex_size.y / 3.0
		match kind:
			"bacteria":
				return Rect2(Vector2(cell_w * float(variant % 4), 0.0), Vector2(cell_w, cell_h))
			"hostile":
				return Rect2(Vector2(cell_w, 0.0), Vector2(cell_w, cell_h))
			"sugar":
				return Rect2(Vector2(cell_w * float(variant % 2), cell_h), Vector2(cell_w, cell_h))
			"sulfur":
				return Rect2(Vector2(cell_w * float(2 + variant % 2), cell_h), Vector2(cell_w, cell_h))
			"nitrogen":
				return Rect2(Vector2(cell_w * 3.0, cell_h), Vector2(cell_w, cell_h))
			"dead_cell":
				return Rect2(Vector2(cell_w * float(variant % 2), cell_h * 2.0), Vector2(cell_w, cell_h))
			"virus":
				return Rect2(Vector2(cell_w * float(2 + variant % 2), cell_h * 2.0), Vector2(cell_w, cell_h))
		return Rect2(Vector2.ZERO, Vector2(cell_w, cell_h))

	func _object_sprite_size(kind: String) -> Vector2:
		match kind:
			"bacteria", "hostile":
				return Vector2(250, 170)
			"sugar", "nitrogen":
				return Vector2(145, 120)
			"sulfur":
				return Vector2(160, 145)
			"dead_cell":
				return Vector2(260, 190)
			"virus":
				return Vector2(120, 110)
		return Vector2(120, 100)

	func _draw_texture_region_centered(texture: Texture2D, region: Rect2, center: Vector2, target_size: Vector2, angle: float, modulate: Color) -> void:
		var x_axis := Vector2.RIGHT.rotated(angle) * target_size.x
		var y_axis := Vector2.DOWN.rotated(angle) * target_size.y
		var top_left := center - x_axis * 0.5 - y_axis * 0.5
		draw_set_transform_matrix(Transform2D(x_axis / region.size.x, y_axis / region.size.y, top_left))
		draw_texture_rect_region(texture, Rect2(Vector2.ZERO, region.size), region, modulate)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _cover_rect(source_size: Vector2, bounds: Rect2) -> Rect2:
		if source_size.x <= 0.0 or source_size.y <= 0.0:
			return bounds
		var scale_value := maxf(bounds.size.x / source_size.x, bounds.size.y / source_size.y)
		var fitted := source_size * scale_value
		return Rect2(bounds.position + (bounds.size - fitted) * 0.5, fitted)

	func _load_texture(path: String) -> Texture2D:
		var actual_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
		if not FileAccess.file_exists(actual_path):
			return null
		var image := Image.load_from_file(actual_path)
		if image == null:
			return null
		return ImageTexture.create_from_image(image)
