extends PanelContainer
## Bottom-left info card: portrait, name, and live health of the selected
## unit (first of a group, with a xN count) or building.
## Portraits follow the display_name slug convention:
##   "Lapu-Lapu" -> assets/gen/portrait_lapu_lapu.png

const PORTRAIT_DIR := "res://assets/gen/"
const FALLBACK_PORTRAIT := "res://assets/gen/portrait_structure.png"

var _target: Node2D = null
var _count := 1
var _portrait: TextureRect
var _name_label: Label
var _health_label: Label


func _ready() -> void:
	visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(48, 48)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_portrait)
	var column := VBoxContainer.new()
	row.add_child(column)
	_name_label = Label.new()
	column.add_child(_name_label)
	_health_label = Label.new()
	_health_label.add_theme_font_size_override("font_size", 15)
	column.add_child(_health_label)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.building_selected.connect(_on_building_selected)


func _process(_delta: float) -> void:
	if not visible:
		return
	if _target == null or not is_instance_valid(_target):
		visible = false
		_target = null
		return
	_health_label.text = "%d / %d" % [int(_target.health), int(_target.get_max_health())]


func _on_selection_changed(units: Array) -> void:
	if units.is_empty():
		visible = false
		_target = null
		return
	_target = units[0]
	_count = units.size()
	_show(_target.data.display_name)


func _on_building_selected(building: Node) -> void:
	if building == null:
		visible = false
		_target = null
		return
	_target = building
	_count = 1
	_show(building.display_name)


func _show(display_name: String) -> void:
	var slug := display_name.to_lower().replace("-", "_").replace(" ", "_")
	var path := PORTRAIT_DIR + "portrait_%s.png" % slug
	if not ResourceLoader.exists(path):
		path = FALLBACK_PORTRAIT
	_portrait.texture = load(path)
	_name_label.text = display_name if _count == 1 else "%s ×%d" % [display_name, _count]
	visible = true
