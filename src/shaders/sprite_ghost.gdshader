shader_type spatial;
// The ranger, where a wall is in the way: a dithered outline of them, seen through it.
render_mode cull_disabled, unshaded, shadows_disabled, depth_test_inverted, depth_draw_never;
#include "res://src/shaders/lit.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform vec4 ghost_color : source_color = vec4(1.0, 0.75, 0.45, 1.0);

uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float flip = 0.0;
uniform vec4 flash = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 tint = vec4(1.0, 1.0, 1.0, 1.0);
uniform float dissolve = 0.0;

void fragment() {
	vec2 uv = UV;
	if (flip > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	uv = uv_rect.xy + uv * uv_rect.zw;
	float a = texture(albedo_tex, uv).a;
	if (a < 0.5 || bayer(FRAGCOORD.xy) > 0.6) {
		discard;
	}
	ALBEDO = ghost_color.rgb;
	ALPHA = 1.0;
}
