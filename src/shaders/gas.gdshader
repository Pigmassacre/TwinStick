shader_type spatial;
// Firedamp: a shimmer of dithered pixels hanging in the air, thick where the gas is.
//   INSTANCE_CUSTOM.x how much gas; y how far it has lit (1 burning)
render_mode cull_disabled, unshaded, shadows_disabled;
#include "res://src/shaders/lit.gdshaderinc"

uniform vec4 gas_color : source_color = vec4(0.62, 0.86, 0.42, 1.0);
uniform vec4 gas_edge : source_color = vec4(0.28, 0.5, 0.26, 1.0);

varying float amount;
varying vec2 world_xz;

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1, 0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0, 1), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1, 1), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	amount = INSTANCE_CUSTOM.x;
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float t = TIME * 0.45;
	vec2 p = world_xz * 0.035;
	float n = noise(p + vec2(t, t * 0.6)) * 0.6 + noise(p * 2.3 - vec2(t * 1.3, 0.0)) * 0.4;
	float d = amount * (0.35 + n * 0.8);
	if (d * 0.62 < bayer(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = mix(gas_edge.rgb, gas_color.rgb, smoothstep(0.35, 0.9, d));
}
