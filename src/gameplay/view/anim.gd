class_name AnimView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/gameplay/view/Main.Anim.cs.
# Owner: Pham Minh Hieu. Which one-shot sprite animation a player plays. The frames are in the character sheets
# Each role's own PNG supplies walking, farming, item-use and nine integrated attack clips.
# chars.json indexes each body + arms + weapon pose, six frames in eight directions.
# Melee weapons drive from beside the torso outward along aim; bows draw/release,
# and explosive ammo has its own arrow.
# Throwing a flask, setting a trap and drinking still use the original jab frames.
#   down          - knocked down: hit, knees give, falling, lying still until revived
# An attack starts when GameSim's P.Swing does (MEC-02, MEC-03) and plays once.
# per character: when its current swing was first and last seen
var swings = {}
# per player: when they were first seen knocked down
var down_since = {}
static var WEAPON_ANIM = {"explosive_arrow": "combat_explosive_arrow", "long_spear": "combat_long_spear", "stun_maul": "combat_stun_maul", "fists": "combat_fists", "stone_spear": "combat_stone_spear", "titanium_blade": "combat_titanium_blade", "hammer": "combat_hammer", "starter_bow": "combat_starter_bow", "bow": "combat_bow"}

var main: Main

func _init(host: Main) -> void:
	main = host

static func hit_height(kind: String, progress: float) -> float:
	if kind in ["stun", "root", "shock", "pull"]:
		return 0.0
	var peak: float = 36.0 if kind == "slam" else 22.0 if kind == "launch_short" else 16.0
	return peak * sin(PI * clampf(progress, 0, 1))

func hit_reaction(id, p) -> Variant:
	if int(p[5]) != 0 or main.snap.get("ph", "") == "result":
		return null
	var hit = main.snap.get("hit_reactions", {}).get(id)
	if hit == null:
		return null
	var age: float = float(hit[2]) + (0.0 if main.pause_menu.paused else clampf(float(main.clock) - main.hit_snapshot_at, 0, 0.05))
	var progress: float = clampf(age / float(hit[3]), 0, 1)
	var kind: String = Cs.s(hit[1])
	var clip: String = "stunned" if kind == "stun" else "rooted" if kind == "root" else "shocked" if kind == "shock" else "hit_launch" if kind in ["slam", "launch_short"] else "hit_knockback"
	var grounded: bool = kind in ["stun", "root", "shock"]
	return [clip, age, hit_height(kind, progress), float(p[12]) if grounded else Vector2(hit[4]).angle() + (0 if kind == "pull" else PI)]

# Legacy snapshots use the swing flag; current snapshots also identify each successful attack.
# Returns when the latest swing started, or -1 if none was seen yet.
func swing_start(key_, flag: bool) -> float:
	var now: float = float(main.clock)
	var s = swings.get(key_, Swing.new())
	if flag:
		if not s.active or now - s.seen > 0.4:
			s.start = now
			s.any = true
		s.seen = now
	swings[key_] = s
	s.active = flag
	return s.start if s.any else -1.0

# seconds a one-shot animation of a sheet lasts (0 when the sheet has no animation of that name)
func anim_length(skin, name) -> float:
	var combat = main.player_view.combat_animation(Cs.s(skin), Cs.s(name))
	if combat != null:
		return float(main.player_view.combat_info.frames) / float(combat.fps)
	var c = main.cinfo.chars.get(skin, null)
	var a_ = null if c == null else c.get("anims", {}).get(name, null)
	return 0.0 if a_ == null else float(a_[1]) / float(a_[2])

# the attack of the weapon a player holds and how far into it they are (null when not attacking)
func player_attack(id, p, skin) -> Variant:
	var start: float = self.swing_start(Cs.s(id), p[11])
	var state = swings.get(Cs.s(id))
	var authoritative = main.snap.get("attack_pose", {}).get(id)
	if authoritative != null and int(authoritative[0]) > 0 and int(authoritative[0]) != state.sequence:
		if state.sequence >= 0 or bool(p[11]):
			state.start = float(main.clock)
			state.any = true
			start = state.start
		state.sequence = int(authoritative[0])
	if start < 0:
		return null
	var weapon = Cs.s(p[8])
	var hand = p[7][int(p[25])]
	if hand != null and Cs.s(hand[0]) == "explosive_arrow":
		weapon = "explosive_arrow"
	if authoritative != null and int(authoritative[0]) > 0:
		weapon = Cs.s(authoritative[1])
	var n = WEAPON_ANIM.get(weapon, null)
	var name = n if WEAPON_ANIM.has(weapon) else "attack_fists"
	# throwing a flask or setting a trap: an overhand throw (the jab frames); drinking a tonic too
	if authoritative == null and hand != null and SimTacticalItems.is_tactical_use(Cs.s(hand[0])) and Cs.s(hand[0]) != "explosive_arrow":
		name = "attack_fists"
	if state.pose_start != start:
		state.pose_start = start
		state.pose = name
		state.aim = float(authoritative[2]) if authoritative != null else float(p[12])
	name = state.pose
	var t: float = float(main.clock) - start
	if t < 0:
		return null
	# Speed up combat poses together with their cooldown, leaving item-use poses unchanged.
	if Cs.s(name).begins_with("combat_"):
		t *= GameSim.WEAPON_ATTACK_SPEED
	return [name, t, state.aim] if t < self.anim_length(skin, name) else null

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
	var sequence: int = -1
	var pose_start: float = -1.0
	var pose: String = ""
	var aim: float = 0.0
	var active: bool = false
	var start: float = 0.0
	var seen: float = 0.0
	var any: bool = false
