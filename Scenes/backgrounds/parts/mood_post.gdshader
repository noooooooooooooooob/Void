// 전투 무드 화면 효과 (BattleMood 의 PostLayer/Post 에 씀). 이 층(1)보다 아래, 즉 월드(0층)에만 걸린다.
// - vignette: 화면 가장자리를 어둡게 (0 = 없음, 1 = 가장 강함)
// - split: 냉난 대비. 어두운 곳은 cool 색, 밝은 곳은 warm 색을 곱한다 (0 = 없음)
// 색수차는 픽셀 그림이 번져서 넣지 않음 (2026-11-27 시험 결과)
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vignette : hint_range(0.0, 1.0) = 0.6;
uniform float split : hint_range(0.0, 1.0) = 0.6;
uniform vec4 cool : source_color = vec4(0.88, 0.95, 1.0, 1.0);
uniform vec4 warm : source_color = vec4(1.0, 0.95, 0.82, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	vec3 c = texture(screen_tex, uv).rgb;
	// 냉난 대비: 밝기에 따라 차가운 색 → 따뜻한 색을 곱함
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c *= mix(vec3(1.0), mix(cool.rgb, warm.rgb, smoothstep(0.15, 0.7, l)), split);
	// 비네트: 가운데에서 멀수록 어둡게 (가로로 조금 넓게)
	c *= mix(1.0, 1.0 - smoothstep(0.3, 0.85, length(d * vec2(1.0, 0.8))), vignette);
	COLOR = vec4(c, 1.0);
}
