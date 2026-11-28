class_name LandmarkDetailsView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.LandmarkDetails.cs.
# Owner: Vu Duc Viet Anh. Ground colour and quiet wildlife distinguish Atlas locations at gameplay scale.
# Visuals only: no extra lights, loot, damage or changes to the navigation mesh.
const landmark_ground_budget_ms: float = 2.0
const landmark_ground_idle_budget_ms: float = 5.0
const landmark_ground_urgent_budget_ms: float = 12.0
const lookahead_margin_px: float = 20.0 * Main.T
var landmark_soil_world
var landmark_soil_cache = {}
var landmark_soil_jobs = []
var profile_landmarks: bool = OS.get_cmdline_user_args().find("--profile-landmarks") >= 0
var last_view: Rect2 = Rect2()
var has_view: bool = false

var has_pending_landmark_ground: bool:
	get:
		return landmark_soil_jobs.size() > 0

var landmark_ground_worst_slice_ms: float = 0.0

var main: Main

func _init(host: Main) -> void:
	main = host

func _ensure_world(w) -> void:
	if w == null or is_same(landmark_soil_world, w):
		return
	landmark_soil_cache.clear()
	landmark_soil_jobs.clear()
	landmark_soil_world = w
	var focus: Vector2 = Vector2(main.local_pos) if main != null else Vector2.ZERO
	for surface in WorldGeometry.landmark_soils:
		var id: int = surface.id
		if not w.lm_at.has(id):
			continue
		var rx: float = surface.rx
		var ry: float = surface.ry
		var c: Vector2 = w.soil_centre(surface)
		var origin: Vector2 = (c - Vector2(rx * 32.0, ry * 32.0)).floor()
		var bottom: int = maxi(int(ry * 32.0), 112) if id == 5 or id == 7 else int(ry * 32.0)
		var soil := Color(surface.hex)
		var job := LandmarkSoilJob.new()
		job.id = id
		job.centre = c
		job.rx = rx
		job.ry = ry
		job.soil = soil
		job.soil_light = soil.lightened(0.035)
		job.soil_dark = soil.darkened(0.035)
		job.fleck = Color(soil.lightened(0.15), 0.7)
		job.surface = surface
		job.min_x = -int(rx * 32.0)
		job.x = job.min_x
		job.max_x = int(rx * 32.0)
		job.y = -int(ry * 32.0)
		job.max_y = int(ry * 32.0)
		job.area = Rect2(origin, Vector2(int(rx * 64.0) + 8, bottom + int(ry * 32.0) + 8))
		landmark_soil_cache[id] = job
		landmark_soil_jobs.push_back(job)
	# Bake nearest-to-base / player landmarks first so ground is ready long before arrival.
	landmark_soil_jobs.sort_custom(func(a, b): return a.centre.distance_squared_to(focus) < b.centre.distance_squared_to(focus))

func _prioritize_jobs(view: Rect2) -> void:
	if landmark_soil_jobs.is_empty():
		return
	var lookahead: Rect2 = view.grow(lookahead_margin_px)
	var view_centre: Vector2 = view.get_center()
	var best_idx: int = -1
	var best_urgent: bool = false
	var best_dist: float = INF
	for i in range(landmark_soil_jobs.size()):
		var job: LandmarkSoilJob = landmark_soil_jobs[i]
		var on_screen: bool = job.area.intersects(view)
		job.urgent = on_screen
		if on_screen or job.area.intersects(lookahead):
			var d: float = job.centre.distance_squared_to(view_centre)
			if best_idx == -1 or (on_screen and not best_urgent) or (on_screen == best_urgent and d < best_dist):
				best_idx = i
				best_urgent = on_screen
				best_dist = d
	if best_idx > 0:
		var promoted = landmark_soil_jobs[best_idx]
		landmark_soil_jobs.remove_at(best_idx)
		landmark_soil_jobs.push_front(promoted)

func draw_landmark_soils(w, view: Rect2) -> void:
	_ensure_world(w)
	last_view = view
	has_view = true
	if landmark_soil_jobs.size() > 0:
		_prioritize_jobs(view)
	for job in landmark_soil_cache.values():
		if job.texture != null and job.area.intersects(view):
			main.draw_texture_rect(job.texture, job.area, false)

# All Godot image/texture operations remain on the main thread, with a small CPU budget per rendered frame.
func tick_landmark_ground() -> void:
	if main != null and main.geometry != null:
		_ensure_world(main.geometry)
	if landmark_soil_jobs.is_empty():
		return
	if has_view:
		_prioritize_jobs(last_view)
	var ph: String = str(main.snap.get("ph", "")) if main != null else ""
	var in_game: bool = ph in ["day", "dusk", "night", "result"]
	var started: int = Time.get_ticks_usec()
	while landmark_soil_jobs.size() > 0:
		var job: LandmarkSoilJob = landmark_soil_jobs.front()
		var budget_ms: float = landmark_ground_urgent_budget_ms if job.urgent else (landmark_ground_budget_ms if in_game else landmark_ground_idle_budget_ms)
		var limit: int = started + int(budget_ms * 1000.0)
		var job_started: int = Time.get_ticks_usec()
		if job.mask == null:
			job.mask = LandmarkGroundMask.new(landmark_soil_world, job.area, 8.0, false)
		if job.image == null:
			job.image = Image.create_empty(int(job.area.size.x), int(job.area.size.y), false, Image.FORMAT_RGBA8)
		var is_cave: bool = job.id == 16
		var cx: float = job.centre.x
		var cy: float = job.centre.y
		var ox: float = job.area.position.x
		var oy: float = job.area.position.y
		var min_x: int = job.min_x
		var max_x: int = job.max_x
		var max_y: int = job.max_y
		var surface = job.surface
		var mask: LandmarkGroundMask = job.mask
		var img: Image = job.image
		var soil: Color = job.soil
		var soil_light: Color = job.soil_light
		var soil_dark: Color = job.soil_dark
		var fleck: Color = job.fleck
		var fleck_a: float = fleck.a
		var fast_mask: bool = mask.no_river and mask.all_inland and mask.floors.is_empty() and mask.ponds.is_empty()
		var cave_poly := PackedVector2Array()
		var cave_box := Rect2()
		var cave_ent_x: float = 0.0
		var cave_inv_depth: float = 1.0 / (24.0 * WorldGeometry.TL)
		if is_cave:
			if job.cave_poly.is_empty():
				job.cave_poly = PackedVector2Array(landmark_soil_world.cave_floor)
				if job.cave_poly.size() > 0:
					var cb := Rect2(job.cave_poly[0], Vector2.ZERO)
					for pt in job.cave_poly:
						cb = cb.expand(pt)
					job.cave_box = cb
			cave_poly = job.cave_poly
			cave_box = job.cave_box
			cave_ent_x = landmark_soil_world.cave_entrance.x
		var x: int = job.x
		var y: int = job.y
		while y <= max_y:
			var py_f: float = roundf(cy + float(y))
			var py_i: int = int(py_f)
			var dy_off: float = py_f - cy
			var iy: int = int(roundf(py_f - oy))
			var py_hash: int = py_i * 668265263
			while x <= max_x:
				var px_f: float = roundf(cx + float(x))
				var coverage: float = WorldLandmarkDetails.soil_coverage(surface, Vector2(px_f - cx, dy_off))
				if coverage > 0.0:
					var p := Vector2(px_f, py_f)
					if fast_mask or mask.can_paint(p, 3.0, true, false):
						var px_i: int = int(px_f)
						var noise: float = float((((px_i * 374761393 + py_hash) & 0xFFFFFFFF) ^ 0x5bd1e995) % 1000) * 0.001
						var ix: int = int(roundf(px_f - ox))
						var patch: Color
						var base: Color
						if is_cave:
							if cave_box.has_point(p) and Geometry2D.is_point_in_polygon(p, cave_poly):
								var depth_t: float = clampf((cave_ent_x - px_f) * cave_inv_depth, 0.0, 1.0)
								base = WorldCave.CAVE_FLOOR_NEAR.lerp(WorldCave.CAVE_FLOOR_DEEP, depth_t)
								patch = base.lightened(0.035) if noise > 0.72 else base.darkened(0.035) if noise < 0.22 else base
							else:
								base = soil
								patch = soil_light if noise > 0.72 else soil_dark if noise < 0.22 else soil
						else:
							patch = soil_light if noise > 0.72 else soil_dark if noise < 0.22 else soil
						patch.a = coverage
						img.fill_rect(Rect2i(ix, iy, 4, 4), patch)
						if noise > 0.92:
							img.fill_rect(Rect2i(ix + 1, iy + 2, 2, 1), Color(fleck.r, fleck.g, fleck.b, fleck_a * coverage))
						if is_cave and noise < 0.025:
							img.fill_rect(Rect2i(ix, iy, 4, 1), Color(base.darkened(0.18), coverage))
				x += 4
			x = min_x
			y += 4
			if Time.get_ticks_usec() >= limit:
				break
		job.x = x
		job.y = y
		var finished: bool = y > max_y
		if finished:
			job.texture = ImageTexture.create_from_image(img)
			job.image = null
			job.mask = null
			job.cave_poly = PackedVector2Array()
			job.urgent = false
			landmark_soil_jobs.pop_front()
		var job_elapsed: int = Time.get_ticks_usec() - job_started
		job.work_ticks += job_elapsed
		job.slices += 1
		if profile_landmarks and finished:
			print("LANDMARK BAKE %02d: %.2f ms across %s frames; worst slice %.2f ms" % [job.id, job.work_ticks * 1000.0 / 1000000.0, job.slices, maxf(landmark_ground_worst_slice_ms, (Time.get_ticks_usec() - started) * 1000.0 / 1000000.0)])
		if not finished or Time.get_ticks_usec() >= limit:
			break
	var elapsed: int = Time.get_ticks_usec() - started
	landmark_ground_worst_slice_ms = maxf(landmark_ground_worst_slice_ms, elapsed * 1000.0 / 1000000.0)

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
	var soil_light: Color = Color(0, 0, 0, 0)
	var soil_dark: Color = Color(0, 0, 0, 0)
	var fleck: Color = Color(0, 0, 0, 0)
	var image
	var texture
	var mask
	var cave_poly: PackedVector2Array = PackedVector2Array()
	var cave_box: Rect2 = Rect2()
	var surface = WorldGeometry.LandmarkSoil.new()
	var urgent: bool = false
	var work_ticks: int = 0
	var slices: int = 0
