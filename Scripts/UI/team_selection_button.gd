class_name TeamSelectionButton
extends Button

var _tooltip_accent_color: Color = Color("69e8e4")


func set_trait_tooltip(trait_text: String, accent_color: Color) -> void:
	tooltip_text = trait_text
	_tooltip_accent_color = accent_color


func _make_custom_tooltip(for_text: String) -> Object:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_tooltip_style())

	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = for_text
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 15)
	panel.add_child(label)
	return panel


func _make_tooltip_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.05, 0.96)
	style.border_color = _tooltip_accent_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_top = 7.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 7.0
	return style
