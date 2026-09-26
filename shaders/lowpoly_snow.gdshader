// Shared material for all low-poly world geometry.
// Colour comes from vertex COLOR.rgb (merged meshes, see MeshBuilder), snow exposure from
// COLOR.a (0 = never snowy, e.g. interiors) and emission strength from UV2.x.
// Snow settles on up-facing surfaces according to the global `snow_amount` (0..1),
// driven by WorldState.snow_level + current snowfall (see WeatherManager).
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

global uniform float snow_amount;

// Dithered fade (0..1). LowPolyBlock keeps one material per fade step and swaps them,
// so no per-instance shader variables are needed (works on every renderer).
uniform float fade = 0.0;

uniform vec3 snow_color : source_color = vec3(0.84, 0.88, 0.95);

varying vec3 world_normal;
varying vec3 world_pos;
varying vec4 vcol;
varying float vemit;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

// Sine-free hash (stable at large world coordinates on every GPU).
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
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
	vcol = COLOR;
	vemit = UV2.x;
}

void fragment() {
	vec3 base = srgb_to_linear(vcol.rgb);
	float snow_mask = vcol.a;
	if (fade > 0.001 && bayer4(FRAGCOORD.xy) < fade) {
		discard;
	}
	float up = clamp(world_normal.y, 0.0, 1.0);
	float grain = hash(floor(world_pos.xz * 2.0)) - 0.5;
	float coverage = clamp(snow_amount * 1.4 + grain * 0.12, 0.0, 1.0) * snow_mask;
	float top = smoothstep(0.45, 0.8, up) * coverage;
	// Drifts creep up the base of walls as snow accumulates.
	float base_drift = (1.0 - up) * smoothstep(snow_amount * 0.9 + 0.02, 0.0, world_pos.y) * snow_mask * step(0.05, snow_amount);
	float s = clamp(max(top, base_drift * 0.9), 0.0, 1.0);
	vec3 col = base * (0.96 + grain * 0.08);
	ALBEDO = mix(col, snow_color, s);
	ROUGHNESS = mix(0.92, 0.75, s);
	SPECULAR = 0.2;
	EMISSION = base * vemit;
}
