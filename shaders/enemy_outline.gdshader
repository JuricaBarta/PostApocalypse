shader_type canvas_item;
uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float outline_size = 10.0;
void fragment() {
	vec2 size = outline_size * TEXTURE_PIXEL_SIZE;
	vec4 col = texture(TEXTURE, UV);

	float a = 0.0;
	a = max(a, texture(TEXTURE, UV + vec2(size.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV - vec2(size.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, size.y)).a);
	a = max(a, texture(TEXTURE, UV - vec2(0.0, size.y)).a);
	a = max(a, texture(TEXTURE, UV + size).a);
	a = max(a, texture(TEXTURE, UV - size).a);
	a = max(a, texture(TEXTURE, UV + vec2(size.x, -size.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(-size.x, size.y)).a);

	float is_outline = a * (1.0 - col.a);
	COLOR = vec4(outline_color.rgb, is_outline);
}
