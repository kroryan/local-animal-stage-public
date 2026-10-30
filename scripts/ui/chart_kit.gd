class_name ChartKit
extends RefCounted

# Thin builder over the TauPlot addon so every window can show a chart in a few
# lines: line/area history, grouped or stacked bars, and scatter plots.
# Series are plain dictionaries: {name, color, xs, ys} or {name, color, values}.

const TauDataset = preload("res://addons/tau-plot/model/dataset.gd").Dataset
const TauAxisId = preload("res://addons/tau-plot/plot/xy/xy_axes.gd").AxisId
const TauOverlayType = preload("res://addons/tau-plot/plot/xy/pane_overlay_type.gd").PaneOverlayType

const PALETTE: Array[Color] = [Color("82b9b0"), Color("e7ad68"), Color("91c9ae"), Color("e78976"), Color("ae9acb"), Color("dd8f72")]


static func create(title: String, min_height: float = 170.0) -> TauPlot:
	var chart: TauPlot = TauPlot.new()
	chart.title = "[color=#e7ad68][b]%s[/b][/color]" % title
	chart.legend_enabled = true
	chart.custom_minimum_size = Vector2(250.0, min_height)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = UiTheme.SURFACE
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	chart.add_theme_stylebox_override("panel", style)
	return chart


# Colour-blind mode: the stock green and red become blue and orange in every chart.
static func accessible(color: Color) -> Color:
	if not bool(GameSettings.get_value("colorblind")):
		return color
	if color.is_equal_approx(Color("91c9ae")):
		return GameSettings.positive_color()
	if color.is_equal_approx(Color("e78976")):
		return GameSettings.negative_color()
	return color


static func _colors(series: Array) -> Array[Color]:
	var colors: Array[Color] = []
	for index: int in range(series.size()):
		colors.append(accessible(series[index].get("color", PALETTE[index % PALETTE.size()])))
	return colors


static func _names(series: Array) -> PackedStringArray:
	var names := PackedStringArray()
	for item: Dictionary in series:
		names.append(str(item.name))
	return names


static func _bindings(dataset: Object, count: int, overlay: int) -> Array[TauXYSeriesBinding]:
	var bindings: Array[TauXYSeriesBinding] = []
	for index: int in range(count):
		var binding := TauXYSeriesBinding.new()
		binding.series_id = dataset.get_series_id_by_index(index)
		binding.pane_index = 0
		binding.overlay_type = overlay
		binding.y_axis_id = TauAxisId.LEFT
		bindings.append(binding)
	return bindings


static func _axis(title: String, categorical: bool = false, include_zero: bool = true, ticks: int = 4) -> TauAxisConfig:
	var axis := TauAxisConfig.new()
	axis.type = TauAxisConfig.Type.CATEGORICAL if categorical else TauAxisConfig.Type.CONTINUOUS
	axis.title = title
	if not categorical:
		axis.include_zero_in_domain = include_zero
		axis.tick_count_preferred = ticks
	return axis


static func _finish(chart: TauPlot, dataset: Object, x_axis: TauAxisConfig, y_title: String, overlay_config: TauPaneOverlayConfig, series: Array, overlay: int) -> void:
	var pane := TauPaneConfig.new()
	# Keep chart behavior generic and independent of a specific simulation.
	var include_zero := true
	pane.y_left_axis = _axis(y_title, false, include_zero)
	pane.overlays = [overlay_config]
	var config := TauXYConfig.new()
	config.x_axis = x_axis
	config.panes = [pane]
	config.style.series_colors = _colors(series)
	chart.plot_xy(dataset, config, _bindings(dataset, series.size(), overlay))


# Time series. `area` adds a flat fill under each line.
static func plot_lines(chart: TauPlot, x_title: String, y_title: String, series: Array, step: bool = false) -> bool:
	if series.is_empty():
		return false
	for item: Dictionary in series:
		if (item.get("xs", PackedFloat64Array()) as PackedFloat64Array).size() < 2:
			return plot_scatter(chart, x_title, y_title, series)
	var xs: Array[PackedFloat64Array] = []
	var ys: Array[PackedFloat64Array] = []
	for item: Dictionary in series:
		if (item.xs as PackedFloat64Array).size() < 2:
			return false
		xs.append(item.xs)
		ys.append(item.ys)
	var dataset: Object = TauDataset.make_per_series_x_continuous(_names(series), xs, ys)
	if dataset == null:
		return false
	var line := TauLineConfig.new()
	line.interpolation_modes = [TauLineConfig.InterpolationMode.STEP_AFTER if step else TauLineConfig.InterpolationMode.LINEAR]
	line.style.line_widths_px = [2.2]
	_finish(chart, dataset, _axis(x_title, false, false, 5), y_title, line, series, TauOverlayType.LINE)
	return true


# Bars per category. Each series: {name, color, values}.
static func plot_bars(chart: TauPlot, y_title: String, categories: PackedStringArray, series: Array, stacked: bool = false) -> bool:
	if series.is_empty() or categories.is_empty():
		return false
	var values: Array[PackedFloat64Array] = []
	for item: Dictionary in series:
		values.append(item.values)
	var dataset: Object = TauDataset.make_shared_x_categorical(_names(series), categories, values)
	if dataset == null:
		return false
	var bars := TauBarConfig.new()
	bars.mode = TauBarConfig.BarMode.STACKED if stacked else TauBarConfig.BarMode.GROUPED
	_finish(chart, dataset, _axis("", true), y_title, bars, series, TauOverlayType.BAR)
	return true


# Scatter of points. Each series: {name, color, xs, ys}.
static func plot_scatter(chart: TauPlot, x_title: String, y_title: String, series: Array) -> bool:
	if series.is_empty():
		return false
	var xs: Array[PackedFloat64Array] = []
	var ys: Array[PackedFloat64Array] = []
	for item: Dictionary in series:
		if (item.xs as PackedFloat64Array).is_empty():
			return false
		xs.append(item.xs)
		ys.append(item.ys)
	var dataset: Object = TauDataset.make_per_series_x_continuous(_names(series), xs, ys)
	if dataset == null:
		return false
	_finish(chart, dataset, _axis(x_title, false, true, 5), y_title, TauScatterConfig.new(), series, TauOverlayType.SCATTER)
	return true


# One-call entry used by the desktop: spec = {kind, title, ...}.
# Cheap fingerprint of what a chart would draw; unchanged data is not re-plotted.
static func spec_signature(spec: Dictionary) -> int:
	var parts: Array = [spec.get("kind", "lines"), spec.get("title", ""), spec.get("categories", PackedStringArray()), spec.get("values", PackedFloat64Array()), spec.get("colors", []), GameSettings.get_value("colorblind")]
	for item: Dictionary in spec.get("series", []):
		parts.append(item.get("name", ""))
		if item.has("values"):
			parts.append(item.values)
		else:
			var xs: PackedFloat64Array = item.get("xs", PackedFloat64Array())
			var ys: PackedFloat64Array = item.get("ys", PackedFloat64Array())
			parts.append(xs.size())
			if xs.size() > 0:
				parts.append(xs[0])
				parts.append(xs[xs.size() - 1])
				parts.append(ys[ys.size() - 1])
				parts.append(ys[ys.size() / 2])
	return hash(parts)


static func render(chart: TauPlot, spec: Dictionary) -> bool:
	var signature := spec_signature(spec)
	if chart.has_meta("chart_sig") and int(chart.get_meta("chart_sig")) == signature:
		return bool(chart.get_meta("chart_ok", true))
	var ok := _render_uncached(chart, spec)
	chart.set_meta("chart_sig", signature)
	chart.set_meta("chart_ok", ok)
	return ok


static func _render_uncached(chart: TauPlot, spec: Dictionary) -> bool:
	chart.title = "[color=#e7ad68][b]%s[/b][/color]" % str(spec.get("title", ""))
	var rendered := false
	match str(spec.get("kind", "lines")):
		"message":
			chart.show_message(str(spec.get("message", "No data is available yet.")))
			return true
		"pie":
			var pie_colors: Array[Color] = []
			for color_value: Variant in spec.get("colors", []):
				pie_colors.append(accessible(color_value))
			rendered = chart.plot_pie(spec.get("categories", PackedStringArray()), spec.get("values", PackedFloat64Array()), pie_colors)
		"bars":
			rendered = plot_bars(chart, str(spec.get("y_title", "")), spec.get("categories", PackedStringArray()), spec.get("series", []), bool(spec.get("stacked", false)))
		"scatter":
			rendered = plot_scatter(chart, str(spec.get("x_title", "TICK")), str(spec.get("y_title", "")), spec.get("series", []))
		_:
			rendered = plot_lines(chart, str(spec.get("x_title", "TICK")), str(spec.get("y_title", "")), spec.get("series", []), bool(spec.get("step", false)))
	if not rendered:
		chart.show_message("Waiting for enough live data to plot this chart")
	return true

# Helper: build a line series from the world's economy history fields.
static func history_series(history: Array[Dictionary], field: String, name: String, color: Color) -> Dictionary:
	var xs := PackedFloat64Array()
	var ys := PackedFloat64Array()
	for sample: Dictionary in history:
		xs.append(float(sample.get("tick", 0)))
		ys.append(float(sample.get(field, 0.0)))
	return {"name": name, "color": color, "xs": xs, "ys": ys}


static func price_index_series(history: Array[Dictionary], field: String, name: String, color: Color, base_price: float) -> Dictionary:
	var xs := PackedFloat64Array()
	var ys := PackedFloat64Array()
	for sample: Dictionary in history:
		xs.append(float(sample.get("tick", 0)))
		ys.append(float(sample.get(field, base_price)) * 100.0 / maxf(1.0, base_price))
	return {"name": name, "color": color, "xs": xs, "ys": ys}
