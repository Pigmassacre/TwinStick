shader_type spatial;
// An upright sprite. Lit by how near the light is, not by which way it faces,
// so that nothing goes black just for standing north of the lamp.
render_mode cull_disabled, specular_disabled, shadows_disabled;
#include "res://src/shaders/lit.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform sampler2D glow_tex : source_color, filter_nearest, repeat_disable;
uniform float bands = 6.0;
uniform float always_lit = 0.0;

uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
// Colour to flash to (its alpha is how much): being hit, a wind-up.
uniform vec4 flash = vec4(1.0, 1.0, 1.0, 0.0);
uniform float flip = 0.0;
// Tint of the sprite, and how much of it has dissolved away.
uniform vec4 tint = vec4(1.0, 1.0, 1.0, 1.0);
uniform float dissolve = 0.0;

void fragment() {
	vec2 uv = UV;
	if (flip > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	uv = uv_rect.xy + uv * uv_rect.zw;
	vec4 c = texture(albedo_tex, uv);
	float a = c.a * tint.a;
	if (dissolve > 0.0 && dissolve > bayer(FRAGCOORD.xy)) {
		a = 0.0;
	}
	if (a < 0.5) {
		discard;
	}
	vec3 rgb = mix(c.rgb * tint.rgb, flash.rgb, flash.a);
	if (always_lit > 0.5) {
		ALBEDO = vec3(0.0);
		EMISSION = rgb;
	} else {
		ALBEDO = rgb;
		EMISSION = texture(glow_tex, uv).rgb + flash.rgb * flash.a;
	}
}

void light() {
	DIFFUSE_LIGHT += LIGHT_COLOR * 0.72 * stepped(falloff(ATTENUATION), FRAGCOORD.xy, bands);
}
