class_name BasePropsView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.BaseProps.cs.
# Owner: Vu Duc Viet Anh. The shared storage chest in the base (BAL-18, GameSim.STORAGE_POS): its lid opens when
# anyone walks up to it (in reach to use it) and shuts again when they leave. art/props/chest.png holds the frames
# side by side, closed to wide open (drawn by tools/PixelProps.cs); props.json gives the anchor of one frame.
const CHEST_FRAMES: int = 4
# lid speed: full swing in 1 / this seconds
const CHEST_OPEN_SPEED: float = 5.0
const CHEST_SHUT_SPEED: float = 3.5
# 0 shut, 1 wide open
var chest_open: float = 0.0
var chest_clock: float = 0.0
# The lighthouse is tall (it stands above the roof, src/world/view/base_fog.gd): while you stand behind it, it
# fades so you can see yourself.
var lighthouse_fade: float = 0.0
var lighthouse_clock: float = 0.0

# constants shared with Main
const LIGHTHOUSE = Main.LIGHTHOUSE
const LIGHTHOUSE_SCALE = Main.LIGHTHOUSE_SCALE

var main: Main

func _init(host: Main) -> void:
	main = host

func lighthouse_tint() -> Color:
	var now: float = float(main.clock)
	var dt: float = clampf(now - lighthouse_clock, 0.0, 0.1)
	lighthouse_clock = now
	var behind: bool = false
	var p = main.prop.get("lighthouse")
	if p != null:
		var size: Vector2 = p[0].get_size() * float(LIGHTHOUSE_SCALE)
		var anchor: Vector2 = Vector2(p[1]) * float(LIGHTHOUSE_SCALE)
		var body: Rect2 = Rect2(Vector2(LIGHTHOUSE) - anchor, size)
		var me: Vector2 = Vector2(main.local_pos)
		# your sprite (about a tile wide, 1.3 tiles tall) overlaps the tower and your feet are behind its foot
		behind = me.y < Vector2(LIGHTHOUSE).y and body.intersects(Rect2(me - Vector2(12, 40), Vector2(24, 40)))
	lighthouse_fade = move_toward(lighthouse_fade, 1.0 if behind else 0.0, dt * 4.0)
	return Color(1, 1, 1, 1.0 - 0.6 * lighthouse_fade)

# call once per frame while building the world items
func tick_chest() -> void:
	var now: float = float(main.clock)
	var dt: float = clampf(now - chest_clock, 0.0, 0.1)
	chest_clock = now
	var near: bool = false
	for id in main.snap.get("ps", {}):
		var p = main.snap.ps[id]
		if p[5] != 0:
			continue
		var pos: Vector2 = Vector2(main.local_pos if id == main.my_id else main.shown_p.get(id, p[2]))
		if SimWorld.near_storage(pos):
			near = true
			break
	chest_open = move_toward(chest_open, 1.0 if near else 0.0, dt * (CHEST_OPEN_SPEED if near else CHEST_SHUT_SPEED))

func draw_chest(pos: Vector2) -> void:
	var p = main.prop.get("chest")
	if p == null:
		return
	# Gd.Load hands back a wrapped object
	var tex = p[0]
	var anchor: Vector2 = p[1]
	var w: float = tex.get_width() / CHEST_FRAMES
	var h: float = tex.get_height()
	var f: int = clampi(roundi(chest_open * (CHEST_FRAMES - 1)), 0, CHEST_FRAMES - 1)
	main.draw_texture_rect_region(tex, Rect2((pos - anchor).round(), Vector2(w, h)), Rect2(f * w, 0, w, h))
	# wide open: a glint rises from inside now and then
	if f == CHEST_FRAMES - 1:
		var mouth = pos + Vector2(0, -15)
		var spark: float = fposmod(float(main.clock) * 0.9, 1.0)
		if spark < 0.35:
			var sp = mouth + Vector2(lerpf(-6.0, 6.0, fposmod(floorf(float(main.clock) * 0.9) * 0.37, 1.0)), -4.0 - spark * 18.0)
			var sc = Color(1.0, 0.95, 0.7, 1.0 - spark / 0.35)
			main.draw_rect(Rect2(sp.round(), Vector2(1, 1)), sc)
			main.draw_rect(Rect2(sp.round() + Vector2(-1, 0), Vector2(3, 1)), Color(sc, sc.a * 0.5))
			main.draw_rect(Rect2(sp.round() + Vector2(0, -1), Vector2(1, 3)), Color(sc, sc.a * 0.5))
