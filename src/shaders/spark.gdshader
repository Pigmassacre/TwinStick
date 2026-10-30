shader_type spatial;
// Bits and sparks: upright little squares, lit or (by INSTANCE_CUSTOM.y) shining by themselves.
//   INSTANCE_CUSTOM: x its size in pixels; y its shine
render_mode cull_disabled, specular_disabled, shadows_disabled, skip_vertex_transform;
#include "res://src/shaders/lit.gdshaderinc"

varying float shine;

void vertex() {
	float s = INSTANCE_CUSTOM.x;
	vec3 world = MODEL_MATRIX[3].xyz + vec3(VERTEX.x * s, VERTEX.y * s / 0.6, 0.0);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
	shine = INSTANCE_CUSTOM.y;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * shine;
}

void light() {
	DIFFUSE_LIGHT += LIGHT_COLOR * stepped(ATTENUATION, FRAGCOORD.xy, 5.0);
}
