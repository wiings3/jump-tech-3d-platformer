shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0; // driven by script
uniform float zoom : hint_range(0.5, 4.0) = 1.6;
uniform float speed : hint_range(0.0, 6.0) = 2.5;
uniform vec4 tint : source_color = vec4(0.55, 0.85, 1.0, 1.0); // lightning color
uniform float vignette : hint_range(0.0, 1.0) = 0.6;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.02;
		a *= 0.55;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv - 0.5) * zoom;

	// animated turbulence
	float t = TIME * speed;
	vec2 flow = vec2(fbm(p + vec2(t, 0.0)), fbm(p + vec2(0.0, -t)));
	p += (flow - 0.5) * 0.9;

	// lightning filaments
	float n = fbm(p * 2.2);
	float bolts = smoothstep(0.62, 0.92, n) * smoothstep(0.35, 0.65, fbm(p * 4.2 + 6.7));
	bolts = pow(bolts, 2.2);

	// vignette mask (stronger at edges)
	vec2 d = abs(uv - 0.5) * 2.0;
	float edge = clamp(max(d.x, d.y), 0.0, 1.0);
	float vig = pow(edge, 1.7) * vignette;

	float a = intensity * (0.55 * bolts + 0.35 * vig);

	vec3 col = tint.rgb * (0.6 + 1.2 * bolts);
	COLOR = vec4(col, a);
}
