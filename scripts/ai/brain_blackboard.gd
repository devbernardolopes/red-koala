class_name BrainBlackboard
extends RefCounted

## Blackboard keys shared between [BrainComponent] and the behavior tree tasks.
##
## [BrainComponent] fills the dependency keys before every tick; tasks own the
## target keys. Keeping the names in one place avoids typos across resources.

const ACTIONS := &"actions"
const PERCEPTION := &"perception"
const BOARD := &"board"

## Array[Entity], refreshed before every tick.
const VISIBLE_HOSTILES := &"visible_hostiles"
## Entity currently being pursued, if any.
const TARGET := &"target"
## Last tile the target was seen on. Remembered after losing sight.
const LAST_KNOWN_TARGET_POS := &"last_known_target_pos"
## Whether [constant LAST_KNOWN_TARGET_POS] holds a position worth searching.
const HAS_LAST_KNOWN_TARGET_POS := &"has_last_known_target_pos"
