class_name RoadsideRenderer
extends Node2D

const GameConfig = preload("res://scripts/game_config.gd")
const VisualStyle = preload("res://scripts/visual_style.gd")
const EnvironmentScroller = preload("res://scripts/environment_scroller.gd")

const SHARPEN_SHADER := """
shader_type canvas_item;

uniform float sharpness : hint_range(0.0, 0.6) = 0.25;

void fragment() {
	vec4 tint = COLOR;
	vec4 center = texture(TEXTURE, UV);
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	vec3 neighbours = (
		texture(TEXTURE, UV + vec2(pixel.x, 0.0)).rgb
		+ texture(TEXTURE, UV - vec2(pixel.x, 0.0)).rgb
		+ texture(TEXTURE, UV + vec2(0.0, pixel.y)).rgb
		+ texture(TEXTURE, UV - vec2(0.0, pixel.y)).rgb
	) * 0.25;
	vec3 sharpened = clamp(center.rgb + (center.rgb - neighbours) * sharpness, vec3(0.0), vec3(1.0));
	COLOR = vec4(sharpened, center.a) * tint;
}
"""

var source_main: Node2D
var _shader_material: ShaderMaterial

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -100
	z_as_relative = false
	var shader := Shader.new()
	shader.code = SHARPEN_SHADER
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	material = _shader_material

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if source_main == null or source_main.run == null:
		return
	draw_set_transform(source_main.screen_shake)
	var viewport_size := get_viewport_rect().size
	var center_x := viewport_size.x * 0.5
	var road_left := center_x - GameConfig.ROAD_HALF_WIDTH
	var road_right := center_x + GameConfig.ROAD_HALF_WIDTH
	var ocean_color := VisualStyle.HIGH_CONTRAST_OCEAN if source_main.high_contrast_enabled else VisualStyle.OCEAN
	draw_rect(Rect2(Vector2.ZERO, viewport_size), ocean_color)
	_draw_environment(road_left, road_right, viewport_size)
	draw_set_transform(Vector2.ZERO)

func _draw_environment(road_left: float, road_right: float, viewport_size: Vector2) -> void:
	var left_textures: Array = source_main.current_environment_left
	var right_textures: Array = source_main.current_environment_right
	if left_textures.is_empty() or right_textures.is_empty():
		return
	_shader_material.set_shader_parameter("sharpness", clampf(float(source_main.current_track.get("environment_sharpness", 0.25)), 0.0, 0.6))
	var side_modulate := Color(0.58, 0.58, 0.58, 1.0) if source_main.high_contrast_enabled else Color.WHITE
	var left_width := maxf(0.0, road_left - 30.0)
	var right_start := road_right + 30.0
	var right_width := maxf(0.0, viewport_size.x - right_start)
	var tile_height := float(left_textures[0].get_height())
	var finish_distance: float = source_main.run.progression.finish_distance
	var sequence_tiles := EnvironmentScroller.sequence_tiles(source_main.run.distance, finish_distance, viewport_size.y, tile_height, left_textures.size())
	for tile in sequence_tiles:
		var tile_y := pixel_aligned_y(float(tile.y))
		var texture_index := int(tile.index)
		var left_texture: Texture2D = left_textures[texture_index]
		var right_texture: Texture2D = right_textures[mini(texture_index, right_textures.size() - 1)]
		if left_width > 0.0:
			var left_source_width := visible_source_width(left_width, float(left_texture.get_width()))
			var left_source := Rect2(left_texture.get_width() - left_source_width, 0.0, left_source_width, tile_height)
			draw_texture_rect_region(left_texture, Rect2(left_width - left_source_width, tile_y, left_source_width, tile_height), left_source, side_modulate)
		if right_width > 0.0:
			var right_source_width := visible_source_width(right_width, float(right_texture.get_width()))
			var right_source := Rect2(0.0, 0.0, right_source_width, tile_height)
			draw_texture_rect_region(right_texture, Rect2(right_start, tile_y, right_source_width, tile_height), right_source, side_modulate)

static func pixel_aligned_y(value: float) -> float:
	return roundf(value)

static func visible_source_width(side_width: float, texture_width: float) -> float:
	return minf(maxf(0.0, side_width), maxf(0.0, texture_width))
