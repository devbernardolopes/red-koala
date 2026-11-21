@tool
class_name Hole
extends Base


func _ready() -> void:
	super._ready()


# TODO: Implement hole logic.
# If an entity walks into a hole and the entity is not flying then the entity
# will fall into the hole and get stuck for at least 1 action. That is, 1 action
# will automatically pass. Then whenever the entity tries to move into any 
# direction that is not blocked a check will be made (maybe a d20 with DEX
# modifier?). If succeds, then it will move out of the hole. If fails, it is a 
# lost action. If the entity enables flight then it will automatically leave 
# the hole. If the hole is concealed and the entity falls into it, then it will 
# be revealed. If the entity is bigger than the hole size (tile_size) then it
# will never fall into the hole but it will be revealed if concealed and the 
# entity walks over it (not fly). If a pushable object is pushed into the hole 
# it will fall into the hole and now the hole will be able to be walk upon and
# the object will be stuck forever. The object polygon(s) must be scaled down a
# bit so that it is apparent that the object is stuck in the hole.
