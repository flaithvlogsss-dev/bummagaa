// Shared material for all low-poly world geometry.
// Colour comes from vertex COLOR.rgb (merged meshes, see MeshBuilder), snow exposure from
// COLOR.a (0 = never snowy, e.g. interiors), emission strength from UV2.x and the surface
// material (a layer of the WorldTextures array) from UV2.y. Material tiles are detail maps
// (0.5 = keep the colour) box-projected in world space, so they never stretch.
// Snow settles on up-facing surfaces according to the global `snow_amount` (0..1),
// driven by WorldState.snow_level + current snowfall (see WeatherManager).
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

global uniform float snow_amount;

// Dithered fade (0..1). LowPolyBlock keeps one material per fade step and swaps them,
// so no per-instance shader variables are needed (works on every renderer).
uniform float fade = 0.0;

uniform vec3 snow_color : source_color = vec3(0.76, 0.8, 0.88);
// Raw (linear) detail values: 0.5 means "unchanged".
uniform sampler2DArray world_tex : filter_nearest_mipmap, repeat_enable;
uniform float texels_per_metre = 16.0;
const float SNOW_LAYER = 3.0;
const float TILE = 32.0;

varying vec3 world_normal;
varying vec3 world_pos;
varying vec4 vcol;
varying float vemit;
varying float vmat;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

// Sine-free hash (stable at large world coordinates on every GPU).
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
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
	vmat = UV2.y;
}

// Box projection: floors use XZ, walls use their facing plane with V pointing down.
vec2 project_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	vec2 uv;
	if (a.y >= a.x && a.y >= a.z) {
		uv = p.xz;
	} else if (a.x >= a.z) {
		uv = vec2(p.z, -p.y);
	} else {
		uv = vec2(p.x, -p.y);
	}
	return uv * texels_per_metre / TILE;
}

void fragment() {
	vec3 base = srgb_to_linear(vcol.rgb);
	float snow_mask = vcol.a;
	if (fade > 0.001 && bayer4(FRAGCOORD.xy) < fade) {
		discard;
	}
	float up = clamp(world_normal.y, 0.0, 1.0);
	float mat = floor(vmat + 0.5);
	vec3 detail = vec3(1.0);
	if (mat > 0.5) {
		detail = texture(world_tex, vec3(project_uv(world_pos, world_normal), mat)).rgb * 2.0;
	}
	vec3 snow_detail = texture(world_tex, vec3(world_pos.xz * texels_per_metre / TILE, SNOW_LAYER)).rgb * 2.0;
	// Snow lies in patches: a low-frequency field, quantised to the texel grid, is compared
	// with the coverage so light snow leaves bare ground between drifts.
	vec2 cell = floor(world_pos.xz * texels_per_metre / 2.0) * 2.0 / texels_per_metre;
	float patch = vnoise(cell * 0.45) * 0.6 + vnoise(cell * 1.7 + 11.0) * 0.4;
	float cover = snow_amount * 2.2 * snow_mask;
	float drifts = smoothstep(1.0 - cover - 0.18, 1.0 - cover + 0.18, patch);
	float dusting = (0.3 + 0.35 * clamp(cover, 0.0, 1.0)) * step(0.01, snow_mask);
	float coverage = max(drifts, dusting) * step(0.01, snow_mask);
	float top = smoothstep(0.45, 0.8, up) * coverage;
	// Drifts creep up the base of walls as snow accumulates.
	float base_drift = (1.0 - up) * smoothstep(snow_amount * 0.9 + 0.02, 0.0, world_pos.y) * snow_mask * step(0.05, snow_amount);
	float s = clamp(max(top, base_drift * 0.9), 0.0, 1.0);
	vec3 col = base * detail;
	ALBEDO = mix(col, snow_color * snow_detail, s);
	ROUGHNESS = mix(0.92, 0.75, s);
	SPECULAR = 0.2;
	EMISSION = base * vemit;
}
