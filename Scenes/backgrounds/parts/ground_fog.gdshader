// 바닥 안개 (ground_fog.tscn). 노이즈 텍스처를 가로로 천천히 흘려서 안개가 움직이는 것처럼 보이게 한다.
// 색·진하기는 노드 modulate (색 = rgb, 진하기 = a). 노이즈는 어디가 진한지만 정한다.
// 텍스처는 seamless 이고 노드의 texture_repeat 가 켜져 있어야 이어진다.
// - speed: 초당 흐르는 양 (UV 단위, 음수면 반대 방향)
// - edge: 위·아래 가장자리를 부드럽게 사라지게 하는 폭 (UV 단위)
shader_type canvas_item;
render_mode unshaded;

uniform float speed = 0.01;
uniform float edge : hint_range(0.0, 0.5) = 0.35;

varying vec4 tint; // 노드 modulate

void vertex() {
	tint = COLOR;
}

void fragment() {
	float n = texture(TEXTURE, vec2(UV.x + TIME * speed, UV.y)).r;
	// 띠의 위·아래 끝은 투명하게
	float fade = smoothstep(0.0, edge, UV.y) * smoothstep(0.0, edge, 1.0 - UV.y);
	COLOR = vec4(tint.rgb, tint.a * n * fade);
}
