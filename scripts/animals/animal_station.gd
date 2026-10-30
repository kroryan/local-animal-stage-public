extends Node3D

const ChartKit = preload("res://scripts/ui/chart_kit.gd")

var species: Dictionary = {}
var species_id := ""
var station_color := Color("79d5c1")
var data_root := "res://neural_assets"
var animal_model: Node3D
var brain_root: Node3D
var brain_visual_root: Node3D
var monitor_chart: TauPlot
var monitor_viewport: SubViewport
var action_label: Label3D
var activity_label: Label3D
var _brain: ConnectomeBrain
var _neuron_positions := PackedVector3Array()
var _visible_neurons: Array[int] = []
var _neuron_instances: Dictionary = {}
var _neuron_radii := PackedFloat32Array()
var _neuron_activity: Dictionary = {}
var _edge_visuals: Dictionary = {}
var _base_colors: Dictionary = {}
var _neuron_cloud: MultiMeshInstance3D
var _active_mesh: MeshInstance3D
var _motor_bias := 0.0
var _activity := 0.0
var _base_rotation := 0.0
var _base_y := 0.0


func configure(row: Dictionary, x: float, color: Color, resource_root: String) -> void:
	species = row
	species_id = str(row.get("id", ""))
	station_color = color
	data_root = resource_root
	position = Vector3(x, 0.0, 0.0)
	_build_station()


func _process(delta: float) -> void:
	if animal_model == null or not is_instance_valid(animal_model):
		return
	var sway := sin(Time.get_ticks_msec() * 0.0012 + float(species_id.hash() % 17)) * 0.025
	animal_model.rotation.y = _base_rotation + sway + _motor_bias * _activity * 0.12
	animal_model.position.y = _base_y + absf(sin(Time.get_ticks_msec() * 0.004 + float(species_id.hash() % 9))) * _activity * 0.025
	if brain_visual_root != null and is_instance_valid(brain_visual_root):
		brain_visual_root.rotation.y += delta * 0.12
		_decay_neuron_activity(delta)


func _build_station() -> void:
	var housing := "tank" if species_id == "zebrafish_larva" else "dish" if species_id in ["c_elegans_herm", "c_elegans_male", "ciona_larva", "drosophila_larva"] else "bench"
	var metal := _material(Color("263438"), 0.62, 0.34)
	var wood := _material(Color("3c3025"), 0.16, 0.62)
	var top := 0.78
	_add_box(Vector3(1.85, 0.06, 0.98), Vector3(0.1, top, 0.0), wood)
	for leg: Vector2 in [Vector2(-0.72, -0.36), Vector2(0.92, -0.36), Vector2(-0.72, 0.38), Vector2(0.92, 0.38)]:
		_add_box(Vector3(0.055, top, 0.055), Vector3(0.1 + leg.x, top * 0.5, leg.y), metal)
	if housing == "tank":
		_add_box(Vector3(0.88, 0.48, 0.58), Vector3(0.46, top + 0.25, 0.12), _material(Color(0.34, 0.62, 0.68, 0.2), 0.05, 0.1, true))
		_add_box(Vector3(0.82, 0.28, 0.52), Vector3(0.46, top + 0.16, 0.12), _material(Color(0.12, 0.36, 0.45, 0.45), 0.0, 0.2, true))
	elif housing == "dish":
		_add_cylinder(0.34, 0.34, 0.035, Vector3(0.48, top + 0.025, 0.12), _material(Color(0.68, 0.84, 0.82, 0.22), 0.0, 0.12, true))
		_add_cylinder(0.30, 0.30, 0.015, Vector3(0.48, top + 0.045, 0.12), _material(Color("56634e"), 0.0, 0.9))
	_build_monitor(top, metal)
	_build_animal(top)
	_build_brain_rig(top, metal)
	_build_nameplate()


func _build_monitor(top: float, metal: StandardMaterial3D) -> void:
	_add_box(Vector3(1.05, 0.64, 0.045), Vector3(0.24, top + 0.53, -0.39), metal)
	monitor_viewport = SubViewport.new()
	monitor_viewport.size = Vector2i(480, 300)
	monitor_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	monitor_viewport.transparent_bg = false
	add_child(monitor_viewport)
	var panel := ColorRect.new()
	panel.color = Color("101719")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	monitor_viewport.add_child(panel)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 3)
	panel.add_child(layout)
	var header := Label.new()
	header.text = "ANIMAL STAGE  /  %s" % str(species.get("name", species_id)).to_upper()
	header.add_theme_color_override("font_color", station_color)
	header.add_theme_font_size_override("font_size", 23)
	layout.add_child(header)
	var readout := Label.new()
	readout.name = "BrainReadout"
	readout.text = "BRAIN ACTIVITY · awaiting input"
	readout.add_theme_color_override("font_color", Color("d7e0dc"))
	readout.add_theme_font_size_override("font_size", 14)
	layout.add_child(readout)
	# Leave room for the monitor heading and activity readout inside this
	# 300px SubViewport. An oversized TauPlot gets clipped before its plot area.
	monitor_chart = ChartKit.create("NEURAL ACTIVITY", 205)
	monitor_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ChartKit.render(monitor_chart, {"kind": "message", "title": "NEURAL ACTIVITY", "message": "Attach a brain stream to display activity here."})
	layout.add_child(monitor_chart)
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.99, 0.59)
	quad.mesh = mesh
	quad.position = Vector3(0.24, top + 0.53, -0.365)
	var screen_material := StandardMaterial3D.new()
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_material.albedo_texture = monitor_viewport.get_texture()
	screen_material.emission_enabled = true
	screen_material.emission_texture = monitor_viewport.get_texture()
	screen_material.emission_energy_multiplier = 0.9
	screen_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material_override = screen_material
	add_child(quad)
	monitor_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	action_label = Label3D.new()
	action_label.text = "CONNECTOME PILOT · READY"
	action_label.position = Vector3(0.0, top - 0.12, 0.53)
	action_label.font_size = 16
	action_label.modulate = Color("dce3dc")
	action_label.pixel_size = 0.0027
	add_child(action_label)


func _build_animal(top: float) -> void:
	var resources: Dictionary = species.get("resources", {})
	var model_rel := str(resources.get("model", "models/%s.glb" % species_id))
	var model_path := "res://neural_assets/" + model_rel
	var packed := load(model_path) as PackedScene if ResourceLoader.exists(model_path) else null
	if packed != null:
		animal_model = packed.instantiate() as Node3D
	if animal_model == null and not data_root.begins_with("res://"):
		var external_model_path := data_root.path_join(model_rel)
		if FileAccess.file_exists(external_model_path):
			var gltf := GLTFDocument.new()
			var gltf_state := GLTFState.new()
			if gltf.append_from_file(external_model_path, gltf_state, 0, external_model_path.get_base_dir()) == OK:
				animal_model = gltf.generate_scene(gltf_state) as Node3D
	if animal_model == null:
		animal_model = Node3D.new()
		var fallback := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.46
		fallback.mesh = sphere
		fallback.material_override = _material(station_color, 0.12, 0.4)
		animal_model.add_child(fallback)
	add_child(animal_model)
	var target_size := 0.82 if species_id.begins_with("c_elegans") else 1.02 if species_id.begins_with("drosophila") or species_id == "zebrafish_larva" else 0.9
	var model_height := _fit_model(animal_model, target_size)
	var support_y := top + 0.03
	if species_id in ["c_elegans_herm", "c_elegans_male", "ciona_larva", "drosophila_larva"]:
		support_y = top + 0.0525
	# GLB origins differ. Fit around their geometric center, then place the
	# actual lower bound on the support surface so models do not sink into it.
	animal_model.position += Vector3(0.48, support_y + model_height * 0.5 + 0.015, 0.13)
	_base_y = animal_model.position.y
	_play_idle_animation(animal_model)
	_add_box(Vector3(0.42, 0.018, 0.26), Vector3(0.48, top + 0.009, 0.13), _material(Color("171d20"), 0.08, 0.4))


func _build_brain_rig(top: float, metal: StandardMaterial3D) -> void:
	_add_cylinder(0.045, 0.055, 0.55, Vector3(-0.58, top + 0.29, 0.12), metal)
	_add_cylinder(0.24, 0.25, 0.035, Vector3(-0.58, top + 0.57, 0.12), _material(Color("1b2428"), 0.48, 0.38))
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.205
	torus.outer_radius = 0.218
	ring.mesh = torus
	ring.position = Vector3(-0.58, top + 0.595, 0.12)
	ring.material_override = _material(station_color, 0.0, 0.28, true)
	add_child(ring)
	brain_root = Node3D.new()
	brain_root.position = Vector3(-0.58, top + 0.84, 0.12)
	add_child(brain_root)
	brain_visual_root = Node3D.new()
	brain_visual_root.name = "ConnectomePoints"
	brain_root.add_child(brain_visual_root)
	var title := Label3D.new()
	title.name = "BrainLabel"
	title.text = "CONNECTOME · READY"
	title.position = Vector3(-0.28, 0.48, 0.0)
	title.font_size = 15
	title.pixel_size = 0.0028
	title.modulate = station_color
	brain_root.add_child(title)
	activity_label = Label3D.new()
	activity_label.name = "ActivityLabel"
	activity_label.text = "real synapses · waiting"
	activity_label.position = Vector3(-0.32, -0.45, 0.0)
	activity_label.font_size = 11
	activity_label.pixel_size = 0.0024
	activity_label.modulate = Color("c4d0ca")
	brain_root.add_child(activity_label)


func _build_nameplate() -> void:
	var title := Label3D.new()
	title.text = str(species.get("name", species_id)).to_upper()
	title.position = Vector3(0.02, 0.56, 0.63)
	title.font_size = 17
	title.pixel_size = 0.003
	title.modulate = station_color
	add_child(title)


func set_connectome(brain: ConnectomeBrain, root: String = "") -> void:
	if _brain == brain and is_instance_valid(_neuron_cloud):
		return
	_brain = brain
	if not root.is_empty():
		data_root = root
	_clear_connectome()
	if brain == null or brain.n <= 0:
		return
	_build_neuron_layout(brain)
	_build_neuron_nodes(brain)
	_build_connectome_edges(brain)
	var title := brain_root.get_node_or_null("BrainLabel") as Label3D
	if title != null:
		title.text = "%s · %s neurons · %s edges" % [str(species.get("name", species_id)).to_upper(), _count(brain.n), _count(brain.nsyn)]
	var activity_readout := brain_root.get_node_or_null("ActivityLabel") as Label3D
	if activity_readout != null:
		activity_label = activity_readout
		activity_label.text = "real connectome · role layout" if not _has_anatomical_positions() else "recorded neuron positions"


func apply_activity(result: Dictionary) -> void:
	if _brain == null:
		return
	var edge_events: PackedInt32Array = result.get("edges", PackedInt32Array())
	var fired: PackedInt32Array = result.get("spikes", PackedInt32Array())
	var unique_records: Array[Dictionary] = []
	var seen: Dictionary = {}
	for edge_id in edge_events:
		if not _edge_visuals.has(edge_id) or seen.has(edge_id):
			continue
		seen[edge_id] = true
		unique_records.append(_edge_visuals[edge_id])
		if unique_records.size() >= 180:
			break
	if is_instance_valid(_active_mesh):
		_active_mesh.queue_free()
	_active_mesh = _draw_edges(unique_records, Color("ffe3a6"), 0.022)
	brain_visual_root.add_child(_active_mesh)
	for neuron in _neuron_activity.keys():
		_neuron_activity[neuron] = 0.0
	for neuron in fired:
		if _neuron_instances.has(neuron):
			_neuron_activity[neuron] = 1.0
			_update_neuron_instance(neuron, 1.0)
	var motor: Dictionary = result.get("motor", {})
	_motor_bias = 0.0
	var active_score := 0
	for module: Variant in motor.values():
		for score: Variant in module:
			active_score += int(score)
	_motor_bias = float(active_score % 3 - 1)
	_activity = clampf(float(fired.size()) / 22.0, 0.0, 1.0)
	if is_instance_valid(activity_label):
		activity_label.text = "%d neurons fired · %d active synapses" % [fired.size(), unique_records.size()]


func show_decision(record: Dictionary) -> void:
	if str(record.get("species_id", "")) == species_id and action_label != null:
		action_label.text = "T%06d · %s" % [int(record.get("tick", 0)), str(record.get("action", ""))]


func _build_neuron_layout(brain: ConnectomeBrain) -> void:
	_neuron_positions.resize(brain.n)
	var row_resources: Dictionary = species.get("resources", {})
	var positions_rel := str(row_resources.get("positions", ""))
	var positions_path := data_root.path_join(positions_rel)
	var loaded_positions := false
	if not positions_rel.is_empty() and FileAccess.file_exists(positions_path):
		var data := FileAccess.get_file_as_bytes(positions_path)
		if data.size() >= 16 + brain.n * 12 and _u32(data, 8) == brain.n:
			var low := Vector3(INF, INF, INF)
			var high := Vector3(-INF, -INF, -INF)
			for i in range(brain.n):
				var offset := 16 + i * 12
				var p := Vector3(data.decode_float(offset), data.decode_float(offset + 4), data.decode_float(offset + 8))
				_neuron_positions[i] = p
				low = low.min(p)
				high = high.max(p)
			var center := (low + high) * 0.5
			var span := high - low
			var scale := 0.5 / maxf(maxf(span.x, span.y), maxf(span.z, 0.001))
			for i in range(brain.n):
				_neuron_positions[i] = (_neuron_positions[i] - center) * scale
			loaded_positions = true
	var sensory: Array[int] = []
	for group: Variant in brain.sensory.values():
		for neuron: Variant in group:
			sensory.append(int(neuron))
	var motor: Array[int] = []
	for group: Variant in brain.action_groups.values():
		for bin: Variant in group:
			for neuron: Variant in bin:
				motor.append(int(neuron))
	var visual_limit := 8000 if OS.has_feature("web") else 24000
	var target_count := mini(brain.n, visual_limit if brain.n > 10000 else brain.n)
	var chosen: Dictionary = {}
	for neuron in sensory + motor:
		if neuron >= 0 and neuron < brain.n:
			chosen[neuron] = true
	var frontier: Array[int] = sensory.duplicate()
	for _depth in range(2):
		var next: Array[int] = []
		for source in frontier:
			if source < 0 or source >= brain.n:
				continue
			var start := brain.indptr[source]
			var finish := mini(brain.indptr[source + 1], start + 18)
			for edge in range(start, finish):
				var target := brain.post[edge]
				if not chosen.has(target):
					chosen[target] = true
					next.append(target)
				if chosen.size() >= target_count:
					break
			if chosen.size() >= target_count:
				break
		frontier = next
		if chosen.size() >= target_count:
			break
	var rng := RandomNumberGenerator.new()
	rng.seed = brain.n * 7919 + species_id.hash()
	while chosen.size() < target_count:
		chosen[rng.randi_range(0, brain.n - 1)] = true
	for id_value: Variant in chosen.keys():
		_visible_neurons.append(int(id_value))
	_visible_neurons.sort()
	var sensory_set: Dictionary = {}
	var motor_set: Dictionary = {}
	for neuron in sensory:
		sensory_set[neuron] = true
	for neuron in motor:
		motor_set[neuron] = true
	if not loaded_positions:
		# Same Open-Fly role layout and species proportions. These coordinates
		# show connectome roles, not anatomy, when the source has no soma file.
		var shape := Vector3(0.8, 0.55, 0.5)
		if species_id.begins_with("c_elegans"):
			shape = Vector3(1.0, 0.18, 0.18)
		elif species_id == "ciona_larva":
			shape = Vector3(1.0, 0.3, 0.3)
		elif species_id == "drosophila_larva":
			shape = Vector3(0.8, 0.5, 0.5)
		elif species_id == "zebrafish_larva":
			shape = Vector3(1.0, 0.45, 0.4)
		for neuron in _visible_neurons:
			var p := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
			while p.length_squared() > 1.0:
				p = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
			if sensory_set.has(neuron):
				p.x = 0.55 + absf(p.x) * 0.45
			elif motor_set.has(neuron):
				p.x = -0.55 - absf(p.x) * 0.45
			_neuron_positions[neuron] = Vector3(p.x * shape.x, p.y * shape.y, p.z * shape.z)
		var low := Vector3(INF, INF, INF)
		var high := Vector3(-INF, -INF, -INF)
		for neuron in _visible_neurons:
			low = low.min(_neuron_positions[neuron])
			high = high.max(_neuron_positions[neuron])
		var center := (low + high) * 0.5
		var span := high - low
		var scale := 0.5 / maxf(maxf(span.x, span.y), maxf(span.z, 0.001))
		for neuron in _visible_neurons:
			_neuron_positions[neuron] = (_neuron_positions[neuron] - center) * scale


func _build_neuron_nodes(brain: ConnectomeBrain) -> void:
	var sensory: Dictionary = {}
	for group: Variant in brain.sensory.values():
		for neuron: Variant in group:
			sensory[int(neuron)] = true
	var motor: Dictionary = {}
	for group: Variant in brain.action_groups.values():
		for bin: Variant in group:
			for neuron: Variant in bin:
				motor[int(neuron)] = true
	var dots := MultiMesh.new()
	dots.transform_format = MultiMesh.TRANSFORM_3D
	dots.use_colors = true
	var point := QuadMesh.new()
	point.size = Vector2.ONE
	dots.mesh = point
	dots.instance_count = _visible_neurons.size()
	_neuron_radii.resize(_visible_neurons.size())
	for index in range(_visible_neurons.size()):
		var neuron := _visible_neurons[index]
		var base := Color(0.30, 0.62, 0.58, 0.12)
		if sensory.has(neuron):
			base = Color(0.50, 0.82, 0.68, 0.20)
		elif motor.has(neuron):
			base = Color(station_color.r, station_color.g, station_color.b, 0.80)
		_base_colors[neuron] = base
		_neuron_instances[neuron] = index
		var radius := 0.0045 if brain.n > 10000 else 0.009 if brain.n > 1000 else 0.018
		if motor.has(neuron):
			radius *= 1.6
		_neuron_radii[index] = radius
		dots.set_instance_transform(index, Transform3D(Basis().scaled(Vector3.ONE * radius), _neuron_positions[neuron]))
		dots.set_instance_color(index, base)
	_neuron_cloud = MultiMeshInstance3D.new()
	_neuron_cloud.multimesh = dots
	_neuron_cloud.material_override = _neuron_cloud_material()
	_neuron_cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	brain_visual_root.add_child(_neuron_cloud)


func _neuron_cloud_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
varying vec4 point_color;
void vertex() { point_color = COLOR; }
void fragment() {
	ALBEDO = point_color.rgb;
	EMISSION = point_color.rgb * (0.35 + point_color.a * 1.7);
	float radius = distance(UV, vec2(0.5));
	ALPHA = point_color.a * (1.0 - smoothstep(0.34, 0.5, radius));
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _build_connectome_edges(brain: ConnectomeBrain) -> void:
	var visible: Dictionary = {}
	for neuron in _visible_neurons:
		visible[neuron] = true
	var records: Array[Dictionary] = []
	for source in _visible_neurons:
		var start := brain.indptr[source]
		var finish := brain.indptr[source + 1]
		var stride := maxi(1, (finish - start) / 12)
		for edge in range(start, finish, stride):
			var target := brain.post[edge]
			if not visible.has(target):
				continue
			var record := {"edge": edge, "from": source, "to": target}
			records.append(record)
			_edge_visuals[edge] = record
			if records.size() >= 5000:
				break
		if records.size() >= 5000:
			break
	# Keep the real CSR edges as an index for activity pulses; drawing every edge
	# as a permanent line makes a tangled ball unlike Open Fly's neuron cloud.
	_active_mesh = _draw_edges([], Color("ffe3a6"), 0.022)
	brain_visual_root.add_child(_active_mesh)


func _draw_edges(records: Array[Dictionary], color: Color, _width: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	if not records.is_empty():
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for edge: Dictionary in records:
			mesh.surface_add_vertex(_neuron_positions[int(edge.from)])
			mesh.surface_add_vertex(_neuron_positions[int(edge.to)])
		mesh.surface_end()
	instance.mesh = mesh
	instance.material_override = _material(color, 0.0, 0.3, true)
	(instance.material_override as StandardMaterial3D).emission_energy_multiplier = 2.4 if color.r > 0.8 else 0.6
	return instance


func _clear_connectome() -> void:
	for child in brain_visual_root.get_children():
		child.queue_free()
	_neuron_positions.clear()
	_visible_neurons.clear()
	_neuron_instances.clear()
	_neuron_radii.clear()
	_neuron_activity.clear()
	_edge_visuals.clear()
	_base_colors.clear()
	_neuron_cloud = null
	_active_mesh = null


func _has_anatomical_positions() -> bool:
	var relative := str(species.get("resources", {}).get("positions", ""))
	return not relative.is_empty() and FileAccess.file_exists(data_root.path_join(relative))


func _decay_neuron_activity(delta: float) -> void:
	var decay := exp(-delta * 2.2)
	for neuron_value: Variant in _neuron_activity.keys():
		var neuron := int(neuron_value)
		var strength := float(_neuron_activity.get(neuron, 0.0)) * decay
		if strength <= 0.002:
			_neuron_activity.erase(neuron)
			_update_neuron_instance(neuron, 0.0)
		else:
			_neuron_activity[neuron] = strength
			_update_neuron_instance(neuron, strength)


func _update_neuron_instance(neuron: int, strength: float) -> void:
	if not is_instance_valid(_neuron_cloud) or not _neuron_instances.has(neuron):
		return
	var index := int(_neuron_instances[neuron])
	var base: Color = _base_colors.get(neuron, Color(0.30, 0.62, 0.58, 0.12))
	var pulse := clampf(strength, 0.0, 1.0)
	var color := base.lerp(Color(1.0, 0.95, 0.80, 1.0), pulse)
	color.a = lerpf(base.a, 1.0, pulse)
	_neuron_cloud.multimesh.set_instance_color(index, color)
	var radius := _neuron_radii[index] * (1.0 + pulse * 0.65)
	var transform := Transform3D(Basis().scaled(Vector3.ONE * radius), _neuron_positions[neuron])
	_neuron_cloud.multimesh.set_instance_transform(index, transform)


func _fit_model(model: Node3D, desired: float) -> float:
	var bounds := AABB()
	var found := false
	var stack: Array[Node] = [model]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MeshInstance3D:
			var mesh_node := node as MeshInstance3D
			var source := mesh_node.get_aabb()
			var relative := model.global_transform.affine_inverse() * mesh_node.global_transform
			var low := Vector3(INF, INF, INF)
			var high := Vector3(-INF, -INF, -INF)
			for corner in range(8):
				var point := source.position + Vector3(source.size.x if corner & 1 else 0.0, source.size.y if corner & 2 else 0.0, source.size.z if corner & 4 else 0.0)
				point = relative * point
				low = low.min(point)
				high = high.max(point)
			bounds = AABB(low, high - low) if not found else bounds.merge(AABB(low, high - low))
			found = true
	if not found:
		model.scale = Vector3.ONE * desired
		return desired
	var span := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var scale := desired / maxf(span, 0.001)
	model.scale = Vector3.ONE * scale
	model.position = -bounds.get_center() * scale
	return bounds.size.y * scale


func _play_idle_animation(root: Node) -> void:
	var queue: Array[Node] = [root]
	while not queue.is_empty():
		var node: Node = queue.pop_back()
		for child in node.get_children():
			queue.append(child)
		if node is AnimationPlayer:
			var player := node as AnimationPlayer
			var animations := player.get_animation_list()
			if not animations.is_empty():
				player.play(str(animations[0]))
			return


func _add_box(size: Vector3, at: Vector3, material: StandardMaterial3D) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	add_child(instance)


func _add_cylinder(top_radius: float, bottom_radius: float, height: float, at: Vector3, material: StandardMaterial3D) -> void:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	add_child(instance)


func _material(color: Color, metallic: float, roughness: float, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
	return material


func _u32(data: PackedByteArray, offset: int) -> int:
	return int(data[offset]) | (int(data[offset + 1]) << 8) | (int(data[offset + 2]) << 16) | (int(data[offset + 3]) << 24)


func _count(value: int) -> String:
	if value >= 1_000_000:
		return "%.1fM" % (float(value) / 1_000_000.0)
	if value >= 1_000:
		return "%.1fk" % (float(value) / 1_000.0)
	return str(value)
