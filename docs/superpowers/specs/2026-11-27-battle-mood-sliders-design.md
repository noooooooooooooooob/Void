# 전투 무드 슬라이더 모으기 (A) — 설계 (2026-11-27)

이어받기 메모 `docs/superpowers/plans/2026-11-27-battle-mood-next-handoff.md` 의 A.

## 목적
무드 값이 석등 노드·빛줄기 꼭짓점 색·안개 modulate·셰이더 값으로 흩어져 있다. 장면 전체 분위기를 `BattleMood` 인스펙터 한 곳에서 맞추게 한다. 다음 B(시간대 프리셋)가 이 값들을 묶는다.

## 목표 / 비목표
- 목표: 빛나는 물품 밝기·헤일로, 빛줄기 세기·색·방향, 안개 색·진하기·속도, 빛 번짐 문턱을 BattleMood 에서 조절. 에디터 2D 화면에 바로 반영
- 목표: 해·달 부품을 놓으면 빛줄기가 그 위치에서 뻗어 나온다
- 목표: 빛줄기 말고는 지금 신사 정원 화면이 바뀌지 않는다 (같은 값으로 옮김)
- 비목표: 시간대 프리셋(B), 그림자(C), 물품 분류 이름(석등만 끄기 등 — B 에서 필요하면), 밤에만 켜지는 물품 (사용자: 없음)

## 방법 (사용자 결정)
- 빛나는 물품은 석등만이 아니다 → **색·범위·기본 밝기·헤일로는 물품마다**, BattleMood 는 **배율만** (광원 밝기 배율, 헤일로 배율). 시간대가 바뀌면 모든 빛이 같이 세지거나 약해진다
- 빛줄기·안개·빛 번짐은 장면에 하나라 BattleMood 가 직접 값을 가진다
- 기각: 모든 물품에 같은 값(물품마다 색이 달라야 함)

## 설계
### 빛나는 물품 `MoodLight` (`Scripts/backgrounds/mood_light.gd`, `@tool`, `extends PointLight2D`)
- 부품 `Scenes/backgrounds/parts/lantern_light.tscn` 루트에 붙임 (다른 물품은 이 부품을 복제해 값만 바꿈). 그룹 `mood_light`
- 물품 값: `light_color`(빛·헤일로 색), `brightness`(기본 밝기, 지금 2.2), `halo_strength`(지금 0.85 ≈ 예전 modulate 1.4×알파 0.6), `halo_size`(Halo 크기, 0.7). 범위는 PointLight2D 자체 `texture_scale`
- BattleMood 가 넣는 값: `mood_brightness_scale`, `mood_halo_scale` (기본 1)
- 결과: `energy = brightness × 밝기 배율`(0 이면 끔), Halo modulate = `light_color × halo_strength × 헤일로 배율`(알파 1, 더하기라 같은 모양)

### 해·달 `SkyBody` (`Scripts/backgrounds/sky_body.gd`, `@tool`, `extends Node2D`, 그룹 `mood_sky_body`) — 사용자 추가 요청
- 빛줄기는 **해의 위치에서 뻗어 나온다**, 밤에는 **달**에서 (사용자 결정 2026-11-27)
- 부품 `Scenes/backgrounds/parts/sun.tscn`, `moon.tscn` (같은 스크립트, 색·크기만 다름). 원반 Sprite2D + 더하기 헤일로, 빛을 안 받음(light_mask 0, unshaded). 배경 씬에 놓고 2D 화면에서 끌어 옮긴다
- 값: `body_color`, `body_size`, `glow_strength`(헤일로). 해는 화면 안에 보이는 것으로 둠 (레퍼런스 프레임 9 의 오른쪽 뒤 낮은 해 — 내 판단). 놓는 순서는 BattleMood 뒤·먼 산 앞 (산 뒤로 지는 해는 FarLayer 앞뒤로 순서만 바꾸면 됨)
- 옮기면(`NOTIFICATION_TRANSFORM_CHANGED`) `moved` 시그널 → BattleMood 가 빛줄기를 다시 맞춤
- 배경에 해·달이 여럿이면 **보이는 것 중 첫 번째**를 따른다 (B 에서 시간대마다 해/달 켜고 끄기). 없으면 빛줄기는 똑바로 아래로

### 빛줄기 `MoodRays` (`Scripts/backgrounds/mood_rays.gd`, `@tool`, `light_rays.tscn` 루트, 그룹 `mood_rays`)
- 빔(Polygon2D)마다 **노드 위치 = 빛이 닿는 곳**(2D 화면에서 끌어 옮김). 빔 모양은 스크립트가 해 위치 → 닿는 곳으로 채움: 해 쪽 폭 `width_near`, 닿는 곳 폭 `width_far`, 꼭짓점 색 흰색, 해 쪽 알파 1 → 닿는 곳 0. 노드를 새로 만들지는 않고 씬에 있는 빔의 polygon 값만 바꿈
- 지금 빔 4개의 닿는 곳 = 지금 아래 가운데 (1100,1000)·(840,1000)·(580,1000)·(320,1000). 폭은 지금 위·아래 폭 평균
- BattleMood: `rays_color`, `rays_strength`(노드 modulate, HDR 이라 1 넘어도 됨). 기본 색 (1, 0.8, 0.55), 세기 0.4 — HDR 켠 뒤 너무 센지 화면 확인
- 해가 들어오면서 신사 정원 빛줄기 모양은 바뀐다 (화면 확인 후 해 위치·닿는 곳을 사용자가 조정)

### 안개 (`ground_fog.tscn`, 그룹 `mood_fog`)
- 재질 `resource_local_to_scene = true` (안 하면 에디터에서 부품 원본이 바뀜)
- BattleMood: `fog_color`, `fog_density`(modulate 알파), `fog_speed`(셰이더 speed)

### 빛 번짐 문턱
- BattleMood `bloom_threshold` → `glow_hdr_threshold` (지금 0.9)

### 찾는 방법
- BattleMood 의 부모(배경 씬 루트) 아래에서 그룹으로 찾음 (다른 배경·씬의 부품은 안 건드림). 값이 바뀔 때마다, 그리고 나중에 배경에 추가된 부품(`node_added`)에도 넣음
- 부품은 BattleMood 없이 혼자 있어도 배율 1·자기 기본값으로 보임

### 신사 정원 옮기기
- 석등 둘의 `energy = 1.0` override → `brightness = 1.0`, 안개 modulate override 제거 → BattleMood `fog_color (0.7, 0.5, 0.45)`, `fog_density 0.25`
- `Sun` 추가 (오른쪽 위, 노을 색). 빛줄기 빔 위치 = 지금 닿는 곳

## 확인
- GUT: 각 슬라이더가 대상에 들어가는지, 배경 밖 부품은 안 바뀌는지, 나중에 추가된 부품도 받는지, 빛줄기 기울기 방향·길이, 안개 재질이 인스턴스마다 따로인지, 신사 정원 테스트 통과
- 화면: 옮기기 전후 신사 정원 스크린샷 비교 (복사본에서)
