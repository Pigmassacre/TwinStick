shader_type spatial;
// The long shadow something throws across the floor, away from the lamp: its own
// sprite, lying flat, dithered thinner the further the lamp is.
render_mode cull_disabled, unshaded, shadows_disabled;
#include "res://src/shaders/lit.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;

uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float flip = 0.0;
uniform float strength = 1.0;

void fragment() {
	vec2 uv = UV;
	if (flip > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	uv = uv_rect.xy + uv * uv_rect.zw;
	if (texture(albedo_tex, uv).a < 0.5 || bayer(FRAGCOORD.xy) > strength * (0.35 + 0.65 * UV.y)) {
		discard;
	}
	ALBEDO = vec3(0.0);
}
