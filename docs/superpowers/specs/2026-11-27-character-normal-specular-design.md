# 캐릭터 노말맵·스페큘러 (홍연 idle 시험) — 설계

## 목적
Aseprite에서 그린 홍연 idle 의 Normal·Specular 맵을 전투 화면에 적용해서, 2D 조명을 받으면 입체감과 광택이 보이게 한다.
첫 단계(A)로, 나머지 맵(Emission·AO·PartMask)은 다음 단계에 붙인다.

## 목표 / 비목표
- 목표: 홍연 idle 8프레임이 노말·스페큘러가 들어간 상태로 재생되고, 시험 조명 하나에 반응한다
- 목표: 조명은 캐릭터만 비추고 UI(카드·라벨·패널)는 비추지 않는다
- 비목표: Emission·AO·PartMask, 화면 어둡게 하기(CanvasModulate), 블룸, 다른 캐릭터·적, 맵 자동 생성 도구
- 실패 조건: 애니메이션이 멈추거나 그림이 흐려지는 경우(픽셀 아트 Nearest 필터가 깨짐), UI 색이 바뀌는 경우

## 방법 비교
- **A. CanvasTexture + AtlasTexture (선택)**: 시트 3장(색·노말·스페큘러)을 `CanvasTexture` 하나로 묶고, 기존 `hongyeon_frames.tres` 의 AtlasTexture 8개가 그것을 가리키게 한다. 셰이더·코드 없이 에디터 자산만 쓴다
- B. 캐릭터 공용 셰이더: 셰이더가 UV 로 노말·스페큘러 시트를 읽는다. 다섯 맵을 모두 다룰 수 있지만 지금 범위보다 크다 → Emission·AO·PartMask 단계에서 다시 검토
- 기각: 프레임마다 노말 텍스처를 따로 두는 방법은 Godot 4 SpriteFrames 에 칸이 없다

## 설계
1. **내보내기**: Aseprite `hongyeon_idle.aseprite` 의 `Normal`·`Specular` 레이어를 각각 지금 `hongyeon_idle.png` 와 같은 배치(128×128 × 8칸 가로, 1024×128)로 내보낸다
   → `Art/characters/hongyeon/hongyeon_idle_normal.png`, `hongyeon_idle_specular.png`. 레이어 블렌드 모드는 따로 내보낼 때 상관없다
2. **CanvasTexture**: `Art/characters/hongyeon/hongyeon_idle_canvas.tres` (diffuse = hongyeon_idle.png, normal, specular). 스페큘러 색·광택(shininess)은 에디터에서 맞춘다
3. **SpriteFrames**: `entities/units/hongyeon_frames.tres` 의 AtlasTexture 8개의 `atlas` 를 CanvasTexture 로 바꾼다 (region 그대로, uid 유지)
4. **캐릭터만 비추기**: `unit_token.tscn` 의 `Sprite` 의 `light_mask` 에 2번 층을 켠다. 조명의 `range_item_cull_mask` = 2번 층만. UI 와 이펙트(EffectBehind/Front)는 1번 층만 → 빛을 안 받음
5. **시험 조명**: 배경 씬 `Scenes/backgrounds/mountain_shrine.tscn` 에 PointLight2D 하나 (배경마다 조명을 갖는 구조). 위치·높이·세기는 에디터에서 보면서 맞춘다
6. 작업은 에디터에서 Godot AI MCP 로 (엔진 기본 리소스라 가능). 바깥에서 `res://` 파일을 쓰지 않는다

## 확인
- GUT: `hongyeon_frames.tres` 의 프레임 텍스처가 AtlasTexture 이고, atlas 가 normal·specular 가 채워진 CanvasTexture 인지 확인
- 실행 확인: F6 시험 전투에서 홍연 idle 이 재생되고, 조명 쪽 면이 밝아지며, UI 색은 그대로인지 스크린샷으로 확인

## 빌더에게 맡기는 것 / 주의
- 노말 방향 규약: Godot 2D 기대값과 Aseprite 에서 그린 방향이 다르면 위아래 빛이 뒤집혀 보인다 → 그러면 내보낼 때 G 채널을 뒤집는다
- 조명은 더하기라서, 화면을 어둡게 하지 않으면 그늘진 면은 지금 그대로이고 빛 받는 면만 밝아진다. 어둡게 하는 연출은 Emission 단계에서 정한다
