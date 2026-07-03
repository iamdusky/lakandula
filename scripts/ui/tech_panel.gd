extends PanelContainer
## Research panel (toggle with R). Lists all Mactan techs grouped by age;
## buttons enable when the tech is researchable (age unlocked + affordable).

const FACTION := "mactan"

var _rows := {}  # tech_id -> { label, button }
var _age_label: Label


func _ready() -> void:
	visible = false
	_build()
	EventBus.tech_researched.connect(func(_f: String, _id: String) -> void: _refresh())
	EventBus.resources_changed.connect(func(_f: String, _r: Dictionary) -> void: _refresh())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_tech"):
		visible = not visible
		if visible:
			_refresh()


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var title := Label.new()
	title.text = "RESEARCH (R)"
	box.add_child(title)
	_age_label = Label.new()
	_age_label.add_theme_font_size_override("font_size", 15)
	box.add_child(_age_label)

	var techs := TechTree.all_techs()
	techs.sort_custom(func(a: TechData, b: TechData) -> bool:
		return a.age < b.age if a.age != b.age else a.display_name < b.display_name)
	for tech in techs:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 15)
		label.tooltip_text = tech.description
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(label)
		var button := Button.new()
		button.text = "Research"
		var tech_id := tech.id
		button.pressed.connect(func() -> void:
			TechTree.research(FACTION, tech_id))
		row.add_child(button)
		box.add_child(row)
		_rows[tech.id] = {"label": label, "button": button}
	_refresh()


func _refresh() -> void:
	if _rows.is_empty():
		return
	_age_label.text = "Current age: %d" % TechTree.current_age(FACTION)
	for tech_id: String in _rows:
		var tech: TechData = TechTree.get_tech(tech_id)
		var label: Label = _rows[tech_id]["label"]
		var button: Button = _rows[tech_id]["button"]
		var done := TechTree.has_tech(FACTION, tech_id)
		label.text = "%s Age %s · %s (%s)" % [
			"✓" if done else "•", "I".repeat(tech.age), tech.display_name, _cost_text(tech.cost)]
		button.visible = not done
		button.disabled = not TechTree.can_research(FACTION, tech_id)


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource in cost:
		parts.append("%d%s" % [cost[resource], resource.left(1).to_upper()])
	return " ".join(parts)
