class_name Combat
extends RefCounted

## Stateless D&D-style combat rules.
##
## Nothing here mutates the world: [method resolve_attack] only returns an
## [AttackResult]. [EntityActions] is the single place that applies the result
## to hit points and the board.


## Rounds between natural regeneration ticks at a +0 ability modifier. Higher
## modifiers shorten the interval, lower ones lengthen it.
const REGEN_BASE_INTERVAL: int = 20
const REGEN_MIN_INTERVAL: int = 5
const REGEN_MAX_INTERVAL: int = 30


static func ability_modifier(score: int) -> int:
	return floori((score - 10) / 2.0)


## Rounds between natural regeneration ticks for [param modifier], clamped so
## regeneration can neither become instant nor effectively stop.
static func regen_interval(modifier: int) -> int:
	return clampi(REGEN_BASE_INTERVAL - modifier,
			REGEN_MIN_INTERVAL, REGEN_MAX_INTERVAL)


## Points restored by one natural regeneration tick at [param level].
static func regen_amount(level: int) -> int:
	@warning_ignore("integer_division")
	return 1 + level / 5


static func proficiency_bonus(level: int) -> int:
	@warning_ignore("integer_division")
	return 2 + (maxi(level, 1) - 1) / 4


## 10 plus the defense of every equipped armor piece plus the Dexterity
## modifier. Light or no armor uses the full modifier, medium armor caps it at
## +2 and heavy armor ignores it. The strictest category wins.
static func armor_class(entity: Entity) -> int:
	if not is_instance_valid(entity):
		return 10
	var defense: int = 0
	var has_medium_armor: bool = false
	var has_heavy_armor: bool = false
	for item: Item in entity.get_equipped_items():
		if not (item.data is ArmorData):
			continue
		var armor: ArmorData = item.data as ArmorData
		defense += armor.defense
		if armor.category.id == &"heavy_armor":
			has_heavy_armor = true
		elif armor.category.id == &"medium_armor":
			has_medium_armor = true
	var dexterity: int = ability_modifier(entity.dexterity)
	if has_heavy_armor:
		dexterity = 0
	elif has_medium_armor:
		dexterity = mini(dexterity, 2)
	return (10 + defense + dexterity
			- Encumbrance.defense_penalty(entity.encumbrance_level))


## The first equipped weapon in [member RaceData.body] order, or an unarmed
## strike (1d1, Strength) when nothing is equipped.
static func attack_profile(entity: Entity) -> AttackProfile:
	var profile: AttackProfile = AttackProfile.new()
	profile.damage_sides = 1
	if not is_instance_valid(entity):
		return profile
	var weapon: Item = _first_equipped_weapon(entity)
	if not weapon:
		return profile
	var weapon_data: WeaponData = weapon.data as WeaponData
	profile.weapon = weapon
	profile.attack_bonus = weapon_data.attack_bonus
	profile.damage_dice = weapon_data.damage_dice
	profile.damage_sides = weapon_data.damage_sides
	profile.damage_bonus = weapon_data.damage_bonus
	profile.is_ranged = weapon_data.ranged
	if weapon_data.ranged:
		profile.ability = &"DEX"
	elif weapon_data.finesse:
		if ability_modifier(entity.dexterity) > ability_modifier(entity.strength):
			profile.ability = &"DEX"
		else:
			profile.ability = &"STR"
	else:
		profile.ability = &"STR"
	return profile


## Total attack modifier: ability modifier plus proficiency plus the weapon's
## own bonus, reduced by any encumbrance penalty.
static func attack_bonus(entity: Entity, profile: AttackProfile) -> int:
	if not is_instance_valid(entity) or not profile:
		return 0
	return (entity.get_ability_modifier(profile.ability) 
			+ entity.get_proficiency_bonus() 
			+ profile.attack_bonus
			- Encumbrance.attack_penalty(entity.encumbrance_level))


## Rolls the attack and, on a hit, the damage. Never applies the result.
static func resolve_attack(attacker: Entity, target: Entity, profile: AttackProfile,
		advantage: Helper.DiceAdvantage = Helper.DiceAdvantage.NONE) -> AttackResult:
	var result: AttackResult = AttackResult.new()
	result.attacker = attacker
	result.target = target
	if not is_instance_valid(attacker) or not is_instance_valid(target) or not profile:
		return result
	var roll: Dictionary = Dice.roll_d20(attack_bonus(attacker, profile), advantage)
	result.natural = roll.get("natural", 0)
	result.total = roll.get("total", 0)
	result.target_ac = armor_class(target)
	result.fumble = result.natural == 1
	result.critical = result.natural == 20
	result.hit = (result.critical 
			or (not result.fumble and result.total >= result.target_ac))
	if result.hit:
		var dice_count: int = profile.damage_dice * (2 if result.critical else 1)
		var damage: int = Dice.roll(dice_count, profile.damage_sides)
		damage += attacker.get_ability_modifier(profile.ability) + profile.damage_bonus
		result.damage = maxi(damage, 0)
	return result


static func _first_equipped_weapon(entity: Entity) -> Item:
	if not (entity.data is EntityData):
		return null
	var race: RaceData = (entity.data as EntityData).race
	if not race:
		return null
	for part: AnatomyData in race.body:
		var item: Item = entity.get_equipped_item(part)
		if item and item.data is WeaponData:
			return item
	return null
