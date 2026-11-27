# 전투 무드 (어둡게 + 광원 + 화면 효과) · 신사 정원 배경 — 설계

## 목적
전투 장면을 어둡게 깔고 석등 같은 광원과 화면 효과로 분위기를 내서, 레퍼런스 영상(용사주식회사 「배틀씬 또 고쳤습니다」 10:02–11:45) 같은 느낌을 낸다.
어두워져야 캐릭터 노말맵(홍연 idle, 2026-11-27)도 눈에 보인다.
시험(스파이크, 2026-11-27)에서 제일 좋았던 조합은 **밤 + 캐릭터 보조광**이었고, 이 조합으로 간다.

## 목표 / 비목표 / 실패 조건
- 목표: 전투 월드(배경·유닛)만 어두워지고 빛을 받는다. UI(카드·라벨·버튼·가방·결과 창)와 피해 숫자·연출 이펙트는 지금 밝기 그대로다
- 목표: 배경마다 무드를 인스펙터 슬라이더로 맞춘다 (영상의 옵션 창처럼). 에디터 2D 화면에서 바로 결과가 보인다
- 목표: 새 배경 「신사 정원」(먼 산 / 바닥 두 장)을 밤 무드로 쓴다
- 비목표 (이번에 안 함): 색수차(픽셀 그림이 번짐, 시험에서 탈락), 노을 무드, 빛줄기, 그림자·젖은 바닥 반사·이슬 반짝임·전경 가림막, 배경 노말맵(영상에도 없음), Emission·AO·PartMask, 한 배경에 무드 여러 개
- 실패 조건: UI 가 어두워지거나 뿌옇게 됨, 마우스 입력 순서가 바뀜(카드·버튼이 안 눌림), 연출 카메라(확대·이동)나 조준 화살표 위치가 틀어짐, 캐릭터가 어두워서 안 보임, 픽셀 그림이 흐려짐

## 방법 비교
- **A. 무드를 배경 씬 안의 노드로 (선택)**: 배경 씬에 `BattleMood` 노드 하나를 넣는다. 이 노드는 `@tool` 스크립트이고, 인스펙터 슬라이더 값을 자식 노드(어둠·하늘·화면 효과·보조광)에 넣는다. 석등·안개는 배경 씬에 그냥 놓는 부품 씬이다. 배경 하나가 자기 분위기를 다 들고 있고, 에디터에서 바로 보인다. 전투 화면 코드는 바뀌지 않는다
- B. 무드 값 묶음 `.tres` + 전투 화면이 적용: 값은 한 파일에 모이지만, 석등 위치는 어차피 씬에 있어야 해서 두 군데로 나뉜다. 적용 코드가 필요하고, 에디터에서 미리 볼 수 없다 → 기각
- 앞서 말한 "배경마다 .tres" 대신 A 로 바꾼 이유: 에디터 우선 원칙, 그리고 2D 화면에서 바로 미리 볼 수 있어서

## 설계

### 1단계 — 전투 화면 층 나누기 (`Scenes/ui/battle_screen/battle_screen.tscn`)
Godot `CanvasLayer` 는 유니티 캔버스처럼 따로 그려지는 층이다. 어둠(CanvasModulate)과 조명은 자기 층에만 걸리고, 화면 효과는 자기보다 아래 층에만 걸린다.
지금 그리기 순서를 그대로 지키면서 층만 나눈다.

| 층 | 노드 이름 | 들어가는 것 | 어둠·조명 | 화면 효과 |
|---|---|---|---|---|
| 0 | (BattleScreen 루트 그대로) | `World` (배경·격자·유닛) | 받음 | 받음 |
| 1 | — (배경 씬의 무드가 가져옴) | 화면 효과 | — | — |
| 2 | `UiLayer` | RoundLabel, TurnQueue, TurnBanner, AllyPanel, EnemyPanel, Log, Hand, BottomLeft, BottomRight | 안 받음 | 안 받음 |
| 3 | `FrontLayer` | `WorldFront` (연출·피해 숫자) | 안 받음 | 안 받음 |
| 4 | `OverlayLayer` | BagPanel, TargetArrow, ResultOverlay | 안 받음 | 안 받음 |

- 노드 이름과 `%` 고유 이름은 그대로다. 그래서 스크립트의 `%World` 같은 참조는 바뀌지 않는다
- 좌표: Camera2D 가 없고 층 변환이 모두 기본값이라, 층이 달라도 `get_global_rect()` 좌표는 같다. 연출 카메라는 지금처럼 World·WorldFront 의 변환을 바꾸는 방식이라 그대로 동작한다
- 연출 이펙트·피해 숫자는 지금도 손패 위에 그려지고, 앞으로도 그렇다 (3층). 어둠을 안 받는 건 "빛나는 이펙트"라서 의도한 것이다
- `Scenes/performances/performance_preview.tscn`: 이 씬은 전투 화면을 품고 있고, 위에 `Panel` 이 있다. 층이 나뉘면 이 Panel 이 전투 화면 층들 밑에 깔린다 → Panel 을 `CanvasLayer`(layer 10) 안으로 옮긴다
- 주의: CanvasLayer 는 부모의 visible 을 따르지 않는다. 전투 화면은 씬 전환으로 열려서 지금은 문제가 없다

### 2단계 — 무드 노드 `BattleMood`
- 스크립트: `Scripts/backgrounds/battle_mood.gd` (`@tool`, `extends Node2D`, `class_name BattleMood`)
- 틀 씬: `Scenes/backgrounds/parts/battle_mood.tscn`. 자식 노드는 아래와 같다
  - `Darkness` (CanvasModulate): 0층을 어둡게 한다
  - `Sky` (TextureRect, 세로 GradientTexture2D, 화면 전체): 맨 뒤에 깐다. 신사 정원 그림은 하늘이 투명이라 필요하다
  - `CharacterFill` (DirectionalLight2D, `range_item_cull_mask` = 2): 캐릭터만 비추는 보조광. 유닛 Sprite 는 light_mask 3 이고, 이건 이미 들어가 있다
  - `PostLayer` (CanvasLayer layer 1) / `Post` (ColorRect, 화면 셰이더): 비네트와 냉난 대비(어두운 곳은 차갑게, 밝은 곳은 따뜻하게). 색수차는 넣지 않는다
  - `Glow` (WorldEnvironment, background = Canvas, glow 켬): 빛 번짐
- 인스펙터 슬라이더 (`@export`, 바꾸면 바로 자식에 반영):
  - `darkness: Color`
  - `sky_top: Color`, `sky_bottom: Color`
  - `fill_color: Color`, `fill_energy: float`, `fill_angle: float`(도)
  - `vignette: float` 0..1
  - `split_tone: float` 0..1, `cool: Color`, `warm: Color`
  - `bloom: float` 0..1 (glow 세기, 0 이면 끔)
  - `haze_targets: Array[NodePath]`, `haze_color: Color`, `haze_amount: float` 0..1: 먼 배경 그림에 공기원근 셰이더를 건다 (멀수록 푸르고 뿌옇게)
- 부품 씬 (배경 씬에 원하는 만큼 놓는다):
  - `Scenes/backgrounds/parts/lantern_light.tscn`: PointLight2D(따뜻한 색, 넓게) + 더하기 헤일로 스프라이트(빛을 안 받음)
  - `Scenes/backgrounds/parts/ground_fog.tscn`: 노이즈 텍스처가 천천히 흐르는 안개 띠. 빛을 안 받고, 기본 진하기는 낮게 둔다(시험에서는 너무 진했음)
- 셰이더 파일은 쓰는 부품 씬 옆 `Scenes/backgrounds/parts/` 에 둔다
- 시작 값은 시험의 "밤 + 캐릭터 보조광" 조합으로 한다. 다만 석등 빛 범위는 더 좁게, 안개는 더 옅게

### 3단계 — 신사 정원 배경 (`Scenes/backgrounds/shrine_garden.tscn`)
- 그림 이름은 에디터 FileSystem 독에서 snake_case 로 바꾼다
  - `신사정원.png` → `shrine_garden_far.png`
  - `이끼 낀 … (1).png` → `shrine_garden_near.png`
- 노드 순서 (뒤에서 앞으로):
  1. `BattleMood`
  2. `FarLayer` (TextureRect, haze 대상, Nearest)
  3. `NearLayer` (TextureRect, Nearest)
  4. `LanternL`, `LanternR`: 석등 불 위치. 그림 기준 (125,405)·(1560,400) × 1920/1672
  5. `GroundFog`
  6. `Ally Board`, `Enemy Board`
- 격자판 네 모서리는 사용자가 에디터에서 바닥에 맞춘다
- `battles/test_battle.tres` 의 background 를 이 씬으로 바꿔 F6 로 확인한다. 기존 `mountain_shrine.tscn` 은 건드리지 않는다 (사용자의 CharacterLight 위치 변경 포함)
- HDR 2D(`rendering/viewport/hdr_2d`): 시험에서는 켜고 빛 번짐을 냈다. 켜면 다른 화면(사무소·지도)의 색이 미세하게 달라질 수 있다. 그래서 켜고 다른 화면 스크린샷을 비교한다. 달라지면 끄고, 빛 번짐은 HDR 없이 되는 만큼만 쓴다

## 확인
- GUT
  - 층 나누기: 각 노드가 위 표의 층에 있고 층 번호가 맞는지. 기존 전투 화면 테스트(연출 카메라 `%World` 변환, 가방, 보상)가 그대로 통과하는지
  - BattleMood: 슬라이더 값을 바꾸면 자식 노드에 들어가는지 (darkness → CanvasModulate 색, vignette → 셰이더 값, fill_energy → 보조광 energy, bloom 0 → glow 꺼짐, haze_targets 에 셰이더가 걸리는지)
  - 신사 정원: 배경이 격자판 두 개를 갖고, 시험 전투가 그 칸을 쓰는지 (`_use_background_boards`)
- 실행 확인 (스크린샷)
  - UI·피해 숫자는 밝고, 월드만 어둡다
  - 카드 드래그·버튼 클릭·가방 드래그·조준 화살표가 지금처럼 동작하고 위치가 맞다
  - 연출 확대가 지금처럼 움직인다
  - 홍연의 노말 음영이 보인다
  - 연출 미리보기 씬의 Panel 이 위에 보인다

## 빌더에게 맡기는 것
- 셰이더 세부 (비네트 곡선, 냉난 대비 식, 안개 노이즈 속도)
- 슬라이더 기본값 미세 조정. 시험 스크립트 `mood_spike.gd` 의 값을 출발점으로 쓴다
- 헤일로 그림: GradientTexture2D 원형으로 충분하면 그것을 쓴다
- 작업 순서: 1단계(층 나누기)는 다른 것 없이도 화면이 지금과 똑같아야 한다. 그래서 먼저 끝내고 커밋한다
- 작업 브랜치: `feat/hongyeon-normal-map` 위에서 새 브랜치를 판다 (light_mask 를 쓰므로)
