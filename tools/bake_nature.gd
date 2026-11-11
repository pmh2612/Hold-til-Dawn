extends Node
## Bakes 3D models into pixel-art sprites seen from the game's 3/4 camera, matching the 32x32 characters:
## 1 px = 1 game px, hard edges, banded colours and the same 1 px dark outline (GDD style guide).
## Not part of the game. Run it in a throwaway Godot project whose res://models/ holds the
## Quaternius "Stylized Nature MegaKit" glTF files (CC0), with this script on the main scene's root:
##   godot --path <bake project> -- --out=D:/Hold-til-Dawn/art/nature
## Writes <Model>_<k>.png (k = turned variant) plus index.json: {name: [anchor_x, anchor_y]}, the pixel
## under the model's origin (its foot). The game draws each sprite with that pixel on the object's position.
## Each big sprite carries its own cast shadow: a second pass renders only the shadow on a ground plane.
## For smooth shadows give the bake project: rendering/lights_and_shadows/directional_shadow/size=4096
## and rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality=3.

const PPU := 32.0  # pixels per tile: one sprite pixel is one game pixel, like the 32x32 characters
const INK := Color("141019")  # outline, the same ink as the characters
const PITCH := 50.0  # camera looks down 50 degrees (the "3/4" angle)
const YAWS := [-30.0, 60.0, 150.0]  # three turns per model so a forest does not repeat
const PAD := 6
const SHADOW_A := 0.42  # darkness of the cast shadow (one flat tone, hard edge)
const SHADOW_COL := Color(0.04, 0.06, 0.1)

# Model scale in tiles. Quaternius trees are ~6 m tall; at x0.55 a tree is drawn ~3 tiles tall, about 3.5-4x a 32 px character.
const SCALE := {"Tree": 0.55, "TwistedTree": 0.27, "Pine": 0.55, "Rock_Medium": 0.6, "Bush": 0.8, "Plant": 0.7,
	"Fern": 0.75, "Mushroom": 0.8, "Flower": 0.6, "Grass": 0.6, "Clover": 0.7, "Pebble": 0.7, "RockPath": 0.7, "Petal": 0.7}
const FLAT := ["Grass", "Clover", "Flower", "Pebble", "Petal", "RockPath"]  # ground scatter: one turn, no shadow

var vp := SubViewport.new()
var cam := Camera3D.new()
var sun := DirectionalLight3D.new()
var env := Environment.new()
var holder := Node3D.new()
var ground := MeshInstance3D.new()


func _ready() -> void:
	var out := "res://baked"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	for f in DirAccess.get_files_at(out):
		if f.ends_with(".png"):
			DirAccess.remove_absolute(out.path_join(f))

	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED  # hard pixel edges
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	sun.rotation_degrees = Vector3(-50, -40, 0)  # light from the upper left, same for every sprite
	sun.shadow_enabled = true  # default PSSM mode: SHADOW_ORTHOGONAL casts nothing under an orthogonal camera
	sun.directional_shadow_max_distance = 300.0
	sun.shadow_blur = 0.8
	vp.add_child(sun)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.rotation_degrees = Vector3(-PITCH, 0, 0)
	vp.add_child(cam)
	vp.add_child(holder)
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color.WHITE
	gm.roughness = 1.0
	gm.metallic_specular = 0.0
	ground.material_override = gm
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp.add_child(ground)

	var index := {}
	var names := []
	for f in DirAccess.get_files_at("res://models"):
		if f.ends_with(".gltf"):
			names.append(f.get_basename())
	names.sort()
	for n: String in names:
		var flat := FLAT.any(func(k): return k in n)
		var yaws: Array = [YAWS[0]] if flat else YAWS
		for k in yaws.size():
			var anchor: Vector2 = await _bake(n, yaws[k], not flat, out.path_join("%s_%d.png" % [n, k]))
			index["%s_%d" % [n, k]] = [anchor.x, anchor.y]
		print("baked ", n)
	var fa := FileAccess.open(out.path_join("index.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify(index, "\t", true))
	fa.close()
	get_tree().quit()


func _bake(n: String, yaw: float, shadow: bool, path: String) -> Vector2:
	for c in holder.get_children():
		c.free()
	var inst: Node3D = (load("res://models/%s.gltf" % n) as PackedScene).instantiate()
	var s := 0.6
	for key: String in SCALE:
		if key in n:
			s = SCALE[key]
	inst.scale = Vector3.ONE * s
	inst.rotation_degrees.y = yaw
	holder.add_child(inst)
	var meshes := inst.find_children("*", "MeshInstance3D", true, false)

	# fit the camera to the model and to where its shadow falls on the ground
	var right := cam.global_transform.basis.x
	var up := cam.global_transform.basis.y
	var back := cam.global_transform.basis.z
	var d := -sun.global_transform.basis.z  # direction the light travels
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for m in meshes:
		var mi := m as MeshInstance3D
		var box := mi.global_transform * mi.get_aabb()
		for i in 8:
			var c := box.get_endpoint(i)
			var pts := [c]
			if shadow and c.y > 0:
				pts.append(c - d * (c.y / d.y))  # where this corner's shadow lands
			for p: Vector3 in pts:
				var q := Vector2(p.dot(right), p.dot(up))
				lo = lo.min(q)
				hi = hi.max(q)
	var size := Vector2i(ceili((hi.x - lo.x) * PPU) + PAD * 2, ceili((hi.y - lo.y) * PPU) + PAD * 2)
	print("  %s yaw %d -> %s" % [n, yaw, size])
	vp.size = size
	cam.size = size.y / PPU
	var mid := (lo + hi) / 2.0
	cam.position = right * mid.x + up * mid.y + back * 20.0

	# pass 1: the model itself, contrasty light, self-shadowed, no ground
	ground.visible = false
	for m in meshes:
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	env.ambient_light_color = Color(0.62, 0.7, 0.85)  # cool sky fill, so the shaded side reads blue-dark
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.7
	var col := await _grab()
	_pixelate(col, shadow)
	if not shadow:
		col.save_png(path)
		return _anchor(size, mid)

	# pass 2: only the shadow, on a white ground plane lit by the sun alone
	ground.visible = true
	for m in meshes:
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	env.ambient_light_energy = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	sun.light_color = Color.WHITE
	sun.light_energy = 1.0
	var sh := await _grab()
	sh.convert(Image.FORMAT_L8)
	var lum := sh.get_data()
	var lit := 1
	for v in lum:
		lit = maxi(lit, v)
	var px := PackedByteArray()
	px.resize(size.x * size.y * 4)
	for i in lum.size():
		var a := SHADOW_A if 1.0 - float(lum[i]) / lit > 0.2 else 0.0  # hard-edged shadow
		px[i * 4] = int(SHADOW_COL.r8)
		px[i * 4 + 1] = int(SHADOW_COL.g8)
		px[i * 4 + 2] = int(SHADOW_COL.b8)
		px[i * 4 + 3] = int(a * 255.0)
	var out := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, px)
	out.blend_rect(col, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	out.save_png(path)
	return _anchor(size, mid)


func _grab() -> Image:
	for i in 4:
		await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


func _anchor(size: Vector2i, mid: Vector2) -> Vector2:
	# pixel under the model origin (world 0,0,0)
	return Vector2(size.x / 2.0 - mid.x * PPU, size.y / 2.0 + mid.y * PPU)


func _pixelate(img: Image, outline: bool) -> void:
	## Pixel-art finish: alpha is on or off, colours fall into bands, and big sprites get a 1 px dark outline.
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				img.set_pixel(x, y, Color.from_hsv(snappedf(c.h, 1.0 / 48.0), snappedf(c.s, 0.12), snappedf(c.v, 0.09)))
	if not outline:
		return
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and src.get_pixel(q.x, q.y).a > 0.0:
					img.set_pixel(x, y, INK)
					break
