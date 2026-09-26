// Full-screen overlay: frost vignette (cold), red pulse (low health), stress darkening,
// snow flakes hitting the lens during blizzards, contamination tint, white-out haze and
// quick white flashes.
shader_type canvas_item;

uniform float cold = 0.0;
uniform float hurt = 0.0;
uniform float stress = 0.0;
uniform float lens_snow = 0.0;
uniform float flash = 0.0;
uniform float toxic = 0.0;
uniform float whiteout = 0.0;
uniform float time_offset = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Smooth value noise for drifting haze.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 c = uv - 0.5;
	float r = length(c * vec2(1.6, 1.0));
	float vig = smoothstep(0.35, 0.95, r);
	vec4 col = vec4(0.0);
	// Frost: blue-white crystalline edge.
	float crystals = hash(floor(uv * vec2(160.0, 90.0)));
	float frost = vig * cold * (0.55 + crystals * 0.45);
	col = mix(col, vec4(0.78, 0.88, 1.0, 1.0), clamp(frost, 0.0, 0.85));
	// Hurt: pulsing red edge.
	float pulse = 0.65 + 0.35 * sin(TIME * 5.0);
	col = mix(col, vec4(0.55, 0.02, 0.02, 1.0), clamp(vig * hurt * pulse, 0.0, 0.8));
	// Stress: dark tunnel.
	col = mix(col, vec4(0.0, 0.0, 0.02, 1.0), clamp(smoothstep(0.25, 1.0, r) * stress * 0.7, 0.0, 0.7));
	// Lens snow: sparse soft dots that drift slowly.
	vec2 grid = uv * vec2(24.0, 13.5) + vec2(time_offset * 0.15, -time_offset * 0.05);
	vec2 cell = floor(grid);
	vec2 f = fract(grid) - 0.5;
	float h = hash(cell);
	float flake = step(0.9, h) * smoothstep(0.22, 0.05, length(f - (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.5));
	col = mix(col, vec4(0.95, 0.97, 1.0, 1.0), clamp(flake * lens_snow * (0.4 + vig), 0.0, 0.9));
	// Contamination: a sick yellow-green seeping in from the edges, breathing slowly.
	float sick = smoothstep(0.2, 0.9, r) * toxic * (0.75 + 0.25 * sin(TIME * 2.3));
	col = mix(col, vec4(0.42, 0.5, 0.12, 1.0), clamp(sick * 0.65, 0.0, 0.6));
	// White-out: drifting milky haze, thicker at the edges so the centre stays readable.
	vec2 wp = uv * vec2(5.0, 3.0) + vec2(time_offset * 0.9, time_offset * 0.25);
	float drift = vnoise(wp) * 0.6 + vnoise(wp * 2.3 + 7.0) * 0.4;
	float haze = whiteout * (0.12 + drift * 0.14 + smoothstep(0.2, 1.0, r) * 0.3);
	col = mix(col, vec4(0.9, 0.93, 0.97, 1.0), clamp(haze, 0.0, 0.5));
	col = mix(col, vec4(1.0, 0.98, 0.9, 1.0), clamp(flash, 0.0, 1.0));
	COLOR = col;
}
