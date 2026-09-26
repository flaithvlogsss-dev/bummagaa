// Full-screen overlay: frost vignette (cold), red pulse (low health), stress darkening,
// snow flakes hitting the lens during blizzards, and quick white flashes.
shader_type canvas_item;

uniform float cold = 0.0;
uniform float hurt = 0.0;
uniform float stress = 0.0;
uniform float lens_snow = 0.0;
uniform float flash = 0.0;
uniform float time_offset = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
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
	col = mix(col, vec4(1.0, 0.98, 0.9, 1.0), clamp(flash, 0.0, 1.0));
	COLOR = col;
}
