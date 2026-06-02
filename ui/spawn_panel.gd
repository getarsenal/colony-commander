## The bottom-right spawn cluster: one round button per caste to spend food on
## growing that caste's population (handoff §8). Mirrors the original's layout.
class_name SpawnPanel
extends CanvasLayer

const _BTN := preload("res://ui/spawn_button.gd")
const GAP := 12
const MARGIN := 22

var colony = null

var _bar: HBoxContainer
var _buttons := {}   # caste -> SpawnButton

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", GAP)
	add_child(_bar)
	for t in [AntTypes.Type.WORKER, AntTypes.Type.SOLDIER, AntTypes.Type.SPITTER]:
		var b: SpawnButton = _BTN.new()
		b.caste_type = t
		b.accent = AntTypes.color_of(t)
		b.cost = Colony.SPAWN_COST[t]
		b.buy.connect(_on_buy.bind(t))
		_buttons[t] = b
		_bar.add_child(b)

func _process(_delta: float) -> void:
	if colony == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_bar.size = _bar.get_combined_minimum_size()
	_bar.position = Vector2(vp.x - _bar.size.x - MARGIN, vp.y - _bar.size.y - MARGIN)
	for t in _buttons:
		var b: SpawnButton = _buttons[t]
		b.count = colony.pop.get(t, 0)
		b.affordable = colony.food >= b.cost

func _on_buy(t: int) -> void:
	colony.buy_caste(t)
