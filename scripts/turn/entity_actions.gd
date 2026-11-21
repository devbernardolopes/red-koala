class_name EntityActions
extends Node

## The only place that mutates the world on behalf of an entity.
##
## Both player input and AI brains go through this node, so AI cannot perform
## actions the player could not, and every action spends its own energy cost.
## [method begin_turn] arms exactly one action: after the first successful
## action every further call fails until [method end_turn] is used. This is
## what stops a behavior tree from moving twice in a single turn.

var board: Board = null
## Kept untyped to avoid a dependency cycle with the universe script.
var universe = null

## Energy spent by the most recent action. Actions may override this when
## variable costs are introduced.
var last_cost: int = TurnManager.ACTION_COST

var _actor: Entity = null
var _acted: bool = false


func begin_turn(actor: Entity) -> void:
	_actor = actor
	_acted = false
	last_cost = TurnManager.ACTION_COST


## Ends the current action opportunity. Returns whether anything happened, so
## the turn manager knows whether to spend energy or keep waiting for input.
func end_turn() -> bool:
	var acted: bool = _acted
	_actor = null
	_acted = false
	return acted


func has_acted() -> bool:
	return _acted


## Steps one tile. Moving into a pushable element pushes it when possible.
func move(entity: Entity, direction: Vector2i) -> bool:
	if not _can_act(entity):
		return false
	var dir: Vector2i = Vector2i(int(direction.x > 0) - int(direction.x < 0),
			int(direction.y > 0) - int(direction.y < 0))
	if dir == Vector2i.ZERO:
		return false
	var mode: Helper.MoveMode = entity.get_move_mode()
	var move_to: Vector2i = board.get_origin(entity) + dir
	# Diagonal movement must not cut corners, exactly like Board.can_step and
	# the A* search. A diagonal push also needs both orthogonal tiles clear.
	if dir.x != 0 and dir.y != 0:
		var origin: Vector2i = board.get_origin(entity)
		if not board.can_occupy(entity, origin + Vector2i(dir.x, 0), mode) \
				or not board.can_occupy(entity, origin + Vector2i(0, dir.y), mode):
			return false
	# Only single-tile movers push for now; multi-tile pushing needs its own
	# rules and there are no multi-tile player characters.
	if entity.tile_size == 1:
		for element: Base in board.get_elements_at(move_to):
			if element.walkable:
				continue
			if element.pushable:
				return _push(entity, element, dir, move_to)
			if mode != Helper.MoveMode.PHASE:
				return false
			break
	if not board.can_occupy(entity, move_to, mode):
		return false
	_move_element(entity, dir)
	_acted = true
	return true


## Takes an item from the tile the entity is standing on.
func take(entity: Entity, item: Item) -> bool:
	if not _can_act(entity) or not item:
		return false
	var origin: Vector2i = board.get_origin(entity)
	if not board.get_elements_at(origin).has(item):
		return false
	if not entity.take(item):
		return false
	board.unregister(item)
	Journal.took(item, entity)
	_acted = true
	_after_item_change()
	return true


## Drops an item onto the entity's tile.
func drop(entity: Entity, item: Item) -> bool:
	if not _can_act(entity) or not item:
		return false
	if not entity.inventory.has(item):
		return false
	if not entity.drop(item):
		return false
	if universe and universe.items_node:
		universe.items_node.add_child(item)
	else:
		add_child(item)
	board.register(item)
	Journal.dropped(item, entity)
	for element: Base in board.get_elements_at(board.get_origin(item)):
		if element is TeleportPad:
			(element as TeleportPad).teleport(item)
	board.sync_from_position(item)
	_acted = true
	_after_item_change()
	return true


## Equips or unequips an item. A refused cursed item does not spend the turn.
func equip(entity: Entity, item: Item) -> Entity.EquipResult:
	if not _can_act(entity) or not item:
		return Entity.EquipResult.INVALID
	var result: Entity.EquipResult = entity.equip(item)
	match result:
		Entity.EquipResult.EQUIPPED:
			Journal.equipped(item, entity)
			_acted = true
		Entity.EquipResult.UNEQUIPPED:
			Journal.unequipped(item, entity)
			_acted = true
		Entity.EquipResult.REFUSED_CURSED:
			Journal.refused_removal(item, entity)
	return result


## Combat is not implemented yet. This reserves the turn and journal entry so
## behavior trees can be built and tested against the real action flow.
func attack(entity: Entity, target: Entity) -> bool:
	if not _can_act(entity) or not is_instance_valid(target) or target == entity:
		return false
	Journal.attacked(entity, target)
	_acted = true
	return true


## Spends the action without doing anything in the world.
func wait(entity: Entity) -> bool:
	if not _can_act(entity):
		return false
	_acted = true
	return true


func _can_act(entity: Entity) -> bool:
	if not board or not is_instance_valid(entity):
		return false
	if entity != _actor or _acted:
		return false
	return not entity.is_queued_for_deletion()


func _push(entity: Entity, pushable: Base, dir: Vector2i, move_to: Vector2i) -> bool:
	# TODO: Not everything that is pushable is a Crate.
	var crate: Crate = pushable if pushable is Crate else null
	if not crate:
		return false
	# The mover takes the pushable's former tile, so it must be free for
	# everything else on it (e.g. a closed door under the crate).
	for element: Base in board.get_elements_at(move_to):
		if element != crate and not element.walkable:
			return false
	for element: Base in board.get_elements_at(move_to + dir):
		if not element.walkable:
			return false
	# Move the crate first: a TeleportPad it lands on must not move the pusher
	# while the push is still in progress.
	_move_element(crate, dir)
	_move_element(entity, dir)
	_acted = true
	return true


func _move_element(element: Base, dir: Vector2i) -> void:
	board.move_element(element, board.get_origin(element) + dir)
	for other: Base in board.get_elements_at(board.get_origin(element)):
		if other is TeleportPad:
			# Teleporting sets the position directly, so the index has to catch
			# up afterwards.
			(other as TeleportPad).teleport(element)
	board.sync_from_position(element)
	if universe:
		universe.after_element_moved(element)


func _after_item_change() -> void:
	if universe:
		universe.after_item_change()
