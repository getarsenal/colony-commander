## Spawns short-lived FxBit flourishes and owns world screen-shake (handoff §5).
##
## Lives in the world (under Main's Node2D) so puffs/labels sit in world space and
## ride the shake. Shake is applied by Main reading `shake_offset` each frame —
## the FX layer just accumulates trauma and decays it.
class_name FxLayer
extends Node2D

const _BIT := preload("res://fx/fx_bit.gd")

var _trauma := 0.0          # 0..1, squared into shake so small hits stay subtle
var shake_offset := Vector2.ZERO

func puff(pos: Vector2, color: Color, radius: float = 14.0) -> void:
	var b := _BIT.new()
	add_child(b)
	b.setup_puff(pos, color, radius)

func popup(pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	var b := _BIT.new()
	add_child(b)
	b.setup_text(pos, text, color)

func add_shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = max(0.0, _trauma - delta * 1.8)
		var s := _trauma * _trauma * 7.0
		shake_offset = Vector2(randf_range(-s, s), randf_range(-s, s))
	else:
		shake_offset = Vector2.ZERO
