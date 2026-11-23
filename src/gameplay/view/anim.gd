class_name AnimView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/gameplay/view/Main.Anim.cs.
# Owner: Pham Minh Hieu. Which one-shot sprite animation a player plays. The frames are in the character sheets
# (art/chars/*.png, drawn by tools/PixelPoses.cs; chars.json "anims" says where they are):
#   attack_fists  - bare hands: guard, jab, impact, back to guard
#   attack_spear  - stone spear: drawn back, thrust, full reach, recover
#   attack_blade  - titanium blade: raised, slash across, follow-through, recover
#   attack_hammer - hammer: lifted overhead, coming down, smashed into the ground, recover
#   attack_bow    - starter bow and bow: nock, full draw, release, recover (the arrow is its own sprite)
#   long spear and stun maul play the spear / hammer frames with their own weapon drawn moving over them,
#   and a thrown flask, a set trap or a drunk tonic plays the jab frames (src/gameplay/view/tactical_items.gd)
#   down          - knocked down: hit, knees give, falling, lying still until revived
# An attack starts when GameSim's P.Swing does (MEC-02, MEC-03) and plays once.
# per character: when its current swing was first and last seen
var swings = {}
# per player: when they were first seen knocked down
var down_since = {}
static var WEAPON_ANIM = {"explosive_arrow": "attack_bow", "long_spear": "attack_spear", "stun_maul": "attack_hammer", "fists": "attack_fists", "stone_spear": "attack_spear", "titanium_blade": "attack_blade", "hammer": "attack_hammer", "starter_bow": "attack_bow", "bow": "attack_bow"}

var main: Main

func _init(host: Main) -> void:
	main = host

# The snapshot only says "swinging now", so a swing seen again after a gap is a new one.
# Returns when the latest swing started, or -1 if none was seen yet.
func swing_start(key_, flag: bool) -> float:
	var now: float = float(main.clock)
	var s = swings.get(key_, Swing.new())
	if flag:
		if not s.any or now - s.seen > 0.06:
			s.start = now
			s.any = true
		s.seen = now
		swings[key_] = s
	return s.start if s.any else -1.0

# seconds a one-shot animation of a sheet lasts (0 when the sheet has no animation of that name)
func anim_length(skin, name) -> float:
	var c = main.cinfo.chars.get(skin, null)
	var a_ = null if c == null else c.get("anims", {}).get(name, null)
	return 0.0 if a_ == null else float(a_[1]) / float(a_[2])

# the attack of the weapon a player holds and how far into it they are (null when not attacking)
func player_attack(id, p, skin) -> Variant:
	var start: float = self.swing_start(Cs.s(id), p[11])
	if start < 0:
		return null
	var weapon = Cs.s(p[8])
	var hand = p[7][int(p[25])]
	if hand != null and Cs.s(hand[0]) == "explosive_arrow":
		weapon = "explosive_arrow"
	var n = WEAPON_ANIM.get(weapon, null)
	var name = n if WEAPON_ANIM.has(weapon) else "attack_fists"
	# throwing a flask or setting a trap: an overhand throw (the jab frames); drinking a tonic too
	if hand != null and SimTacticalItems.is_tactical_use(Cs.s(hand[0])) and Cs.s(hand[0]) != "explosive_arrow":
		name = "attack_fists"
	var t: float = float(main.clock) - start
	return [name, t] if t < self.anim_length(skin, name) else null

# seconds since a player went down (the fall plays once, then they lie still); forgets them once they are up
func down_time(id, down: bool) -> float:
	var key_ = Cs.s(id)
	if not down:
		down_since.erase(key_)
		return 0.0
	var since = down_since.get(key_, 0.0)
	if not down_since.has(key_):
		since = float(main.clock)
		down_since[key_] = since
	return float(main.clock) - since

class Swing:
	var start: float = 0.0
	var seen: float = 0.0
	var any: bool = false
