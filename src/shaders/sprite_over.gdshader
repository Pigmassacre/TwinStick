shader_type spatial;
// Effects that go over everything: blasts, warnings on the floor.
render_mode cull_disabled, unshaded, shadows_disabled, depth_test_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;

uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 flash = vec4(1.0, 1.0, 1.0, 0.0);
uniform float flip = 0.0;
uniform vec4 tint = vec4(1.0, 1.0, 1.0, 1.0);
uniform float dissolve = 0.0;

void fragment() {
	vec2 uv = UV;
	if (flip > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	uv = uv_rect.xy + uv * uv_rect.zw;
	vec4 c = texture(albedo_tex, uv);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb * tint.rgb;
	ALPHA = 1.0;
}
