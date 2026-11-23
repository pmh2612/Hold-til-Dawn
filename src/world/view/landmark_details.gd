class_name LandmarkDetailsView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.LandmarkDetails.cs.
# Owner: Vu Duc Viet Anh. Ground colour and quiet wildlife distinguish Atlas locations at gameplay scale.
# Visuals only: no extra lights, loot, damage or changes to the navigation mesh.
const landmark_ground_budget_ms: float = 1.0
var landmark_soil_world
var landmark_soil_cache = {}
var landmark_soil_jobs = []
var profile_landmarks: bool = OS.get_cmdline_user_args().find("--profile-landmarks") >= 0

var has_pending_landmark_ground: bool:
	get:
		return landmark_soil_jobs.size() > 0

var landmark_ground_worst_slice_ms: float = 0.0

var main: Main

func _init(host: Main) -> void:
	main = host

func draw_landmark_soils(w, view: Rect2) -> void:
	if not is_same(landmark_soil_world, w):
		for job in landmark_soil_cache.values():
			pass
			pass
		landmark_soil_cache.clear()
		landmark_soil_jobs.clear()
		landmark_soil_world = w
	for surface in WorldGeometry.landmark_soils:
		var _d1 = surface
		var id = _d1.id
		var rx = _d1.rx
		var ry = _d1.ry
		var hex_ = _d1.hex
		if not w.lm_at.has(id):
			continue
		var c: Vector2 = w.soil_centre(surface)
		if not Cs.has_point(view.grow(rx * 32), c):
			continue
		var job = landmark_soil_cache.get(id, null)
		if not landmark_soil_cache.has(id):
			# Queue work while the location is still in the camera's off-screen culling margin.
			# Never scan terrain, paint an image or upload a texture from _Draw().
			var origin: Vector2 = (c - Vector2(rx * 32, ry * 32)).floor()
			var bottom: int = maxi(int(ry * 32), 112) if id == 5 or id == 7 else int(ry * 32)
			job = Cs.init(LandmarkSoilJob.new(), {"id": id, "centre": c, "rx": rx, "ry": ry, "soil": Color(hex_), "surface": surface, "fleck": Color(Color(hex_).lightened(0.15), 0.7), "min_x": -int(rx * 32), "x": -int(rx * 32), "max_x": int(rx * 32), "y": -int(ry * 32), "max_y": int(ry * 32), "area": Rect2(origin, Vector2(int(rx * 64) + 8, bottom + int(ry * 32) + 8))})
			landmark_soil_cache[id] = job
			landmark_soil_jobs.push_back(job)
		if job.texture != null:
			main.draw_texture_rect(job.texture, job.area, false)

# All Godot image/texture operations remain on the main thread, with a small CPU budget per rendered frame.
func tick_landmark_ground() -> void:
	if landmark_soil_jobs.size() == 0:
		return
	var started: int = Time.get_ticks_usec()
	var limit: int = started + int(1000000 * landmark_ground_budget_ms / 1000)
	var job = landmark_soil_jobs.front()
	if job.mask == null: job.mask = LandmarkGroundMask.new(landmark_soil_world, job.area)
	if job.image == null: job.image = Image.create_empty(int(job.area.size.x), int(job.area.size.y), false, Image.FORMAT_RGBA8)
	while true:
		if job.y <= job.max_y:
			paint_landmark_cell(job)
			job.x += 4
			if job.x > job.max_x:
				job.x = job.min_x
				job.y += 4
		else:
			job.texture = ImageTexture.create_from_image(job.image)
			pass
			job.image = null
			landmark_soil_jobs.pop_front()
			break
		if not (Time.get_ticks_usec() < limit): break
	var elapsed: int = Time.get_ticks_usec() - started
	job.work_ticks += elapsed
	job.slices += 1
	landmark_ground_worst_slice_ms = maxf(landmark_ground_worst_slice_ms, elapsed * 1000.0 / 1000000)
	if profile_landmarks and job.texture != null:
		print("LANDMARK BAKE %02d: %.2f ms across %s frames; worst slice %.2f ms" % [job.id, job.work_ticks * 1000.0 / 1000000, job.slices, landmark_ground_worst_slice_ms])

func paint_landmark_cell(job) -> void:
	var p: Vector2 = (job.centre + Vector2(job.x, job.y)).round()
	var coverage: float = WorldLandmarkDetails.soil_coverage(job.surface, p - job.centre)
	var noise: float = LandmarkView.h01(int(p.x), int(p.y))
	if coverage <= 0 or not job.mask.can_paint(p, 3, true, false):
		return
	var base: Color = landmark_soil_world.cave_ground_colour(p) if job.id == 16 else job.soil
	var patch: Color = base.lightened(0.035) if noise > 0.72 else base.darkened(0.035) if noise < 0.22 else base
	patch.a = coverage
	fill_landmark(job, p, Vector2i(4, 4), patch)
	if noise > 0.92:
		fill_landmark(job, p + Vector2(1, 2), Vector2i(2, 1), Color(job.fleck, job.fleck.a * coverage))
	if job.id == 16 and noise < 0.025:
		fill_landmark(job, p, Vector2i(4, 1), Color(base.darkened(0.18), coverage))

static func fill_landmark(job, p: Vector2, size: Vector2i, colour: Color) -> void:
	job.image.fill_rect(Rect2i(Vector2i((p - job.area.position).round()), size), colour)

func draw_landmark_life(w, view: Rect2, time: float) -> void:
	var night: bool = main.snap.get("ph", "day") == "night"
	for id in [4, 8, 15, 18]:
		var c = w.lm_at.get(id, Vector2.ZERO)
		if not w.lm_at.has(id) or not Cs.has_point(view.grow(200), c):
			continue
		if id == 8:
			c = w.swamp_centre
		if id == 15 and w.ponds.size() > 0:
			c = w.ponds[0].centre
		for i in range(12 if id == 8 else 6):
			var a_: float = time * 0.24 + i * 2.4
			var p: Vector2 = (c + Vector2(sin(a_) * (45 + i * 7), cos(a_ * 1.3) * (28 + i * 5))).round()
			if not view.has_point(p):
				continue
			if night or id == 8:
				var alpha: float = 0.25 + 0.65 * pow(0.5 + 0.5 * sin(time * 1.8 + i * 1.9), 3)
				# HDR points remain visible through the world's night tint, without casting gameplay light.
				var glow: Color = Color(4.2, 3.8, 1.5, alpha) if night else Color("D4DE87", alpha)
				main.draw_rect(Rect2(p - Vector2.ONE * 2, Vector2(5, 5)), Color(glow, alpha * 0.07))
				main.draw_rect(Rect2(p, Vector2.ONE), glow)
			else:
				var wing: int = 2 if sin(time * 10 + i) > 0 else 1
				var col: Color = Color("9DD5D5" if id == 15 else "E3BE74" if i % 2 == 0 else "DAB4D9", 0.85)
				main.draw_rect(Rect2(p + Vector2(-wing, -1), Vector2(wing, 2)), col)
				main.draw_rect(Rect2(p + Vector2(1, -1), Vector2(wing, 2)), col)
				main.draw_rect(Rect2(p, Vector2(1, 2)), Color("4A4B34"))

class LandmarkSoilJob:
	var id: int = 0
	var x: int = 0
	var y: int = 0
	var min_x: int = 0
	var max_x: int = 0
	var max_y: int = 0
	var rx: float = 0.0
	var ry: float = 0.0
	var centre: Vector2 = Vector2.ZERO
	var area: Rect2 = Rect2()
	var soil: Color = Color(0, 0, 0, 0)
	var fleck: Color = Color(0, 0, 0, 0)
	var image
	var texture
	var mask
	var surface = WorldGeometry.LandmarkSoil.new()
	var work_ticks: int = 0
	var slices: int = 0
