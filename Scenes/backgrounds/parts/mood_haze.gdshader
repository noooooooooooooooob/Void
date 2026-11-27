// 공기원근 (BattleMood.haze_material). 먼 배경 그림을 haze 색 쪽으로 섞고 살짝 흐리게 해서 멀어 보이게 한다.
// - amount: haze 색을 섞는 비율 (0 = 원래 그림)
// - blur: 주변 픽셀을 섞는 거리 (텍스처 픽셀 단위, 0 = 흐림 없음)
shader_type canvas_item;

uniform vec4 haze : source_color = vec4(0.35, 0.4, 0.6, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.35;
uniform float blur : hint_range(0.0, 4.0) = 1.5;

varying vec4 tint; // 노드 modulate (fragment 의 COLOR 에는 텍스처 색이 이미 곱해져 있어 따로 받는다)

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur;
	// 가운데 + 상하좌우 네 점을 섞는 가벼운 흐림
	vec4 c = texture(TEXTURE, UV) * 0.4
		+ (texture(TEXTURE, UV + vec2(px.x, 0.0)) + texture(TEXTURE, UV - vec2(px.x, 0.0))
		+ texture(TEXTURE, UV + vec2(0.0, px.y)) + texture(TEXTURE, UV - vec2(0.0, px.y))) * 0.15;
	COLOR = vec4(mix(c.rgb, haze.rgb, amount), c.a) * tint;
}
