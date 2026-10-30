shader_type spatial;
// A pool of shadow on the floor, dithered.
render_mode cull_disabled, unshaded, shadows_disabled, depth_draw_never;
#include "res://src/shaders/lit.gdshaderinc"

void fragment() {
	vec2 d = (UV - vec2(0.5)) * 2.0;
	float v = 1.0 - dot(d, d);
	if (v * 1.6 < bayer(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = vec3(0.0);
}
