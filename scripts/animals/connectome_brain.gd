extends RefCounted
class_name ConnectomeBrain

# Reads the same SFC1/OAS1 CSR connectome package used by Open Fly. This is a
# compact LIF runtime for a single pilot; every emitted spike and lit edge is
# indexed from that animal's actual connectome, never a generated graph.
const WINDOW_MS := 100.0
const MIN_RUNTIME_DT_MS := 0.5

var meta: Dictionary = {}
var n := 0
var nsyn := 0
var ngap := 0
var indptr := PackedInt32Array()
var post := PackedInt32Array()
var weight_pairs := PackedInt32Array()
var gap_a := PackedInt32Array()
var gap_b := PackedInt32Array()
var gap_w := PackedFloat32Array()
var v := PackedFloat32Array()
var g := PackedFloat32Array()
var refractory := PackedInt32Array()
var no_refractory := PackedByteArray()
var awake := PackedByteArray()
var awake_ids: Array[int] = []
var ring_posts: Array[PackedInt32Array] = []
var ring_weights: Array[PackedFloat32Array] = []
var ring_head := 0
var dt := 0.1
var v0 := -52.0
var threshold := -45.0
var v_reset := -52.0
var tau_membrane := 20.0
var tau_synapse := 5.0
var refractory_steps := 22
var delay_steps := 18
var synapse_weight := 0.275
var poisson_scale := 250.0
var gap_gain := 0.0
var membrane_decay := 0.0
var synapse_decay := 0.0
var voltage_factor := 0.0
var _spike_mark := PackedByteArray()
var sensory: Dictionary = {}
var senses: Dictionary = {}
var action_groups: Dictionary = {}
var last_spikes: PackedInt32Array = PackedInt32Array()
var last_active_edges: PackedInt32Array = PackedInt32Array()
var last_motor_counts: Dictionary = {}
var load_error := ""


func load_from_paths(metadata_path: String, manifest_path: String) -> bool:
	load_error = ""
	if not FileAccess.file_exists(metadata_path) or not FileAccess.file_exists(manifest_path):
		return _fail("connectome metadata or package manifest is missing")
	var meta_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not meta_value is Dictionary or not manifest is Dictionary:
		return _fail("brain metadata or connectome manifest is invalid")
	meta = meta_value
	var bytes := PackedByteArray()
	var parts: Array = manifest.get("parts", [])
	if parts.is_empty():
		parts = [str(manifest.get("name", "connectome.bin"))]
	for item: Variant in parts:
		var part_path := manifest_path.get_base_dir().path_join(str(item))
		var file := FileAccess.open(part_path, FileAccess.READ)
		if file == null:
			return _fail("connectome part missing: " + part_path)
		bytes.append_array(file.get_buffer(file.get_length()))
		file.close()
	if bytes.size() != int(manifest.get("size", bytes.size())):
		return _fail("connectome size does not match its manifest")
	var header := _u32(bytes, 4)
	var magic := bytes.slice(0, 4).get_string_from_ascii()
	if magic == "OAS1":
		n = header
		nsyn = _u32(bytes, 8)
		ngap = _u32(bytes, 12)
		_load_csr(bytes, 16)
	elif magic == "SFC1":
		n = header
		nsyn = _u32(bytes, 8)
		ngap = 0
		_load_csr(bytes, 12)
	else:
		return _fail("unrecognised connectome signature: " + magic)
	if n <= 0 or nsyn <= 0 or indptr.size() != n + 1 or indptr[n] != nsyn:
		return _fail("connectome CSR dimensions are inconsistent")
	if bytes.size() != int(manifest.get("size", bytes.size())):
		return _fail("connectome package ended unexpectedly")
	var params: Dictionary = meta.get("params", {})
	# Source packages use a 0.1 ms step. A 0.5 ms LIF step stays well below
	# the packaged 5–20 ms time constants and keeps each turn responsive.
	dt = maxf(float(params.get("dt", 0.1)), MIN_RUNTIME_DT_MS)
	tau_membrane = float(params.get("t_mbr", 20.0))
	tau_synapse = float(params.get("tau", 5.0))
	v0 = float(params.get("v_0", -52.0))
	threshold = float(params.get("v_th", -45.0))
	v_reset = float(params.get("v_rst", v0))
	refractory_steps = maxi(1, roundi(float(params.get("t_rfc", 2.2)) / dt))
	delay_steps = maxi(0, roundi(float(params.get("t_dly", 1.8)) / dt))
	synapse_weight = float(params.get("w_syn", 0.275))
	poisson_scale = float(params.get("f_poi", 250.0))
	gap_gain = float(params.get("w_gap", 0.0)) * dt / maxf(tau_membrane, 0.001)
	membrane_decay = exp(-dt / tau_membrane)
	synapse_decay = exp(-dt / tau_synapse)
	voltage_factor = tau_synapse / (tau_synapse - tau_membrane)
	sensory = meta.get("sensory", {})
	senses = meta.get("senses", {})
	action_groups = meta.get("groups", {})
	_initialize_neurons()
	return true


func _load_csr(bytes: PackedByteArray, start: int) -> void:
	indptr = bytes.slice(start, start + (n + 1) * 4).to_int32_array()
	var offset := start + (n + 1) * 4
	post = bytes.slice(offset, offset + nsyn * 4).to_int32_array()
	offset += nsyn * 4
	var packed_size := nsyn * 2
	var aligned_size := packed_size & ~3
	weight_pairs = bytes.slice(offset, offset + aligned_size).to_int32_array()
	if aligned_size < packed_size:
		weight_pairs.append(_u16(bytes, offset + aligned_size))
	offset += nsyn * 2
	if ngap > 0:
		offset = (offset + 3) & ~3
		gap_a.resize(ngap)
		gap_b.resize(ngap)
		gap_w.resize(ngap)
		for i in range(ngap): gap_a[i] = _u32(bytes, offset + i * 4)
		offset += ngap * 4
		for i in range(ngap): gap_b[i] = _u32(bytes, offset + i * 4)
		offset += ngap * 4
		for i in range(ngap): gap_w[i] = bytes.decode_float(offset + i * 4)


func _initialize_neurons() -> void:
	v.resize(n)
	g.resize(n)
	refractory.resize(n)
	no_refractory.resize(n)
	awake.resize(n)
	_spike_mark.resize(n)
	_spike_mark.fill(0)
	for i in range(n):
		v[i] = v0
		g[i] = 0.0
		refractory[i] = 0
	awake_ids.clear()
	for channel: Variant in sensory.values():
		for neuron: Variant in channel:
			if int(neuron) >= 0 and int(neuron) < n:
				no_refractory[int(neuron)] = 1
	if gap_gain != 0.0:
		for i in range(gap_a.size()):
			_wake(gap_a[i])
			_wake(gap_b[i])
	ring_posts.clear()
	ring_weights.clear()
	for _i in range(delay_steps + 1):
		ring_posts.append(PackedInt32Array())
		ring_weights.append(PackedFloat32Array())
	ring_head = 0


func run_window(rates: Dictionary, seed: int, requested_window_ms: float = -1.0) -> Dictionary:
	if n == 0:
		return {"ok": false, "error": load_error, "spikes": PackedInt32Array(), "edges": PackedInt32Array(), "motor": {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var counts := PackedInt32Array()
	counts.resize(n)
	var lit := PackedInt32Array()
	var edge_seen: Dictionary = {}
	var output := {"counts": counts, "edges": lit, "edge_seen": edge_seen, "spike_events": 0}
	var window_ms := WINDOW_MS if requested_window_ms <= 0.0 else maxf(dt, requested_window_ms)
	var steps := roundi(window_ms / dt)
	# Match Open Fly's runWindow boundary: advance 2 ms without sensory input,
	# then return awake cells to rest before the next decision window. Decision windows are
	# separated in wall-clock time; carrying stale membrane voltage across that
	# gap made small connectomes settle into permanent motor silence.
	var flush_steps := roundi(2.0 / dt)
	var no_input: Dictionary = {}
	for _flush in range(flush_steps):
		_step(no_input, rng, null)
	for neuron: int in awake_ids:
		v[neuron] = v0
		g[neuron] = 0.0
	for _i in range(steps):
		_step(rates, rng, output)
	var spike_events := int(output.get("spike_events", 0))
	var fired := PackedInt32Array()
	for neuron in range(n):
		if counts[neuron] > 0:
			fired.append(neuron)
	last_spikes = fired
	last_active_edges = lit
	last_motor_counts.clear()
	for module: Variant in action_groups.keys():
		var groups: Array = action_groups[module]
		var scores: Array[int] = []
		for group: Variant in groups:
			var score := 0
			for neuron: Variant in group:
				if int(neuron) >= 0 and int(neuron) < counts.size(): score += counts[int(neuron)]
			scores.append(score)
		last_motor_counts[str(module)] = scores
	return {"ok": true, "counts": counts, "spikes": fired, "spike_events": spike_events, "edges": lit, "motor": last_motor_counts.duplicate(true), "window_ms": window_ms, "runtime_dt_ms": dt}


func _step(rates: Dictionary, rng: RandomNumberGenerator, output: Variant) -> void:
	var em := membrane_decay
	var es := synapse_decay
	var k := voltage_factor
	var spiked: Array[int] = []
	var next_awake: Array[int] = []
	for neuron in awake_ids:
		if refractory[neuron] > 0:
			next_awake.append(neuron)
			continue
		var conductance := g[neuron]
		var voltage := v0 + (v[neuron] - v0 - k * conductance) * em + k * conductance * es
		v[neuron] = voltage
		g[neuron] = conductance * es
		if voltage > threshold:
			spiked.append(neuron)
			next_awake.append(neuron)
		elif gap_gain == 0.0 and absf(voltage - v0) < 0.00001 and absf(g[neuron]) < 0.000001:
			v[neuron] = v0
			g[neuron] = 0.0
			awake[neuron] = 0
		else:
			next_awake.append(neuron)
	awake_ids = next_awake
	for neuron in spiked:
		_spike_mark[neuron] = 1
	if gap_gain != 0.0:
		for edge in range(gap_a.size()):
			var a := gap_a[edge]
			var b := gap_b[edge]
			if refractory[a] > 0 or refractory[b] > 0: continue
			var diff := gap_gain * gap_w[edge] * (v[b] - v[a])
			v[a] += diff
			v[b] -= diff
		for edge in range(gap_a.size()):
			var a := gap_a[edge]
			var b := gap_b[edge]
			if refractory[a] == 0 and v[a] > threshold and _spike_mark[a] == 0:
				_spike_mark[a] = 1
				spiked.append(a)
			if refractory[b] == 0 and v[b] > threshold and _spike_mark[b] == 0:
				_spike_mark[b] = 1
				spiked.append(b)
	var due_posts := ring_posts[ring_head]
	var due_weights := ring_weights[ring_head]
	for j in range(due_posts.size()):
		var target := due_posts[j]
		if refractory[target] > 0: continue
		g[target] += due_weights[j]
		_wake(target)
	due_posts.clear()
	due_weights.clear()
	ring_posts[ring_head] = due_posts
	ring_weights[ring_head] = due_weights
	for channel: Variant in sensory.keys():
		var rate := float(rates.get(str(senses.get(str(channel), "")), 0.0))
		if rate <= 0.0: continue
		var chance := rate * dt * 0.001
		for neuron_value: Variant in sensory[channel]:
			var neuron := int(neuron_value)
			if rng.randf() < chance and refractory[neuron] <= 0:
				v[neuron] += synapse_weight * poisson_scale
				_wake(neuron)
	var target_bucket := posmod(ring_head + delay_steps, ring_posts.size())
	var schedule_posts := ring_posts[target_bucket]
	var schedule_weights := ring_weights[target_bucket]
	var step_spike_count := spiked.size()
	for neuron in spiked:
		v[neuron] = v_reset
		g[neuron] = 0.0
		refractory[neuron] = 0 if no_refractory[neuron] == 1 else refractory_steps
		if output != null:
			output.counts[neuron] += 1
		for edge in range(indptr[neuron], indptr[neuron + 1]):
			schedule_posts.append(post[edge])
			var packed := weight_pairs[edge >> 1]
			var raw := packed & 0xffff if (edge & 1) == 0 else (packed >> 16) & 0xffff
			if raw >= 32768:
				raw -= 65536
			schedule_weights.append(float(raw) * synapse_weight)
			if output != null and output.edges.size() < 1200 and not output.edge_seen.has(edge):
				output.edge_seen[edge] = true
				output.edges.append(edge)
	ring_posts[target_bucket] = schedule_posts
	ring_weights[target_bucket] = schedule_weights
	for neuron in awake_ids:
		if refractory[neuron] > 0 and _spike_mark[neuron] == 0:
			refractory[neuron] -= 1
	for neuron in spiked:
		_spike_mark[neuron] = 0
	if output != null:
		output.spike_events = int(output.spike_events) + step_spike_count
	ring_head = (ring_head + 1) % ring_posts.size()


func _wake(neuron: int) -> void:
	if neuron < 0 or neuron >= n or awake[neuron] == 1:
		return
	awake[neuron] = 1
	awake_ids.append(neuron)


func _u16(bytes: PackedByteArray, offset: int) -> int:
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8)


func _u32(bytes: PackedByteArray, offset: int) -> int:
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8) | (int(bytes[offset + 2]) << 16) | (int(bytes[offset + 3]) << 24)


func _fail(message: String) -> bool:
	load_error = message
	return false
