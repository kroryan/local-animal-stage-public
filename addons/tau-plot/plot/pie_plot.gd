extends Control

## Compact native pie renderer used by TauPlot's plot_pie() API.
## Values below zero are ignored because they cannot represent a sector share.

var categories := PackedStringArray()
var values := PackedFloat64Array()
var colors: Array[Color] = []


func setup(p_categories: PackedStringArray, p_values: PackedFloat64Array, p_colors: Array[Color]) -> void:
	categories = p_categories.duplicate()
	values = p_values.duplicate()
	colors = p_colors.duplicate()
	queue_redraw()


func _draw() -> void:
	var total := 0.0
	for value: float in values:
		total += maxf(0.0, value)
	var compact := size.x < 390.0
	var radius := minf(size.y * (0.4 if compact else 0.43), size.x * (0.25 if compact else 0.25))
	var center := Vector2(size.x * (0.5 if compact else 0.29), radius + 10.0 if compact else size.y * 0.52)
	var font := get_theme_default_font()
	var font_size := 13 if compact else 14
	if total <= 0.0:
		font.draw_string(get_canvas_item(), Vector2(maxf(8.0, size.x * 0.5 - 48.0), size.y * 0.52), "No invested assets", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("aebdca"))
		return
	var start_angle := -PI * 0.5
	for index: int in range(mini(categories.size(), values.size())):
		var value := maxf(0.0, values[index])
		if value <= 0.0:
			continue
		var sweep := TAU * value / total
		var points := PackedVector2Array([center])
		var segments := maxi(3, ceili(sweep * 20.0))
		for segment: int in range(segments + 1):
			var angle := start_angle + sweep * float(segment) / float(segments)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, colors[index % colors.size()] if not colors.is_empty() else Color("58d7ef"))
		start_angle += sweep
	var legend_x := 10.0 if compact else size.x * 0.56
	var legend_y := radius * 2.0 + 22.0 if compact else size.y * 0.25
	var line_height := 22.0 if compact else 24.0
	var legend_width := size.x - legend_x - 8.0
	for index: int in range(mini(categories.size(), values.size())):
		var value := maxf(0.0, values[index])
		if value <= 0.0:
			continue
		var color := colors[index % colors.size()] if not colors.is_empty() else Color("58d7ef")
		var row := Vector2(legend_x, legend_y + line_height * float(index))
		draw_rect(Rect2(row, Vector2(11.0, 11.0)), color, true)
		var percent := value * 100.0 / total
		var label := "%s · %.1f%%" % [categories[index].left(18 if compact else 24), percent]
		font.draw_string(get_canvas_item(), row + Vector2(17.0, 11.0), label, HORIZONTAL_ALIGNMENT_LEFT, legend_width - 18.0, font_size, Color("d4e0e9"))
	if compact:
		custom_minimum_size.y = maxf(170.0, legend_y + float(mini(categories.size(), values.size())) * line_height + 8.0)
