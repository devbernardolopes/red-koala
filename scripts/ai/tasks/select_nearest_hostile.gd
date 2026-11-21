@tool
extends EntityActionTask

## Stores the nearest visible hostile on the blackboard and remembers where it
## was seen. When nothing is visible the target is cleared, but the last known
## position is kept so the entity can search there.
##
## Choosing a target is not a world action, so this does not spend the turn.


func _generate_name() -> String:
	return "Select nearest hostile"


func _tick(_delta: float) -> Status:
	var entity: Entity = _entity()
	var board: Board = _board()
	if not entity or not board:
		return FAILURE
	var hostiles: Array = blackboard.get_var(BrainBlackboard.VISIBLE_HOSTILES, [], false)
	var nearest: Entity = null
	var nearest_distance: int = 0
	for candidate: Variant in hostiles:
		if not candidate is Entity:
			continue
		var hostile: Entity = candidate as Entity
		var distance: int = Board.footprint_distance(board.get_origin(entity),
				entity.tile_size, board.get_origin(hostile), hostile.tile_size)
		if not nearest or distance < nearest_distance:
			nearest = hostile
			nearest_distance = distance
	if nearest:
		blackboard.set_var(BrainBlackboard.TARGET, nearest)
		blackboard.set_var(BrainBlackboard.LAST_KNOWN_TARGET_POS, board.get_origin(nearest))
		blackboard.set_var(BrainBlackboard.HAS_LAST_KNOWN_TARGET_POS, true)
	else:
		blackboard.set_var(BrainBlackboard.TARGET, null)
	return SUCCESS
