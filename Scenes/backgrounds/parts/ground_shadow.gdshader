// 바닥 그림자 (GroundShadow). 그림의 모양(알파)만 쓰고 색은 shadow_color 로 칠한다.
// 발밑(foot_y)에서 그림 맨 위(top_y)로 갈수록 fade 만큼 옅어진다 — 그림자 끝이 흐려 보이게.
// 값은 모두 인스턴스 값이라 재질 하나를 모든 그림자가 같이 쓴다 (GroundShadow 스크립트가 넣음).
shader_type canvas_item;

// 그림자 색. 알파 = 진하기
instance uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);
// 끝으로 갈수록 옅어지는 정도 (0 = 끝까지 같음, 1 = 끝에서 사라짐)
instance uniform float fade = 0.6;
// 대상 기준 좌표에서 발밑·그림 맨 위의 y (눕히기 전)
instance uniform float foot_y = 0.0;
instance uniform float top_y = -100.0;

varying float local_y;

void vertex() {
	// VERTEX 는 노드 변환 전 좌표 = 그림 안 높이
	local_y = VERTEX.y;
}

void fragment() {
	float a = texture(TEXTURE, UV).a;
	float t = clamp((foot_y - local_y) / max(foot_y - top_y, 0.001), 0.0, 1.0);
	COLOR = vec4(shadow_color.rgb, shadow_color.a * a * (1.0 - fade * t));
}
