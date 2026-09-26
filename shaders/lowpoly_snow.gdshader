// Shared material for all low-poly world geometry.
// Per-object colour comes from instance uniforms, so every block shares one material.
// Snow settles on up-facing surfaces according to the global `snow_amount` (0..1),
// driven by WorldState.snow_level + current snowfall (see WeatherManager).
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

global uniform float snow_amount;

instance uniform vec4 albedo : source_color = vec4(0.55, 0.56, 0.6, 1.0);
// 0 = never snowy (interiors), 1 = full exposure.
instance uniform float snow_mask = 1.0;
instance uniform float emission_strength = 0.0;
// 0..1 dithered fade used when an object hides the player from the camera.
instance uniform float fade = 0.0;

uniform vec3 snow_color : source_color = vec3(0.84, 0.88, 0.95);

varying vec3 world_normal;
varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int idx = i.x + i.y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[idx] + 0.5) / 16.0;
}

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (fade > 0.001 && bayer4(FRAGCOORD.xy) < fade) {
		discard;
	}
	float up = clamp(world_normal.y, 0.0, 1.0);
	float grain = hash(floor(world_pos.xz * 1.5)) - 0.5;
	float coverage = clamp(snow_amount * 1.4 + grain * 0.25, 0.0, 1.0) * snow_mask;
	float top = smoothstep(0.45, 0.8, up) * coverage;
	// Drifts creep up the base of walls as snow accumulates.
	float base_drift = (1.0 - up) * smoothstep(snow_amount * 0.9 + 0.02, 0.0, world_pos.y) * snow_mask * step(0.05, snow_amount);
	float s = clamp(max(top, base_drift * 0.9), 0.0, 1.0);
	vec3 col = albedo.rgb * (0.94 + grain * 0.12);
	ALBEDO = mix(col, snow_color, s);
	ROUGHNESS = mix(0.92, 0.75, s);
	SPECULAR = 0.2;
	EMISSION = albedo.rgb * emission_strength;
}
