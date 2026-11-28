class_name SimInventory
extends RefCounted

# Part of GameSim (game_sim.gd); in the C# version this was src/gameplay/GameSim.Inventory.cs.
# Rules only: the match state lives on GameSim, passed in as `sim`.
const STACK: int = 20
# A crafted bow carries its own arrows: a bow slot is [id, 1, arrows loaded], up to QUIVER, so the arrows take
# no slot of their own. Arrows a player gets go into a bow first; "arrow" counts and takes cover both.
const QUIVER: int = 30

# constants shared with GameSim
const INV_SLOTS = GameSim.INV_SLOTS
const T = GameSim.T

static func empty_slots(n: int) -> Variant:
	var slots = []
	for i in range(n):
		slots.append(null)
	return slots

static func item_name(id) -> Variant:
	var component: int = GameSim.COMPONENT_IDS.find(Cs.s(id))
	if component >= 0:
		return GameSim.SUPPLY_NAMES[component]
	var rescue: int = SimSupplies.rescue_kind(Cs.s(id))
	if rescue >= 0:
		return "Locator radio"
	return GameSim.ITEMS[id][0] if GameSim.ITEMS.has(id) else Cs.s(id)

static func stack_of(id) -> int:
	return int(GameSim.ITEMS[id][1]) if GameSim.ITEMS.has(id) else 1

static func kind_of(id) -> Variant:
	return GameSim.ITEMS[id][2] if GameSim.ITEMS.has(id) else ""

# --- a bow's arrows ---------------------------------------------------------
static func is_bow(s) -> bool:
	return s != null and s[0] == "bow"

# Arrows loaded in the bow of slot S (0 for any other slot).
static func loaded(s) -> int:
	return int(s[2]) if is_bow(s) and s.size() > 2 else 0

static func bow_slot(arrows_: int) -> Variant:
	return ["bow", 1, arrows_]

static func use_bow_arrow(p) -> bool:
	var selected = p.inv[int(p.sel)]
	if is_bow(selected) and loaded(selected) > 0:
		p.inv[int(p.sel)] = bow_slot(loaded(selected) - 1)
		return true
	return take_from(p.inv, "arrow", 1)

# Loads up to N arrows into the bows of a slot array; returns what did not fit.
static func load_arrows(slots, n: int) -> int:
	var i: int = 0
	while i < slots.size() and n > 0:
		var s = slots[i]
		if is_bow(s) and loaded(s) < QUIVER:
			var put: int = mini(n, QUIVER - loaded(s))
			slots[i] = bow_slot(loaded(s) + put)
			n -= put
		i += 1
	return n

# Moves loose arrows of a slot array into its bows, emptying the arrow slots first from the back.
static func load_bows(slots) -> void:
	var room_: int = 0
	var loose: int = 0
	for s in slots:
		if is_bow(s):
			room_ += QUIVER - loaded(s)
		elif s != null and s[0] == "arrow":
			loose += int(s[1])
	var n: int = mini(room_, loose)
	if n > 0:
		take_loose(slots, "arrow", n)
		load_arrows(slots, n)

# --- slot arrays (a player's inventory or the storage) -------------------
static func count_in(slots, id) -> int:
	var n: int = 0
	var arrows_: bool = id == "arrow"
	for s in slots:
		if s != null and s[0] == id:
			n += int(s[1])
		elif arrows_:
			n += loaded(s)
	return n

static func room_in(slots, id) -> int:
	var room_: int = 0
	var stack: int = stack_of(id)
	var arrows_: bool = id == "arrow"
	for s in slots:
		if s == null:
			room_ += stack
		elif s[0] == id:
			room_ += stack - int(s[1])
		elif arrows_ and is_bow(s):
			room_ += QUIVER - loaded(s)
	return room_

static func prefers_inner_bag(id) -> bool:
	var k = kind_of(id)
	return k == "res" or k == "quest"

static func _top_up_range(slots, id, n: int, stack: int, start: int, end: int) -> int:
	var i: int = start
	while i < end and n > 0:
		var s = slots[i]
		if s != null and s[0] == id and int(s[1]) < stack:
			var put: int = mini(n, stack - int(s[1]))
			slots[i] = [id, int(s[1]) + put]
			n -= put
		i += 1
	return n

static func _fill_empty_range(slots, id, n: int, stack: int, start: int, end: int) -> int:
	var i: int = start
	while i < end and n > 0:
		if slots[i] == null:
			var put: int = mini(n, stack)
			slots[i] = [id, put]
			n -= put
		i += 1
	return n

# Adds up to N into a generic container (chest/storage); returns what did not fit.
static func add_to(slots, id, n: int) -> int:
	var stack: int = stack_of(id)
	if id == "arrow":
		n = load_arrows(slots, n)
	n = _top_up_range(slots, id, n, stack, 0, slots.size())
	n = _fill_empty_range(slots, id, n, stack, 0, slots.size())
	return n

# Adds up to N into a player's inventory with hotbar priority:
# - Weapons and equipment/usable gear go into hotbar slots 1-4 (0..HOTBAR-1) first, even shifting a raw
#   resource out of the hotbar into a free inner-bag slot when needed.
# - Raw resources (wood, stone, herb, titanium) and quest parts go into inner-bag slots (HOTBAR..end) first,
#   only spilling into the hotbar when the inner bag has no room left.
static func add_to_player(slots, id, n: int) -> int:
	var stack: int = stack_of(id)
	if id == "arrow":
		n = load_arrows(slots, n)
	var hot: int = mini(GameSim.HOTBAR, slots.size())
	if prefers_inner_bag(id):
		n = _top_up_range(slots, id, n, stack, hot, slots.size())
		n = _fill_empty_range(slots, id, n, stack, hot, slots.size())
		n = _top_up_range(slots, id, n, stack, 0, hot)
		n = _fill_empty_range(slots, id, n, stack, 0, hot)
		return n
	n = _top_up_range(slots, id, n, stack, 0, hot)
	n = _top_up_range(slots, id, n, stack, hot, slots.size())
	n = _fill_empty_range(slots, id, n, stack, 0, hot)
	# If hotbar is full of raw resources while inner bag has an empty slot, move a resource inward so gear lands on 1-4.
	var i: int = 0
	while i < hot and n > 0:
		var s = slots[i]
		if s != null and prefers_inner_bag(s[0]):
			var free_bag: int = -1
			for j in range(hot, slots.size()):
				if slots[j] == null:
					free_bag = j
					break
			if free_bag < 0:
				break
			slots[free_bag] = s
			var put: int = mini(n, stack)
			slots[i] = [id, put]
			n -= put
		i += 1
	n = _fill_empty_range(slots, id, n, stack, hot, slots.size())
	return n

# Removes N if there are that many (from the last slots first); otherwise removes nothing. Arrows come out of
# the loose stacks first, so a slot frees up as soon as it can, then out of the bows.
static func take_from(slots, id, n: int) -> bool:
	if count_in(slots, id) < n:
		return false
	n -= take_loose(slots, id, n)
	var i: int = slots.size() - 1
	while i >= 0 and n > 0:
		var s = slots[i]
		if id == "arrow" and loaded(s) > 0:
			var got: int = mini(n, loaded(s))
			n -= got
			slots[i] = bow_slot(loaded(s) - got)
		i -= 1
	return true

# Removes up to N from the stacks of Id (from the last slots first); returns how many it took.
static func take_loose(slots, id, n: int) -> int:
	var want: int = n
	var i: int = slots.size() - 1
	while i >= 0 and n > 0:
		var s = slots[i]
		if s != null and s[0] == id:
			var got: int = mini(n, int(s[1]))
			n -= got
			slots[i] = [id, int(s[1]) - got] if int(s[1]) - got > 0 else null
		i -= 1
	return want - n

# --- a player's inventory --------------------------------------------------
static func count(sim: GameSim, p, id) -> int:
	return count_in(p.inv, id)

static func room(sim: GameSim, p, id) -> int:
	return room_in(p.inv, id)

static func take(sim: GameSim, p, id, n) -> bool:
	return take_from(p.inv, id, int(n))

# Puts items in the inventory; whatever does not fit is dropped at the player's feet.
static func add_item(sim: GameSim, p, id, n) -> void:
	if kind_of(id) == "bag":
		equip_bag(p, id)
		return
	# armour is worn at once and takes no bag slot
	if kind_of(id) == "armour":
		p.armour = maxi(int(p.armour), GameSim.ARMOUR_ITEMS.find(id))
		return
	var left: int = add_to_player(p.inv, id, int(n))
	load_bows(p.inv)
	if left > 0:
		player_drop(sim, p.pos, id, left)
		SimPlayers.note(sim, p, "Bag full - dropped")

# Sets how many of an item a player carries (tests and debug).
static func set_count(sim: GameSim, p, id, n) -> void:
	take_from(p.inv, id, count(sim, p, id))
	add_to_player(p.inv, id, int(n))

static func give_starting_kit(sim: GameSim, p) -> void:
	# Team change to BAL-42: no basic weapon item; everyone fights bare-handed when the selected slot holds
	# No weapon. Scout: starter bow; Engineer: hammer; Healer: empty hands.
	p.inv = empty_slots(INV_SLOTS)
	p.bag_tier = 0
	if p.role == 0:
		p.inv[0] = ["starter_bow", 1]
	elif p.role == 2:
		p.inv[0] = ["hammer", 1]
	p.sel = 0

# Upgrades replace the worn bag: bonuses are totals, never cumulative. Keep every slot.
static func equip_bag(p, id: String) -> void:
	var tier: int = GameSim.BAG_ITEMS.find(id)
	if tier <= int(p.get("bag_tier", 0)):
		return
	p.bag_tier = tier
	var capacity: int = INV_SLOTS + int(GameSim.BAG_BONUS[tier])
	while p.inv.size() < capacity:
		p.inv.append(null)

# The weapon in hand: the item in the selected hotbar slot if it is a weapon, otherwise bare hands.
static func weapon_of(sim: GameSim, p) -> Variant:
	var s = p.inv[int(p.sel)]
	if s != null and kind_of(s[0]) == "weapon":
		return s[0]
	return "fists"

static func weapon_name(id) -> Variant:
	return "Bare hands" if id == "fists" else item_name(id)

# Armour is worn from the inventory: the best piece carried counts (BAL-11).
# The armour worn (0 none, 1 light, 2 stone, 3 titanium). Armour is not kept in the bag: it is worn as soon as
# it is crafted or picked up, the best piece kept.
static func armour_tier(sim: GameSim, p) -> int:
	return int(p.armour)

# Any armour that reached the bag (taken from storage, picked up) is put on at once and leaves the bag.
static func wear_armour(sim: GameSim, p) -> void:
	for tier in range(1, GameSim.ARMOUR_ITEMS.size()):
		var id = GameSim.ARMOUR_ITEMS[tier]
		var have: int = count(sim, p, id)
		if have > 0:
			take_from(p.inv, id, have)
			p.armour = maxi(int(p.armour), tier)

# Storage is the chest by the north wall (GameSim.STORAGE_POS): reachable standing at it, inside the base by
# day, or as the Engineer inside at night.
static func at_storage(sim: GameSim, p) -> bool:
	return SimPlayers.in_base_to_work(sim, p) and SimWorld.near_storage(Vector2(p.pos))

static func inventory_box(sim: GameSim, p, box) -> Variant:
	if box == "inv":
		return p.inv
	if box == "sto":
		return sim.storage if at_storage(sim, p) else null
	var _c1 = not box.begins_with("chest:")
	var id
	if not _c1:
		id = box.substr(6).to_int()
		_c1 = not box.substr(6).is_valid_int()
	if _c1:
		return null
	var c = SimSupplies.chest_by_id(sim, id)
	return c.slots if SimSupplies.can_access_chest(sim, p, c) else null

# Drag and drop between the inventory ("inv"), storage ("sto"), chests ("chest:N"), or radio ("radio"): swaps or merges.
static func _sync_chest_component(sim: GameSim, box: String) -> void:
	if not box.begins_with("chest:"):
		return
	var chest = SimSupplies.chest_by_id(sim, box.substr(6).to_int())
	if chest == null:
		return
	chest.component = -1
	for s in chest.slots:
		if s != null:
			var comp: int = GameSim.COMPONENT_IDS.find(Cs.s(s[0]))
			if comp >= 0:
				chest.component = comp
				return

static func move_slot(sim: GameSim, p, arg) -> void:
	if p.state != 0 or not arg is Array or arg.size() < 4:
		return
	var from_box = Cs.s(arg[0])
	var to_box = Cs.s(arg[2])
	var a: int = int(arg[1])
	var b: int = int(arg[3])
	if from_box == "inv" and to_box == "radio":
		if a < 0 or a >= p.inv.size() or p.inv[a] == null:
			return
		var comp: int = GameSim.COMPONENT_IDS.find(Cs.s(p.inv[a][0]))
		if comp >= 0:
			SimSupplies.insert_radio_part(sim, p, comp)
		return
	var from = inventory_box(sim, p, from_box)
	var to = inventory_box(sim, p, to_box)
	if from == null or to == null:
		SimPlayers.note(sim, p, "Out of reach")
		return
	if a < 0 or a >= from.size() or b < 0 or b >= to.size() or from_box == to_box and a == b:
		return
	var sa = from[a]
	var sb = to[b]
	if sa == null:
		return
	var component: int = GameSim.COMPONENT_IDS.find(Cs.s(sa[0]))
	if to_box == "inv" and kind_of(sa[0]) == "bag":
		if GameSim.BAG_ITEMS.find(sa[0]) > int(p.get("bag_tier", 0)):
			from[a] = null
			equip_bag(p, sa[0])
		return
	# Starter bows never accept ammunition; full crafted bows keep both slots intact.
	if sb != null and ((sa[0] == "arrow" and sb[0] == "starter_bow") or (sb[0] == "arrow" and sa[0] == "starter_bow")):
		return
	# arrows dropped on a bow (or a bow on arrows) are loaded into it
	var bow = sb if is_bow(sb) else sa if is_bow(sa) else null
	var ammo = sa if is_bow(sb) else sb
	if bow != null and ammo != null and ammo[0] == "arrow":
		if loaded(bow) >= QUIVER:
			return
		var put: int = mini(int(ammo[1]), QUIVER - loaded(bow))
		var rest_ = ["arrow", int(ammo[1]) - put] if int(ammo[1]) - put > 0 else null
		var full = bow_slot(loaded(bow) + put)
		# the bow stays in its slot, what is left of the arrows stays in theirs
		from[a] = full if is_bow(sa) else rest_
		to[b] = full if is_bow(sb) else rest_
		SimPlayers.note(sim, p, "+%d arrows" % [put])
		return
	if sb != null and sa[0] == sb[0] and stack_of(sa[0]) > 1:
		var stack: int = stack_of(sa[0])
		var put: int = mini(int(sa[1]), stack - int(sb[1]))
		to[b] = [sb[0], int(sb[1]) + put]
		from[a] = [sa[0], int(sa[1]) - put] if int(sa[1]) - put > 0 else null
		return
	from[a] = sb
	to[b] = sa
	_sync_chest_component(sim, from_box)
	_sync_chest_component(sim, to_box)
	SimSupplies.sync_rescue_components(sim)
	if component >= 0 and from_box.begins_with("chest:") and to_box == "inv":
		SimPlayers.say(sim, "%d/3 - %s (bring to radio)" % [SimSupplies.supplies_got(sim), GameSim.SUPPLY_NAMES[component]])
		sim.msg_t = 3.5
	load_bows(p.inv)

# G: hand the selected stack to the nearest teammate in reach (1.5 tiles), otherwise drop it (MEC-09).
static func give_or_drop(sim: GameSim, p) -> void:
	var sel: int = int(p.sel)
	var s = p.inv[sel]
	if s == null or p.state != 0:
		return
	var best = null
	var best_d: float = 1.5 * T
	for q in sim.players.values():
		if q.id != p.id and q.state == 0 and q.pos.distance_to(p.pos) <= best_d and room_in(q.inv, s[0]) > 0:
			best_d = q.pos.distance_to(p.pos)
			best = q
	p.inv[sel] = null
	var arrows_: int = loaded(s)
	if best != null:
		var left: int = add_to_player(best.inv, s[0], int(s[1]))
		if left > 0:
			p.inv[sel] = s if is_bow(s) else [s[0], left]
		elif arrows_ > 0:
			# the bow's arrows go with it: into its new owner's bows or bag, the rest at their feet
			var over: int = add_to_player(best.inv, "arrow", arrows_)
			if over > 0:
				player_drop(sim, best.pos, "arrow", over)
		SimSupplies.sync_rescue_components(sim)
		SimPlayers.note(sim, p, "%s to %s" % [item_name(s[0]), best.name])
		SimPlayers.note(sim, best, "%s: +%s" % [p.name, item_name(s[0])])
		return
	player_drop(sim, p.pos, s[0], s[1])
	if arrows_ > 0:
		player_drop(sim, p.pos, "arrow", arrows_)
	SimSupplies.sync_rescue_components(sim)

# Items dropped by players stay until someone picks them up with E (MEC-09).
static func player_drop(sim: GameSim, pos, id, n) -> void:
	sim.drops.append({"pos": pos, "item": id, "n": int(n), "ttl": -1.0, "player": true})
	SimAudio.emit(sim, "item_drop", pos)

# E next to a dropped item: picks up as much as fits. Returns true when there was something to pick up.
static func pick_up(sim: GameSim, p) -> bool:
	for d in sim.drops:
		if d.get("player", false) and d.pos.distance_to(p.pos) <= 1.2 * T:
			var left: int = add_to_player(p.inv, d.item, int(d.n))
			if left == int(d.n):
				SimPlayers.note(sim, p, "Bag full")
				return true
			d.n = left
			sim.drops = sim.drops.filter(func(x): return x.n > 0)
			load_bows(p.inv)
			SimSupplies.sync_rescue_components(sim)
			return true
	return false
