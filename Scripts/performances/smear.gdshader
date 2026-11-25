// 스머지(스미어) 셰이더 — 그림을 지나온 쪽으로 늘린다 (줄무늬 또는 전체 고르게, 몸 뒤 또는 앞까지).
// smear_driver.gd 가 부모 그림(AnimatedSprite2D)에 붙이고 smear 값을 매 프레임 넣는다.
// 원리: 메시 스미어(godotshaders.com/shader/mesh-smearing)를 2D 로 — 꼭짓점 대신 픽셀이
// "이동 방향 앞쪽"의 그림 색을 끌어와 지나온 자리에 꼬리가 남는다.
// 기본(2026-11-25 사용자 선택): 전체 고르게(min_length 1) + 평균(부드러운 블러) + 몸 앞 0.2. 줄무늬는 min_length < 1, average 끔
shader_type canvas_item;

// 꼬리 벡터 (그림 픽셀 단위, 지금 위치 → 지나온 쪽). 0 이면 효과 없음
uniform vec2 smear = vec2(0.0);
// 그림 사각형을 사방으로 넓히는 여백 (그림 픽셀). 꼬리가 그림 밖으로 나갈 수 있게. smear 길이 이상이어야 함
uniform float pad = 600.0;
// 줄무늬 굵기 (그림 픽셀, 이동에 수직 방향)
uniform float streak_width = 24.0;
// 꼬리 길이의 최소 비율 (줄무늬마다 이 값 ~ 1 사이로 길이가 다름). 1 = 줄무늬 없이 그림 전체가 고르게
uniform float min_length = 1.0;
// 꼬리 끝으로 갈수록 투명해지는 정도 (0 = 안 흐려짐)
uniform float fade = 0.6;
// 꼬리를 따라 몇 번 짚어 볼지 (많을수록 매끈, 무거움)
uniform int samples = 12;
// 꼬리를 몸 앞에도 덮는 정도. 0 = 몸 뒤(빈 곳)에만, 1 = 몸 위를 완전히 덮음 (몸이 늘어난 것처럼)
uniform float front_amount : hint_range(0.0, 1.0) = 0.2;
// 짚는 위치를 화면 픽셀마다 흩뜨리는 정도 (0~1). 일정한 간격으로 찍힌 사본이 계단처럼 보이는 것을 가린다
uniform float dither : hint_range(0.0, 1.0) = 0.0;
// true = 짚은 색의 평균 (부드러운 블러), false = 가장 진한 하나 (또렷한 줄·사본)
uniform bool average = true;
// 평균일 때 꼬리 불투명도 배율 (평균은 그림이 걸린 비율만큼만 진해서 옅어 보이므로)
uniform float average_gain = 2.0;
// 지금 프레임이 그리는 영역 (텍스처 UV 기준 x, y, 너비, 높이). 아틀라스 프레임이면 그 칸만 — 옆 프레임을 꼬리로 읽지 않게.
// smear_driver.gd 가 매 프레임 넣는다 (SmearDriver.frame_region)
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);

varying vec2 tex_size;
// 넓힌 UV. fragment 의 UV 는 엔진이 그림 영역(0~1)으로 잘라 버려서(clip_uv) 여백에 가장자리 줄이 늘어지므로 따로 넘긴다
varying vec2 uv_ext;
varying vec4 tint;  // 꼭짓점 색 (modulate). fragment 의 COLOR 는 이미 원래 UV 의 그림 색이 곱해져 있어 따로 받는다

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	// 1. 그림 사각형을 사방으로 pad 만큼 넓히고, UV 도 같은 만큼 바깥으로 (영역 밖은 fragment 에서 투명).
	//    방향은 프레임 영역의 가운데 기준 (아틀라스면 UV 가 그 칸 범위라서)
	vec2 dir = sign(UV - (region.xy + region.zw * 0.5));
	VERTEX += dir * pad;
	UV += dir * pad * TEXTURE_PIXEL_SIZE;
	uv_ext = UV;
	tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	tint = COLOR;
}

// uv 가 지금 프레임 영역 안이면 1, 밖이면 0. (TEXTURE 는 함수 인자로 못 넘겨서 샘플은 fragment 에서 하고 이 값을 곱한다)
float inside(vec2 uv) {
	vec2 lo = region.xy;
	vec2 hi = region.xy + region.zw;
	return step(lo.x, uv.x) * step(lo.y, uv.y) * step(uv.x, hi.x) * step(uv.y, hi.y);
}

void fragment() {
	vec2 uv = uv_ext;
	vec4 col = texture(TEXTURE, uv) * inside(uv);
	float len = length(smear);
	if (len > 0.5) {
		// 2. 줄무늬 번호: 이동에 수직인 축으로 잘라, 줄마다 꼬리 길이를 다르게
		vec2 d = smear / len;
		vec2 perp = vec2(-d.y, d.x);
		float stripe = floor(dot(uv * tex_size, perp) / streak_width);
		float k_max = mix(min_length, 1.0, hash(stripe));
		// 3. 앞쪽(지나온 쪽 반대)으로 짚어 가며, 그림이 걸리면 그 색을 꼬리로 (가까울수록 진하게).
		//    짚는 위치는 화면 픽셀마다 한 칸 안에서 흩뜨린다 (dither)
		float jitter = hash2(FRAGCOORD.xy) * dither;
		vec4 trail = vec4(0.0);
		vec3 sum_rgb = vec3(0.0);  // 평균용: 색 × 불투명도의 합
		float sum_a = 0.0;          // 평균용: 불투명도의 합
		for (int i = 1; i <= samples; i++) {
			float k = (float(i) - jitter) / float(samples) * k_max;
			vec2 su = uv - smear * k * TEXTURE_PIXEL_SIZE;
			vec4 s = texture(TEXTURE, su) * inside(su);
			s.a *= 1.0 - fade * (k / k_max);
			sum_rgb += s.rgb * s.a;
			sum_a += s.a;
			if (s.a > trail.a) {
				trail = s;
			}
		}
		// 평균: 짚은 색을 고르게 섞어 부드러운 모션 블러로 (가장 진한 하나를 고르면 계단·줄이 남는다)
		if (average) {
			trail = sum_a > 0.0 ? vec4(sum_rgb / sum_a, min(sum_a / float(samples) * average_gain, 1.0)) : vec4(0.0);
		}
		// 4. 몸 뒤: 몸을 꼬리 위에 얹는다 (몸이 비치는 곳만 꼬리가 보임).
		//    몸 앞: 몸이 있는 곳에도 꼬리 색을 front_amount 만큼 덮는다
		vec4 body = col;
		float out_a = body.a + trail.a * (1.0 - body.a);
		if (out_a > 0.0) {
			col.rgb = (body.rgb * body.a + trail.rgb * trail.a * (1.0 - body.a)) / out_a;
		}
		col.a = out_a;
		col.rgb = mix(col.rgb, trail.rgb, trail.a * front_amount * body.a);
	}
	COLOR = col * tint;
}
