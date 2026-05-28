shader_type canvas_item;

uniform float speedScale = 16.0;
uniform float clipPosition = 0.2;
uniform float line_alpha : hint_range(0.0, 1.0) = 0.0;
uniform float line_density : hint_range(0.001, 0.1) = 0.02;

float random(vec2 uv) {
	return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	COLOR.a = 0.0;

	vec2 pos = UV - vec2(0.5);
	float theta = round(64.0 * atan(pos.y, pos.x));
	float dist = sqrt(pow(pos.x, 2.0) + pow(pos.y, 2.0));
	float distValue = round(dist * 4.0 + TIME * -speedScale + 8.0 * random(vec2(theta)));

	if (dist > clipPosition + random(vec2(theta)) * 0.3 && random(vec2(theta, distValue)) < line_density) {
		COLOR.a = line_alpha;
	}
}