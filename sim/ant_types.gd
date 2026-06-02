## Shared definitions for the four ant castes.
##
## Step 1 (this prototype) only spawns/streams the first three for feel-testing;
## BOMBER is declared so the data shape is ready for later steps. Trail colour
## coding matches the original game: Worker = blue, Soldier = yellow,
## Spitter = red/orange (see handoff §4 and §8).
##
## Declared `class_name` so every other script can read these globally without
## an autoload — e.g. `AntTypes.COLORS[AntTypes.Type.WORKER]`.
class_name AntTypes
extends RefCounted

enum Type { WORKER, SOLDIER, SPITTER, BOMBER }

## Trail / caste colour coding (faithful to the original: worker=blue,
## soldier=yellow, spitter=pink).
const COLORS := {
	Type.WORKER:  Color(0.30, 0.58, 0.96),   # blue
	Type.SOLDIER: Color(0.97, 0.81, 0.22),   # yellow
	Type.SPITTER: Color(0.95, 0.42, 0.78),   # pink
	Type.BOMBER:  Color(0.40, 0.78, 0.42),   # green
}

const NAMES := {
	Type.WORKER:  "Worker",
	Type.SOLDIER: "Soldier",
	Type.SPITTER: "Spitter",
	Type.BOMBER:  "Bomber",
}

## Base outbound walking speed in px/sec. Per-ant variation is layered on top
## at spawn so the column never marches in lockstep.
const SPEED := {
	Type.WORKER:  92.0,
	Type.SOLDIER: 112.0,
	Type.SPITTER: 104.0,
	Type.BOMBER:  120.0,
}

## Visual scale of the drawn ant body, by caste.
const BODY_SCALE := {
	Type.WORKER:  1.0,
	Type.SOLDIER: 1.25,
	Type.SPITTER: 1.05,
	Type.BOMBER:  1.15,
}

static func color_of(t: int) -> Color:
	return COLORS.get(t, Color.WHITE)

static func name_of(t: int) -> String:
	return NAMES.get(t, "Ant")

static func speed_of(t: int) -> float:
	return float(SPEED.get(t, 100.0))

static func body_scale_of(t: int) -> float:
	return float(BODY_SCALE.get(t, 1.0))
