shader_type spatial;
// The walls and floors: the tile atlas under the lamp, normal-mapped.
render_mode cull_back, specular_disabled, shadows_disabled;
#include "res://src/shaders/lit.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_nearest, repeat_disable;
uniform sampler2D emission_tex : source_color, filter_nearest, repeat_disable;
uniform float emission_energy = 1.0;
uniform float bands = 7.0;

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	ALBEDO = c.rgb * COLOR.rgb;
	NORMAL_MAP = texture(normal_tex, UV).xyz;
	NORMAL_MAP_DEPTH = 1.0;
	EMISSION = texture(emission_tex, UV).rgb * emission_energy;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float v = falloff(ATTENUATION) * pow(ndl, 0.55);
	DIFFUSE_LIGHT += LIGHT_COLOR * stepped(v, FRAGCOORD.xy, bands);
}
