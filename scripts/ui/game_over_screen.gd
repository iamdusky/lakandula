extends ColorRect
## Full-screen win/loss overlay. Listens for EventBus.game_over, shows the
## historical outcome, and offers Retry (reload scene; autoloads reset via
## EventBus.game_started) / Quit. Runs while the tree is paused.

const RESULTS := {
	"magellan_killed": ["VICTORY", "April 27, 1521. In the shallows of Mactan, Ferdinand Magellan falls — struck down at the water's edge, his armored men helpless in the surf. The captains refuse to press the attack; the fleet weighs anchor. The islands remember."],
	"powder_starvation": ["VICTORY", "The Spanish guns have fallen silent — every last measure of powder spent. Without shot, armor is only weight. The expedition withdraws to Cebu, and then to the open sea."],
	"monsoon": ["VICTORY", "Day 60. The habagat breaks over the strait, and no deep-hulled fleet dares hold anchor against it. With the Kuta still standing, Spain's season of conquest is over."],
	"great_alliance": ["VICTORY", "Every datu of Mactan and Rajah Humabon himself now stand with Lapu-Lapu. Against a united archipelago, Spain's foothold crumbles into the sea."],
	"kuta_razed": ["DEFEAT", "The Kuta burns, and with the fortress falls the heart of the resistance. In another history, the walls held and a conqueror died in the shallows. Fight again."],
	"lapu_lapu_killed": ["DEFEAT", "Lapu-Lapu has fallen, and the coalition scatters to their barangays. Yet history remembers a different April morning — one where the Datu of Mactan stood in the surf and won. Fight again."],
	"full_conversion": ["DEFEAT", "Every barangay has taken baptism and flies Spanish colors. Mactan stands alone, surrounded by its own kin. Resistance without allies is a last stand — fight again."],
}

@onready var _title: Label = $Center/Box/TitleLabel
@onready var _body: Label = $Center/Box/BodyLabel
@onready var _stats: Label = $Center/Box/StatsLabel
@onready var _retry: Button = $Center/Box/Buttons/RetryButton
@onready var _menu: Button = $Center/Box/Buttons/MenuButton
@onready var _quit: Button = $Center/Box/Buttons/QuitButton


func _ready() -> void:
	visible = false
	EventBus.game_over.connect(_on_game_over)
	_retry.pressed.connect(_on_retry)
	_menu.pressed.connect(func() -> void:
		SceneFlow.goto("res://scenes/ui/main_menu.tscn"))
	_quit.pressed.connect(func() -> void: get_tree().quit())


func _on_game_over(_winner: String, condition: String) -> void:
	var entry: Array = RESULTS.get(condition, ["GAME OVER", ""])
	_title.text = entry[0]
	_body.text = entry[1]
	_stats.text = GameStats.summary()
	visible = true


func _on_retry() -> void:
	SceneFlow.reload()  # unpauses and fades
