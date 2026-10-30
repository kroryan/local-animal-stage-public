extends Node3D

const ChartKit = preload("res://scripts/ui/chart_kit.gd")
const AnimalStationClass = preload("res://scripts/animals/animal_station.gd")

var camera: Camera3D
var _wall_chart: TauPlot
var _wall_viewport: SubViewport
var _stations: Dictionary = {}
var _station_order: Array[String] = []
var _camera_target := Vector3(0.0, 1.55, -0.95)
var _camera_yaw := 0.0
var _camera_pitch := 0.045
var _camera_distance := 9.4
var _camera_dragging := false


func _ready() -> void:
	_build_laboratory()


func _process(delta: float) -> void:
	if get_viewport().gui_get_focus_owner() != null:
		return
	var movement := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): movement.z -= 1.0
	if Input.is_key_pressed(KEY_S): movement.z += 1.0
	if Input.is_key_pressed(KEY_A): movement.x -= 1.0
	if Input.is_key_pressed(KEY_D): movement.x += 1.0
	if Input.is_key_pressed(KEY_Q): movement.y -= 1.0
	if Input.is_key_pressed(KEY_E): movement.y += 1.0
	if movement.length_squared() > 0.0:
		var speed := 2.4 if not Input.is_key_pressed(KEY_SHIFT) else 5.0
		var forward := Vector3(-sin(_camera_yaw), 0.0, -cos(_camera_yaw))
		var right := Vector3(cos(_camera_yaw), 0.0, -sin(_camera_yaw))
		_camera_target += (right * movement.x + Vector3.UP * movement.y + forward * -movement.z).normalized() * speed * delta
		_apply_camera_pose()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_RIGHT:
			_camera_dragging = button.pressed
			get_viewport().set_input_as_handled()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = clampf(_camera_distance - 0.55, 4.0, 30.0)
			_apply_camera_pose()
			get_viewport().set_input_as_handled()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = clampf(_camera_distance + 0.55, 4.0, 30.0)
			_apply_camera_pose()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _camera_dragging:
		var motion := event as InputEventMouseMotion
		_camera_yaw = wrapf(_camera_yaw - motion.relative.x * 0.004, -PI, PI)
		_camera_pitch = clampf(_camera_pitch + motion.relative.y * 0.003, -0.55, 0.48)
		_apply_camera_pose()
		get_viewport().set_input_as_handled()


func _apply_camera_pose() -> void:
	if camera == null:
		return
	var offset := Vector3(sin(_camera_yaw) * cos(_camera_pitch), sin(_camera_pitch), cos(_camera_yaw) * cos(_camera_pitch)) * _camera_distance
	camera.position = _camera_target + offset
	camera.look_at(_camera_target, Vector3.UP)


func _build_laboratory() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101619")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9db3ac")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)
	camera = Camera3D.new()
	camera.fov = 48.0
	add_child(camera)
	_apply_camera_pose()
	camera.make_current()
	_add_box(Vector3(70.0, 0.24, 28.0), Vector3(0.0, -0.17, -0.4), Color("242c2e"), 0.44, 0.54)
	_add_box(Vector3(70.0, 8.0, 0.22), Vector3(0.0, 3.85, -4.0), Color("182126"), 0.2, 0.82)
	_add_box(Vector3(0.2, 8.0, 28.0), Vector3(-35.0, 3.85, -0.4), Color("202a2d"), 0.42, 0.65)
	_add_box(Vector3(0.2, 8.0, 28.0), Vector3(35.0, 3.85, -0.4), Color("202a2d"), 0.42, 0.65)
	var key_light := OmniLight3D.new()
	key_light.position = Vector3(-4.0, 6.5, 4.2)
	key_light.light_color = Color("b9d9d0")
	key_light.light_energy = 4.2
	key_light.omni_range = 23.0
	add_child(key_light)
	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(6.0, 4.0, -1.5)
	rim_light.light_color = Color("d79d61")
	rim_light.light_energy = 2.1
	rim_light.omni_range = 16.0
	add_child(rim_light)
	_build_wall_screen()


func _build_wall_screen() -> void:
	_add_box(Vector3(5.5, 3.15, 0.2), Vector3(0.0, 4.1, -3.82), Color("080d10"), 0.7, 0.28)
	_wall_viewport = SubViewport.new()
	_wall_viewport.size = Vector2i(1024, 576)
	_wall_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_wall_viewport.transparent_bg = false
	add_child(_wall_viewport)
	var surface := ColorRect.new()
	surface.color = Color("101719")
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wall_viewport.add_child(surface)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 3)
	surface.add_child(layout)
	var heading := Label.new()
	heading.text = "OPEN ANIMAL STAGE  /  CONNECTOME OBSERVATORY"
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color("79d5c1"))
	layout.add_child(heading)
	# The wall SubViewport is 576px tall; keeping the chart below that height
	# leaves space for TauPlot's title/axes while avoiding a clipped layout.
	_wall_chart = ChartKit.create("BRAIN ACTIVITY · LIVE TAUPLOT", 500)
	_wall_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ChartKit.render(_wall_chart, {"kind": "message", "title": "BRAIN ACTIVITY · LIVE TAUPLOT", "message": "Attach a simulation stream to display neural activity and decisions."})
	layout.add_child(_wall_chart)
	var display := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(5.26, 2.96)
	display.mesh = quad
	display.position = Vector3(0.0, 4.1, -3.70)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _wall_viewport.get_texture()
	material.emission_enabled = true
	material.emission_texture = _wall_viewport.get_texture()
	material.emission_energy_multiplier = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	display.material_override = material
	add_child(display)
	_wall_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var sign := Label3D.new()
	sign.text = "CONNECTOME OBSERVATORY  ·  LIVE BRAIN ACTIVITY"
	sign.position = Vector3(-2.65, 5.78, -3.6)
	sign.font_size = 25
	sign.pixel_size = 0.003
	sign.modulate = Color("79d5c1")
	add_child(sign)


func set_participants(rows: Array[Dictionary], resource_root: String = "res://neural_assets") -> void:
	var wanted: Dictionary = {}
	for row: Dictionary in rows:
		wanted[str(row.get("id", ""))] = true
	for old_id: Variant in _stations.keys():
		if wanted.has(str(old_id)):
			continue
		var old_station := _stations[str(old_id)] as Node3D
		if is_instance_valid(old_station):
			old_station.queue_free()
		_stations.erase(str(old_id))
	_station_order.clear()
	var spacing := 2.25
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var species_id := str(row.get("id", ""))
		var station := _stations.get(species_id) as Node3D
		if station == null:
			station = AnimalStationClass.new()
			station.name = "Station_%s" % species_id
			add_child(station)
			station.configure(row, 0.0, ChartKit.PALETTE[index % ChartKit.PALETTE.size()], resource_root)
			_stations[species_id] = station
		station.position.x = (float(index) - float(rows.size() - 1) * 0.5) * spacing
		_station_order.append(species_id)
	var row_width := maxf(2.0, float(rows.size() - 1) * spacing + 2.6)
	_camera_target = Vector3(0.0, 1.62, -0.65)
	_camera_distance = maxf(7.35, row_width * 0.87)
	_apply_camera_pose()


func set_connectome(species_id: String, brain: ConnectomeBrain, resource_root: String = "") -> void:
	var station := _stations.get(species_id) as Node3D
	if station != null:
		station.call("set_connectome", brain, resource_root)


func focus_station(species_id: String) -> void:
	if not _stations.has(species_id):
		return
	var station := _stations[species_id] as Node3D
	_camera_target = station.position + Vector3(-0.05, 1.4, -0.05)
	_camera_distance = 4.9
	_apply_camera_pose()


func focus_all() -> void:
	_camera_target = Vector3(0.0, 1.62, -0.65)
	_camera_distance = maxf(7.35, float(maxi(1, _stations.size()) - 1) * 2.25 * 0.87 + 2.1)
	_apply_camera_pose()


func apply_activity(species_id: String, result: Dictionary) -> void:
	var station := _stations.get(species_id) as Node3D
	if station != null:
		station.call("apply_activity", result)


func update_decision(record: Dictionary) -> void:
	var station := _stations.get(str(record.get("species_id", ""))) as Node3D
	if station != null:
		station.call("show_decision", record)


func _add_box(size: Vector3, at: Vector3, color: Color, metallic: float, roughness: float) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	instance.material_override = material
	add_child(instance)
