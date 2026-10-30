shader_type spatial;
// Everything flying: drawn together, unlit, and over the walls (nobody is to
// lose a shot in the dark), each turned on the screen by its custom data.
//   INSTANCE_CUSTOM: x, y its frame in the sheet; z its angle; w its scale
render_mode cull_disabled, unshaded, shadows_disabled, skip_vertex_transform, depth_test_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform vec2 frame_uv = vec2(0.125, 0.125);

varying vec2 sheet_uv;

void vertex() {
	float c = cos(INSTANCE_CUSTOM.z);
	float s = sin(INSTANCE_CUSTOM.z);
	vec2 v = VERTEX.xy * INSTANCE_CUSTOM.w;
	vec2 turned = vec2(v.x * c - v.y * s, v.x * s + v.y * c);
	// Upright in the world, stretched by the cos of the camera so it is square on the screen.
	vec3 world = MODEL_MATRIX[3].xyz + vec3(turned.x, turned.y / 0.6, 0.0);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
	sheet_uv = (INSTANCE_CUSTOM.xy + UV) * frame_uv;
}

void fragment() {
	vec4 c = texture(albedo_tex, sheet_uv);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb;
	ALPHA = 1.0;
}
