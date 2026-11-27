# Project Void 개발 진행 상황

마지막 갱신: 2026-11-27

코드 구조 관계도 (Figma): https://www.figma.com/design/tQfd1uNHyAqbmYuwPUHkan — 카드 데이터 흐름 / 데이터 구조 / 전투 런타임, 구현됨·예정 색 구분

## 완료된 기능

| 기능 | 내용 | 위치 |
|---|---|---|
| 카드 가져오기 | 웹 카드 에디터 내보내기(zip) → Godot 카드 데이터. 다시 가져와도 Godot에서 붙인 효과·비용·조건은 유지. 덱 폴더 = 덱 이름, 파일 이름 = 카드 이름(2026-11-05, 이름이 바뀌면 파일을 옮겨 uid 유지) | 프로젝트 → 도구 → 카드 가져오기... (`addons/card_importer`) |
| 카드 내보내기 (2026-11-09) | 가져오기의 반대 방향. Godot 카드·키워드·그림 → 웹 에디터 형식 zip → 웹 에디터의 "가져오기" 버튼으로 미리보기 후 적용. 추가·변경만 하고 삭제는 안 함, 이미 있는 덱 이름은 유지, 내용이 같은 그림은 다시 올리지 않음. Godot 쪽 효과·비용·조건은 안 나감 | 프로젝트 → 도구 → 카드 내보내기... (`addons/card_importer/card_exporter.gd`) |
| 장비 에디터 (2026-11-10) | 웹 카드 에디터에 장비 탭 추가 (종류·등급·스탯 줄·키워드·그림·설명). 같은 zip 으로 카드 가져오기·내보내기에 장비 포함. 웹 칸만 덮어쓰고 Godot 에서 붙인 상태(버프·특수 효과)는 유지, 착용 중인 장비는 지우지 않음. 장비 스탯은 착용 중 항상 적용, HP 보너스는 시작 HP 에도 반영 | 웹 에디터 장비 탭, `addons/card_importer/equipment_importer.gd`, `Scripts/statuses/equipment_data.gd`, 설계 `docs/superpowers/specs/2026-11-10-equipment-editor-design.md` |
| 소비 아이템 에디터 (2026-11-16) | 웹 카드 에디터에 소비 아이템 탭 추가 (이름·설명·그림·키워드·효과 줄: HP 회복 / SP 회복 [고정·%, % 는 최대치 기준] / 스탯 버프 [스탯·고정·%·지속 턴]). 등급 없음. 내보내기 zip 의 `cards.json` 에 `consumables` 키, 웹 가져오기도 읽음. Godot 가져오기는 2026-11-17 (아래 "소비 아이템 대상·범위·가져오기") | 웹 에디터 소비 아이템 탭, 설계 `docs/superpowers/specs/2026-11-16-consumable-editor-design.md` |
| 소비 아이템 대상·범위·가져오기 (2026-11-17) | 웹 에디터 소비 아이템에 **사용 대상**(아군/적/둘 다)·**범위**(5×5)를 정하고 수치에 **음수** 허용. 카드 가져오기가 `consumables` 를 `items/consumables/<이름>.tres` 로 가져옴(웹 칸만 덮어씀, `effects` 유지, id 없는 시험 아이템은 그대로, 스탯 버프 줄은 빼고 확인 창에 경고). 전투: 적에게도 끌어서 사용, 범위 안 같은 편 모두에게 적용, 음수 HP 는 **피해가 아닌 HP 감소**(방어도·피격 효과 없음, `HP_LOST`), 음수 SP 는 0 에서 멈춤, 끌 때 범위 칸 표시 | 웹 에디터, `addons/card_importer/consumable_importer.gd`, `Battle.use_item`·`lose_hp`·`item_affected`, 설계 `docs/superpowers/specs/2026-11-17-consumable-targets-design.md` |
| 소비 아이템 특수 효과 (2026-11-17) | 웹 효과 줄로 못 적는 아이템을 Godot `effects` 로 구현: **폭탄** 범위 안 적마다 고정 피해 10(치명 없음, 방어도에 막힘), **쉴드 포션** 고정 방어도 10, **분노 포션** 새 상태 분노(`rage_potion`, 공격 +10% × 수치, 받은 유닛 자신의 엔드 페이즈에 전부 사라짐). 다시 가져와도 유지. 분노 포션의 웹 버프 줄은 여전히 가져올 때 빠짐 | `items/consumables/폭탄·쉴드 포션·분노 포션.tres`, `statuses/data/rage_potion.tres`, 설계 `docs/superpowers/specs/2026-11-17-consumable-special-effects-design.md` |
| 이동 버튼 (2026-11-17) | 이동 칸(하늘색)이 항상 떠 있던 것을 **이동 버튼**으로 바꿈: 버튼을 눌러야 갈 수 있는 칸이 빛나고, 칸을 누르면 이동 후 모드가 꺼짐. ESC·우클릭·카드/아이템 고르기·차례 종료로도 꺼짐. 이동력 0·적 차례·연출 중엔 버튼 비활성 | `battle_screen.gd` (`toggle_move`, `is_move_mode`), 씬 `BottomRight/MoveButton`, 설계 `docs/superpowers/specs/2026-11-17-move-button-design.md` |
| 키워드 파일 이름 (2026-11-10) | `cards/keywords/` 파일 이름을 id 대신 키워드 이름으로 (겹치면 `_<id>`). 게임은 `KeywordData.find` 로 파일 안의 id 로 찾음. 기존 id 이름 파일은 다음 카드 가져오기 때 자동으로 이름이 바뀜 | `Scripts/cards/keyword_data.gd`, `addons/card_importer/card_importer.gd` |
| 홍연 전투 그림·혈갑 이펙트 (2026-11-23) | 홍연 idle(128px 8칸, 칸당 300ms)을 전투 그림으로 연결 (`hongyeon`·시험용 홍연 둘 다). 유닛별 그림 배율 `UnitData.battle_scale`(브람 일러스트 = 1, 128px 픽셀 = 10 → 화면 2배)·픽셀 그림 Nearest(`battle_pixel_art`), 중심 위치는 배율과 상관없이 같음. 상태에 **전투 이펙트** 칸(`StatusData.effect_behind`/`effect_front`): 그 상태를 가진 동안 유닛 그림 뒤·앞에 반복 재생, 상태가 사라지면 같이 사라짐. 혈갑에 bloodswirl(80칸, 20 FPS) 연결. 연출 씬(Actor)에는 아직 배율 미적용 | `entities/units/hongyeon_frames.tres`, `statuses/effects/`, `Art/vfx/hongyeon/`, `Scripts/ui/unit_token.gd`, 씬 `unit_token.tscn` 의 `Sprite/EffectBehind`·`EffectFront` |
| 적 그림 21종 (2026-11-25) | 배경 7개 × 적 3종, 동작 서기(`idle`, 반복)·맞기(`hit`)·공격(`attack`) 한 장씩. 그림은 `Art/enemies/<배경>/<이름>/<이름>_<동작>.png`, 새 메뉴 **프로젝트 → 도구 → 적 그림 가져오기...** 가 `entities/units/enemies/<배경>/` 에 그림 묶음(`<이름>_frames.tres`, 매번 다시 채움)과 유닛(`<이름>.tres`, 없을 때만 — 시험용 적 A 의 스탯·덱 복사, 배율 2.7)을 만듦. 공용 `타격`·`사격` 카드 동작 = `attack`. 연출 씬 없는 카드로 맞아도 `hit` 재생. 시험 전투 적 = 산 신사 3종(금 간 수호 석상·종이 등롱 요괴·원령 무녀). 스탯·덱은 아직 전부 임시 | `addons/card_importer/enemy_frames_builder.gd`, `Art/enemies/`, `entities/units/enemies/`, 프롬프트 `docs/art/2026-11-25-enemy-sprite-prompts.md` |
| 전투 그림 발밑 피벗 (2026-11-25) | 전투 그림의 기준점을 **발밑**으로: 규약 = 한 그림 묶음의 프레임은 모두 같은 캔버스 크기, 두 발 가운데가 캔버스 아래 가운데 (`SpritePivot.foot_offset` → offset = (0, -캔버스 높이/2)). 유닛 박스의 `Sprite` 노드 위치(지금 칸 중심)에 발이 선다 — 높이를 바꾸려면 `unit_token.tscn` 의 `Sprite` position. 브람 5동작 PNG 를 1548×1362 공통 캔버스로 패딩(동작 바뀔 때 안 튐), 홍연 idle 을 4px 왼쪽으로, 상태 이펙트도 바닥 가운데가 발밑에. 연출 Actor·연출 화면 탭도 같은 규약 | `Scripts/ui/sprite_pivot.gd`, `Scripts/ui/unit_token.gd`, `Scripts/performances/card_performance.gd`, `addons/performance_stage_view/stage_view.gd`, `Art/characters/bram_welburn/`, `Art/characters/hongyeon/hongyeon_idle.png` |
| 적 그림 발밑 맞춤 (2026-11-27) | 적 21종 PNG 를 발밑 규약대로 다시 자름: 적마다 idle 의 맨 아래 줄 가운데 = 발, 세 동작을 같은 만큼 옮겨(동작 바뀔 때 안 튐) 발이 캔버스 아래 가운데에 오게. 아래 빈칸 9~18px 가 없어져 적이 떠 보이지 않음. 분수 가고일·네온 깡패는 발보다 아래로 나온 몇 px(4·1)가 잘림. 배율·.tres 는 그대로 | `Art/enemies/` |
| 캐릭터 노말맵·스페큘러 (2026-11-27) | 홍연 idle 에 Aseprite `Normal`·`Specular` 레이어를 붙임: 같은 배치 시트(`_normal`·`_specular.png`, 발밑 피벗에 맞춰 4px 왼쪽)를 기본 색과 함께 `CanvasTexture` 로 묶고 idle 프레임이 그것을 씀. 노말은 OpenGL 방식(초록 = 위) 그대로. **조명은 캐릭터만**: 유닛 그림 `light_mask` 2번 층, 조명은 2번 층만 비춤 → UI·배경·상태 이펙트는 그대로. 시험 조명 = 산중 신사 배경의 `CharacterLight`(PointLight2D, 세기 0.5, 높이 150) — 위치·세기는 에디터에서 맞추면 됨. 조명은 더하기라 빛 받는 쪽만 밝아짐(어둡게 하는 연출은 다음 단계). 노말맵 없는 유닛(브람·적)도 조명 근처면 고르게 밝아짐. 다음: Emission·AO·PartMask | `Art/characters/hongyeon/hongyeon_idle_canvas.tres`, `entities/units/hongyeon_frames.tres`, `Scenes/backgrounds/mountain_shrine.tscn`, `Scenes/ui/battle_screen/unit_token.tscn`, 설계 `docs/superpowers/specs/2026-11-27-character-normal-specular-design.md` |
| 전투 화면 층 나누기 — 전투 무드 1단계 (2026-11-27) | 다음 단계에서 월드만 어둡게·조명·화면 효과를 받게 하려고 전투 화면을 CanvasLayer 로 나눔. 0층 = `World`(배경·격자·유닛), 1층 = 화면 효과 자리(비움), 2층 `UiLayer` = 라벨·손패·패널·버튼, 3층 `FrontLayer` = `WorldFront`(연출·피해 숫자), 4층 `OverlayLayer` = 가방·조준 화살표·결과 창·← 사무소로. 그리기 순서·노드 이름은 예전 그대로라 보이는 것은 같음. **화면 흔들기는 이제 루트가 아니라 뷰포트 `canvas_transform` 을 흔듦**(CanvasLayer 는 부모를 안 따라서) — 2~4층은 follow_viewport 라 같이 흔들리고 층끼리 좌표가 안 어긋남. 흔드는 중 화면이 닫히면 되돌림. 연출 미리보기 씬의 Panel 은 CanvasLayer 10 으로 올림 | `Scenes/ui/battle_screen/battle_screen.tscn`, `Scripts/ui/battle_screen.gd`, `Scenes/performances/performance_preview.tscn`, 설계 `docs/superpowers/specs/2026-11-27-battle-mood-design.md`, 계획 `docs/superpowers/plans/2026-11-27-battle-screen-layers.md` |
| 전투 무드 노드 — 전투 무드 2단계 (2026-11-27) | 배경 씬 맨 앞에 `Scenes/backgrounds/parts/battle_mood.tscn` 을 넣고 인스펙터로 분위기를 맞춤 (`@tool`, 에디터 2D 화면에 바로 보임). 값: 어둠 색(CanvasModulate, 월드 0층만), 하늘 위·아래 색(투명한 하늘 뒤에 깔림), 캐릭터 보조광(색·세기·각도, 캐릭터만 비춤), 비네트·냉난 대비(1층 화면 셰이더), 빛 번짐(WorldEnvironment glow, UI 층은 안 받음), 공기원근(haze_targets 에 먼 배경 노드를 넣으면 푸르고 뿌옇게). 색수차는 픽셀 그림이 번져서 뺌. 시작 값 = 시험 '밤 + 캐릭터 보조광'. 부품: `lantern_light.tscn`(석등 빛 + 헤일로), `ground_fog.tscn`(흐르는 바닥 안개) — 배경에 원하는 만큼 놓음. 아직 어떤 배경에도 안 넣음(3단계 신사 정원에서) | `Scripts/backgrounds/battle_mood.gd`, `Scenes/backgrounds/parts/`, 계획 `docs/superpowers/plans/2026-11-27-battle-mood-node.md` |
| 신사 정원 배경 (밤 무드) — 전투 무드 3단계 (2026-11-27) | 새 배경 `Scenes/backgrounds/shrine_garden.tscn`: BattleMood(밤) → 먼 산 `shrine_garden_far.png`(공기원근, **빛 안 받음** light_mask 0) → 바닥·나무·도리이 `shrine_garden_near.png` → 석등 빛 둘(석등 불 자리) → 바닥 안개 → 아군·적 격자판(좌우 대칭, 윗변·아랫변 수평). **캐릭터 보조광은 PointLight2D** — DirectionalLight2D 는 range_item_cull_mask 를 무시하고 배경까지 비춰서 화면이 밝아졌음(시험으로 확인). 멀리 둔 큰 점광이라 한 방향 빛처럼 보임, `fill_angle` = 빛이 오는 쪽(기본 -45 = 오른쪽 위). 전투 유닛 그림 밑 이름·HP 글자 뺌(상태 패널에만). 시험 전투 배경을 바꾸려면 `battles/test_battle.tres` background 를 이 씬으로 | `Scenes/backgrounds/shrine_garden.tscn`, `Scenes/backgrounds/parts/battle_mood.tscn`, `Scripts/backgrounds/battle_mood.gd` |
| 카드 연출도 무드를 받음 (2026-11-27, 코드 리뷰 반영) | 카드 연출(행위자 복사본)이 3층에 그려져 공격할 때만 캐릭터가 환하게 튀던 문제 → **사용자 결정 A**: `PerformanceLayer` 를 월드(0층) 안 유닛 위(z 2)로 옮겨 연출 중에도 어둠·석등·보조광·노말맵을 받음. 행위자는 진짜 그림의 light_mask 를 물려받음(`PerformanceQueue`). 대신 연출은 UI 밑에 그려지고 연출 씬 안 효과도 같이 어두워짐. 피격 이펙트는 새 `EffectLayer`(3층)에 띄워 밝게 유지, 피해 숫자도 3층 그대로. 그 밖에: 에디터 '연출 화면' 독 미리보기 SubViewport 를 own_world_3d 로(무드의 빛 번짐이 에디터에 새지 않게), 보조광 기본 방향 -45 로 통일 | `Scenes/ui/battle_screen/battle_screen.tscn`, `Scripts/ui/battle_screen.gd`, `Scripts/ui/performance_queue.gd`, `addons/performance_stage_view/stage_view.tscn` |
| 스머지(스미어) 효과 (2026-11-25) | 연출 중 Actor 가 빠르게 움직이거나 순간이동하면 지나온 쪽으로 **모션 블러 꼬리**가 잠깐 생김 (그림 새로 안 그림). 쓰는 법: 연출 씬의 Actor 아래에 `Scenes/performances/smear.tscn` 을 끌어다 놓기 — 키를 찍을 필요 없음. 꼬리 = 이동 거리 × `length_ratio`(0.5), 최대 `max_length` 400px, `decay_time` 0.12초 안에 사라짐, 60fps 한 프레임에 20px 미만 이동은 무시, 길이는 화면 px 기준(픽셀 그림 행위자도 같음), **60fps 기준**(이동을 1/60 초 단위로 모아 판단 — 144Hz 도 같은 꼬리, 30fps 같은 저프레임은 순간이동 꼬리도 줄어듦), 카메라 이동엔 반응 안 함, 좌우 반전 Actor 도 맞게 그림. 모양(셰이더 기본값, 사용자 선택): 그림 전체가 고르게(`min_length` 1)·평균 블러(`average`)·몸 위에 살짝(`front_amount` 0.2). 줄무늬로 하려면 `min_length` < 1, `average` 끔. 아틀라스 그림(홍연)도 그 칸만 읽음. Actor 에 다른 material 이 있으면 끔(경고). 연출 화면 탭에서도 보임(편집 중인 씬에선 안 돎). 지금 브람 돌주먹에만 붙음 | `Scripts/performances/smear_driver.gd`, `smear.gdshader`, `Scenes/performances/smear.tscn`, 설계 `docs/superpowers/specs/2026-11-25-smear-effect-design.md` |
| 덱 코스트 삭제 (2026-11-25) | 사용자 결정으로 카드의 덱 코스트를 없앰: 웹 카드 에디터(편집 칸·카드 배지·덱 "코스트 평균"·내보내기/가져오기), `CardData.cost`, 카드 화면의 "코스트 N", 카드 가져오기·내보내기. 예전 zip·예전 .tres 의 cost 는 무시(.tres 의 `cost = N` 줄은 다음 저장 때 빠짐) | `Scripts/cards/card_data.gd`, `Scripts/ui/card_view.gd`, `Scenes/ui/card_view/card_view.tscn`, `addons/card_importer/` |
| 카드 화면 | 웹 에디터와 같은 카드 모양, 마우스를 올리면 키워드 설명. 2026-11-17: "+N" 강화 배지를 없애고 **강화 버전 카드는 옅은 금색 바탕 + 금빛 광채**로 구분 (색은 `CardView` 인스펙터 "강화 버전 모양") | `ui/card_view/card_view.tscn` |
| 카드 갤러리 | 에디터에서 열기만 해도 카드가 보임. 인스펙터 Deck 으로 덱별 보기, 실행(F6) 시 탭 | `ui/card_gallery/card_gallery.tscn` |
| 테스트 도구 | GUT 9.7.1 (실행 방법은 CLAUDE.md) | `addons/gut`, `tests/` |
| 예시 데이터 | 유닛 홍연(덱 10장, 패시브 피의 갈망, 장비 시험용 검), 상태 피의 갈망(잃은 HP 1%당 공격 +0.5%, 임시 값), 장비 시험용 검(공격 +5) | `entities/units/hongyeon.tres`, `statuses/data/`, `statuses/equipment/` |
| 상태 데이터 | 출혈(드로우 페이즈 고정 피해 × 수치), 혈갑(차례 종료 방어도 × 수치), 핏방울(패시브, 적이 받은 출혈 피해만큼 쌓임) — 에디터 인스펙터로 제작 | `statuses/data/` |
| 소비 아이템 (시험판, 2026-11-17) | 파티 공용 가방 5칸(의뢰 동안 유지), 전투 중 TAB/가방 버튼으로 열어 **카드처럼 끌어서** 아군에게 사용(아군 차례의 카드 사용 페이즈만, 비용 없음), HP 회복·SP 회복(SP 는 최대 초과 가능, 다음 차례 시작에 최대로). 의뢰의 일반 전투 승리 시 40% 로 1개 드랍 → 결과 창에서 받기 / 넘어가기, 가방이 가득 차면 바꿀 칸 고르기. 보스·F6 시험 전투는 드랍 없음. 아이템은 웹 에디터에서 가져옴 (시험 아이템 회복약·기력약은 2026-11-17 삭제) | `Scripts/items/`, `items/consumables/`, `Scenes/ui/battle_screen/bag_panel.tscn`·`item_slot.tscn`, 규칙 `Battle.use_item`·`StageRun.roll_item_drop`. 설계 `docs/superpowers/specs/2026-11-17-consumable-items-design.md` |
| 전투 화면 (시험판) | 홍연·브람 (2026-11-23 시험용 홍연 → 진짜 홍연, 보스 전투도 같음) vs 시험용 적 A·B 한 판을 직접 플레이. 원거리·근접 카드는 휜 화살표로 대상 지정, 자신 카드는 두 번 클릭/끌어 올리기, 빈 칸 클릭으로 이동, 적 차례 0.7초 간격 자동, 떠오르는 숫자·전투 기록, 승리/패배 → 다시 하기. 손패에 계산된 수치 표시 | `ui/battle_screen/battle_screen.tscn` 열고 F6. 데이터 `battles/test_battle.tres` |
| 전투 데이터 | 격자 크기 + 아군/적 배치 리소스 (`BattleData`), 진행 담당 `BattleSession` (의뢰 파티를 밖에서 넣을 수 있음) | `Scripts/battle/battle_data.gd`, `battle_session.gd` |
| 타이틀·메인 메뉴·사무소 (2026-11-21) | 게임 메인 씬. 타이틀(아무 키·클릭) → 메인 메뉴(↑↓/W·S, 엔터·스페이스·E) → 새 게임 → 사무소(왼쪽 레일 7개, 패널은 빈 틀) → 의뢰 게시판 "시험 의뢰 출발" → 스테이지 지도. 의뢰가 끝나면(성공·실패) 사무소로, 지도·전투 화면의 "← 사무소로" 는 확인 없이 도주. 공용 테마(연보라) | `Scenes/ui/title_screen/`, `Scenes/ui/office_screen/`, `Scenes/ui/void_theme.tres` (F5). 아래 "UI 뼈대 작업 기록" |
| 의뢰 게시판 (2026-11-24) | 사무소 01 의뢰 게시판 패널을 Figma 01-A 대로: 필터 칩(전체 N / 본 이야기 / 반복 의뢰), 의뢰 카드 목록(긴급·반복·본편 칩, 번호, 의뢰인, 보상 글, 난이도 ◆, 잠긴 카드), 오른쪽 자세히(의뢰인 초상·이름, 장 줄, 제목, 인용, 권장 등급·지역·적 정보, 목표, 보상 칸, 긴급 도장). 클릭·↑↓/W·S 로 고르기, "의뢰 수락"(Enter·Space·E) → `StageRun.start_request` → 스테이지 지도, "지도에서 보기" → 공허 지도 패널. 의뢰는 `requests/*.tres`(`RequestData`) — 예시 4개(Figma 그대로). 어떤 의뢰든 지금은 같은 1층 지도, 고른 의뢰는 `StageRun.current_request`. 자금·명성·등급·목표 진행·보상 아이템은 글만. 임시 버튼 "시험 의뢰 출발" 삭제 | `Scripts/requests/request_data.gd`, `Scripts/ui/request_card.gd`·`requests_board.gd`, `Scenes/ui/office_screen/request_card.tscn`·`requests_board.tscn`, `Art/ui/requests/`, 설계 `docs/superpowers/specs/2026-11-24-request-board-design.md` |
| 의뢰 진행 (시험판, 2026-11-10) | 의뢰마다 랜덤 지도(시작 → 3열×3행 전투 6·이벤트 3 → 상점 → 보스), 연결선, W/S·클릭으로 다음 노드 고르기, 스페이스·엔터로 실행. 전투 승리 → 지도, 패배 → 시작 화면, 보스 승리 → 의뢰 성공. 의뢰 안에서 HP 유지, HP 0 파티원 제외. 이벤트는 자리만(상점은 2026-11-17 상점 화면), 보스는 시험 전투 | `Scenes/ui/stage_map/`, `Scenes/ui/room_screen/`, `Scripts/stage/` (StageRun 자동 로드·StageProgress), 테스트 `tests/stage/`, `tests/ui/` |
| 브람 (2026-11-09) | 유닛 브람 웰번(덱 10장), 카드 10장·강화 10장 효과, 상태 도발·대신 맞기. 새 규칙: 쉴드 전부 소모(`BlockCost`), 현재 쉴드 비례(`CurrentBlockValue`), 쉴드 제거(`RemoveBlockEffect`), 끌어오기(`PullEffect`), 도발(`StatusData.taunts`), 대신 맞기(`StatusData.guarded_by_applier`). 시험 전투(`battles/test_battle.tres`)에 배치됨. 전투 그림은 아래 "전투 스프라이트"(2026-11-13) | `entities/units/bram_welburn.tres`, `cards/data/브람/`, `statuses/data/` |
| 전투 격자판 (2026-11-10) | 편마다 5×5 칸 판(`battle_board.tscn`)을 배경 씬에 아군용·적용으로 하나씩 넣고 칸 위치·크기·모양을 에디터에서 꾸민다. 전투가 시작되면 맞닿는 쪽 열·가운데 행부터 전투 크기만큼만 켜고 나머지는 숨김. 판이 없는 배경은 기존 정사각형 격자. 2026-11-11: 칸을 원근 사각형으로. 보드 네 모서리(`corners`)를 바닥에 맞추면 25칸이 자동으로 나뉘고, 필요한 칸만 꼭짓점(`custom_corners`)을 직접 조정. 색·표시·클릭 판정이 칸 모양을 따름. 에디터 2D 화면에서 핸들로 드래그 | `Scenes/ui/battle_screen/battle_board.tscn`, `Scripts/ui/battle_board.gd`, `Scripts/ui/grid_cell.gd`, `Scripts/ui/board_shape.gd`, `addons/board_shape_editor/`, 설계 `docs/superpowers/specs/2026-11-11-board-cell-shape-design.md` |
| 전투 격자판 늘리기·넓은 배경 (2026-11-25) | 격자판 인스펙터 **판 늘리기**: `row_stretch`(세로)·`col_stretch`(가로) 칸을 끌면 판이 가운데 기준으로 바로 늘었다 줄었다 함 — 화면을 늘리는 게 아니라 원근 평면에서 판이 덮는 바닥을 넓혀서 원근·가운데 점 유지, Ctrl+Z 됨, 아군·적 같은 값이면 대칭 유지 (`BoardShape.stretch`). 뒤 줄 캐릭터가 앞 줄에 가리던 문제(줄 간격 약 60px vs 홍연 256px)로 산중 신사 판을 세로 1.5배. 캐릭터 크기는 그대로(사용자 결정: 작아지면 안 됨), 원근 크기·연출 줌은 나중에. 배경을 넓은 판(같은 픽셀 크기, 더 멀리서 본 구도)으로 교체: `Art/backgrounds/` 5장 같은 이름으로 교체 + `mountain_shrine_terrace.png`(전투 배경)·`amethyst_mine_forge.png` 새로. 같은 날 폴더 나눔: 전투 배경 `Art/backgrounds/battle/` 7장(`golden_vortex_void` → `void_mirror_expanse`, `misty_castle_garden` → `lilac_castle_courtyard`), 화면 배경 `Art/backgrounds/screens/` 4장(`title`·`title_void`·`office`·`office_void`) | `Scripts/ui/battle_board.gd`, `Scripts/ui/board_shape.gd`, `Scenes/backgrounds/mountain_shrine.tscn`, `Art/backgrounds/` |
| 전투 스프라이트 (2026-11-13) | 유닛마다 `UnitData.battle_frames`(SpriteFrames)를 두고 유닛 박스의 `Sprite`(AnimatedSprite2D)가 `idle` 을 반복. 카드를 쓰면 `CardData.animation` 이름의 동작을 한 번 재생하고 idle 로 돌아옴(강화본은 칸이 비면 원래 카드 이름). 지금은 브람만, 동작마다 그림 1장(placeholder): punch·uppercut·guard·victory_pose. 묶음이 없는 유닛은 색 박스 그대로 | `entities/units/bram_frames.tres`, `Art/characters/bram_welburn/bram_*.png`, `Scripts/ui/unit_token.gd` |
| 카드 연출 (2026-11-14) | 카드마다 연출 씬(`CardData.performance`, 루트 `CardPerformance`)의 AnimationPlayer `perform` 타임라인으로 이동·동작·이펙트를 정하고, Call Method 키 `move(x, y, 시간)`(대상 칸 기준)·`hit()`(맞는 반응, 여러 번)·`show_results()`(결과 한 번에)·`zoom(세기, 시간)` 을 찍는다. 연출 끝나면 자동 복귀. 계산은 즉시, 화면은 `PerformanceRecorder`→`PerformanceQueue` 로 단계별 재생하고 연출 중엔 입력·적 행동·결과 창 대기. hit 반응: 캐릭터 그림·화면·캐릭터 UI 랜덤 흔들림, 피격 이펙트, 효과음(음높이 무작위), 히트스톱, 번쩍임, 넉백. 결과: 숫자는 부호 없이 색으로 구분(피해 빨강·회복 초록·방어도 파랑)하고 매번 조금씩 다른 방향으로 떠오름, 피해 클수록·치명타면 큰 숫자, 처치·치명 때 추가 흔들림. 공통값은 BattleScreen, 카드별 변경은 연출 씬 루트. 시험: 브람 돌주먹. HP 바 잔상은 HP 바가 생긴 뒤 | `Scripts/performances/`, `Scripts/ui/performance_queue.gd`, `Scripts/ui/shaker.gd`, `Scenes/performances/bram_stone_fist.tscn`, 설계 `docs/superpowers/specs/2026-11-14-card-performance-design.md` |
| 연출 타임라인 (2026-11-19) | 연출 씬을 **에디터 ▶ 로 그대로 미리 보며** 유니티 Timeline 처럼 짠다. 씬은 **게임 화면 크기**로 짠다(좌표 1 = 화면 1px, Actor·대상 미리보기 그림에 유닛 그림 배율 0.2 를 직접 넣음 → Camera 사각형 = 실제 전투 화면 범위). 규약 노드: `Home`(행위자 자리)·`Target`(대상 자리, 자식 미리보기 그림은 실행 때 숨김)·`Actor`·`Camera`(Camera2D, enabled 끔)·`AnimationPlayer`(`perform`). 동작 전환은 속성 트랙 `Actor:animation`, 이동·카메라는 Bezier 트랙(`Actor:position`, `Camera:position`·`zoom`·회전), 효과음은 Audio Playback 트랙, 이펙트는 속성 트랙. `move()` 키는 없앰 — 전투 화면 반응(`hit`·`show_results`·`zoom`)만 Call Method 키. 실행 땐 Home→행위자 그림, Target→대상 그림 자리로 맞추고(`PerformanceSpace`, Home→Target 직선에서 벗어난 높이는 그대로). 2026-11-21 **가까운 쪽 기준**: Target 쪽 1/3 에 찍은 위치는 실제 대상에서 같은 픽셀(대상 앞 50px → 어느 칸이든 대상 앞 50px), Home 쪽 1/3 은 실제 행위자에서 같은 픽셀, 가운데 1/3 만 섞어 이음. 브람 돌주먹은 이동을 **순간이동**(`Actor:position` 값 트랙 Discrete: 0초 Home → 0.15초 대상 앞 50px → 0.6초 Home)으로, 끝나면 `return_time` 동안 Home 으로 복귀. 카메라는 전투 화면의 월드 묶음(`%World` 배경·격자, `%WorldFront` 연출·숫자)만 움직이고 UI 는 고정, 끝나면 원위치. **연출 미리보기**: `Scenes/performances/performance_preview.tscn` 에서 F6 → 카드·대상 고르고(행위자는 카드 주인으로 자동, 2026-11-21) ▶ 재생·반복·속도(0.25~1×), 피격 반응·숫자·카메라까지 실제 전투와 같음 (인스펙터 `card` 로 기본 카드). 에디터 ▶ 에서는 hit·결과·줌 펀치 반응은 안 보임 → 미리보기 씬에서 | `Scripts/performances/` (`card_performance.gd`, `performance_space.gd`, `camera_math.gd`, `performance_preview.gd`), `Scripts/ui/performance_queue.gd`, `Scripts/ui/battle_screen.gd`, `Scenes/performances/`, 설계 `docs/superpowers/specs/2026-11-19-performance-timeline-design.md` |
| 연출 화면 창 (2026-11-19) | 에디터 플러그인 `addons/performance_stage_view` (프로젝트 설정에서 켜짐). 연출 씬(루트 `CardPerformance`)을 열면 하단 **"연출 화면"** 탭에 시험 전투의 배경·격자판·아군·**적 하나**가 깔리고, 애니메이션 패널 막대를 끌거나 ▶ 하면 **그 프레임을 실제 전투 화면처럼**(실제 칸 거리로 늘린 위치·카메라 구도) 보여 줌. 위 줄에서 행위자 고르기(기본 = 이 연출 카드의 주인). 2026-11-21: 위 줄 **배경** 목록(`Scenes/backgrounds/` 의 씬, 고른 배경은 에디터를 다시 켜도 기억 — 칸 크기·자리는 계속 시험 전투)과, 유닛은 **행위자 하나 + 적 하나**, 격자 칸도 **그 둘이 선 칸 하나씩**만 보이게. 행위자 목록은 없앰(연출 카드 주인으로 자동). **적 목록**(`entities/units/` 아래 유닛 전부, 기본 = 시험 전투 첫 적, 기억함. **내 칸·적 칸** 목록으로 서는 칸을 고름(기본 = 시험 전투 자리, 기억함). 아군 캐릭터 — `battles/` 전투들의 적으로 나온 적 없는 유닛 — 를 고르면 좌우 반전). 유닛은 그림만, 그림 묶음 없는 유닛만 편 색 박스로 (설계 `docs/superpowers/specs/2026-11-21-stage-view-background-pick-design.md`). 배치·카메라 식은 게임과 공용(`PerformanceSpace.root_scale/root_position/map_point`, `CameraMath.world_xform`). 피격 반응·숫자·UI 는 없음 → F6 미리보기. 주의: 막대를 옮긴 채 씬을 저장하면 그 상태가 씬에 남음(게임은 0초 키로 시작하므로 영향 없음) | `addons/performance_stage_view/`, 설계 `docs/superpowers/specs/2026-11-19-performance-stage-view-design.md` |
| 피격 반응 미리보기·슬로우모션 (2026-11-21) | 게임: hit 키 때 대상 그림 묶음에 **`hit` 애니메이션**이 있으면 한 번 재생 → idle (지금은 어느 유닛에도 없음, 반복 없이 넣으면 됨). **히트스톱은 정지 대신 슬로우모션**: `hitstop_speed`(기본 0.2배속) × `hitstop_time`(기본 0.15초), 카드별 값은 연출 씬 루트 — **피격 반응 값 전부 카드별로 바꿀 수 있음**(수치 -1·색 알파 0 = 공통값). 결과 강조도 슬로우모션: 쓰러뜨림 = 흔들림·슬로우 시간 × `kill_boost`(1.8), 치명타 = 흔들림 × `crit_shake_boost`(1.3)·슬로우 시간 × `crit_hitstop_boost`(1.3), 기준값은 카드별 값 우선. 연출 화면 탭: 막대 끌기·▶ 모두 적의 번쩍임·넉백·흔들림·hit 애니메이션, ▶ 재생 중 hit 키를 지나면 효과음·화면 흔들림·슬로우모션, 위 줄 **치명타** 체크를 켜면 ▶ 중 결과 키 때 치명타 강조(화면 흔들림·슬로우모션)도(연출 씬 AnimationPlayer 배속을 잠깐 바꿈 — 저장 직전·창 숨김 때 되돌림). 피격 이펙트는 연출 씬 안에 노드+트랙으로 직접 짬(Target 기준 자리) | `Scripts/ui/battle_screen.gd`(`_hitstop`), `Scripts/ui/unit_token.gd`(`play_hit`), `Scripts/performances/card_performance.gd`(`set_speed`, `hitstop_speed`), `addons/performance_stage_view/`, 설계 `docs/superpowers/specs/2026-11-21-hit-reaction-preview-design.md` |
| 손패 떠오르기 (2026-11-15) | 손패 카드는 평소 `hand_sink`(150px)만큼 화면 아래로 내려가 있고, 마우스를 올린 카드만 부드럽게 떠오름(`hand_rise_speed`). 카드는 끌어서 대상 위(자신·근접 카드는 위로 끌어 올리면 어디서 놓든, 근접은 자동 대상 — 2026-11-17)에서 놓아야 쓰이고, 그 밖에 놓거나 그냥 클릭했다 떼면 손패로 돌아감. 카드가 움직여도 깜빡이지 않게 카드 가로 범위 기둥 전체로 마우스를 봄 | `Scripts/ui/battle_screen.gd` |
| 상점·공허 조각 (시험판, 2026-11-17) | 의뢰 안 재화 **공허 조각**: 의뢰 전투 승리마다 `BattleData.shard_reward`(일반 20, 보스 50 — 보스는 새 `battles/boss_battle.tres`), 결과 창에 "공허 조각 +N", 의뢰가 끝나면 0. 상점 노드 → **상점 화면**: 파티(살아 있는 파티원) 캐릭터 카드 5장·소비 아이템 3개를 겹치지 않게 진열해 구매(카드 50, 아이템 30), **카드 제거**(75)·**카드 강화**(60, 원래 카드의 강화 중 최대 3개에서 고름, 강화한 카드는 다른 강화로 바꾸기). 가격 고정, 값은 `shop/shop_data.tres`. 덱 변경은 **의뢰 덱**(`BattleUnit.run_deck`)에만, 유닛 원본 덱은 그대로. 나가면 노드 클리어. 가방 아이템은 끌어서 **버리기** 칸에 놓으면 버림(상점·전투) | `Scripts/shop/`, `Scripts/cards/card_pool.gd`, `Scripts/stage/wallet.gd`, `Scripts/ui/shop_screen.gd`, `Scenes/ui/shop_screen/`, 설계 `docs/superpowers/specs/2026-11-17-shop-design.md` |
| 전투 보상 목록 (2026-11-19) | 의뢰 전투 승리 → 결과 창에 보상 줄(공허 조각 / 아이템 / 카드 추가)을 **클릭해서 챙김**(슬더스식). 조각 자동 지급·받기 버튼 없앰. 아이템은 가방이 가득 차면 바꿀 칸 고르기·취소. **카드 보상 새로 추가**: 살아 있는 파티원 카드 중 3장 → 1장 골라 주인의 의뢰 덱으로(넘어가기 가능). 보스는 조각만. "계속"은 언제든, 안 챙긴 보상은 사라짐. 카드 후보 뽑기는 상점과 같은 함수(`CardPool.pick_party_cards`) | `Scripts/stage/battle_reward.gd`, `Scripts/ui/battle_screen.gd`, 씬 `ResultOverlay/Box/RewardList`·`ResultOverlay/CardPick`, 설계 `docs/superpowers/specs/2026-11-19-battle-rewards-design.md` |
| 그림 추가 (코드에서 아직 안 씀) | 캐릭터 10명 일러스트·픽셀 아트(`mo_liang` 은 일러스트만), 배경 5장, 공허 지도 | `Art/characters/`, `Art/backgrounds/`, `Art/ui/void_map.png` |

## UI 뼈대 작업 기록 — 타이틀 · 메인 메뉴 · 사무소 (2026-11-21, `feat/ui-frame` → `main` 바로 머지, 2026-11-24)

Figma `Project Void UI Wireframes` › **v6 · 연보라 사이드 패널** 기준. 설계 `docs/superpowers/specs/2026-11-21-ui-frame-design.md`, 계획 `docs/superpowers/plans/2026-11-21-ui-frame.md`.

- 범위 (사용자 결정): 공용 테마(연보라 팔레트) · 타이틀 → 메인 메뉴(T-A/T-B) · 사무소(00-A, 왼쪽 레일 7개 + 오른쪽 위 자금·설정 HUD + 패널 자리) · 패널 7개는 빈 틀. 다음 차례는 의뢰 게시판. 메인 메뉴·사무소 배경 그림은 사용자가 준비
- 끝남: Figma 그림 15개(`Art/ui/title·main_menu·office/`), 스크립트(`ui_palette`, `menu_cursor`, `notice_label`, `main_menu_item`, `title_screen` 새로 씀, `rail_menu_item`, `office_panel`, `office_screen`), 테스트, **의뢰가 끝나면 시작 화면 대신 사무소로** (`StageRun.OFFICE_SCENE`)
- 글꼴 4종 `Art/fonts/` (Noto Serif KR · Noto Sans KR · Cormorant Garamond · IBM Plex Mono, OFL)
- 2026-11-21 테마·씬 완료: `Scenes/ui/void_theme.tres`(프로젝트 설정 `gui/theme/custom`, Label 변형 11개·PrimaryButton·GhostButton), `title_screen/main_menu_item.tscn`, `title_screen/title_screen.tscn`(uid 유지), `office_screen/rail_menu_item.tscn`·`office_panel.tscn`·`office_screen.tscn`. 타이틀 → 새 게임 → 사무소 → 의뢰 게시판 "시험 의뢰 출발" → 스테이지 지도
  - 만드는 법: 숫자·색·노드는 GoPeak MCP, MCP 가 못 하는 것(테마의 글꼴·StyleBox, 씬 인스턴스 넣기)만 에디터에서 손으로. 그라데이션은 씬 안 리소스 대신 **SVG 그림**(`Art/ui/title/*.svg`, `Art/ui/office/rail_*.svg` 등)으로 만들어 TextureRect 에 늘려 씀
  - 글꼴 변형: `Art/fonts/cormorant_garamond/cormorant_garamond_semibold_italic.tres`(wght 600), `Art/fonts/ibm_plex_mono/ibm_plex_mono_medium_wide.tres`(자간 2)
  - 배경 그림(사용자 제작): `Art/backgrounds/screens/title.png`(타이틀 키 아트)·`office.png`(사무소) — 2026-11-25 전 이름 `main_screen`·`lobby_screen`. 스토리에 따라 바꿀 `_void` 판도 같이 넣어 둠 — 바꾸는 기능은 스토리 진행 상태가 생기면
  - `title_screen.gd` 버그 수정: 삼항식 안 배열이 타입 없는 Array 라 `Array[CanvasItem]` 에 못 넣어 실행 시 멈추던 것
- 2026-11-21 사용자 피드백 반영: 타이틀은 **클릭**으로도 시작(화면 전체 루트가 클릭을 먼저 받아서 `_gui_input` 에서 처리), 메뉴 확인은 **엔터·스페이스·E**. 새 게임에서 엔터를 누르면 나던 오류(장면이 바뀌어 트리에서 빠진 뒤 `get_viewport()` 가 null) 수정 — 입력 처리 표시를 먼저 하고 실행. 메뉴 줄 클릭도 같은 순서로. **스테이지 지도·전투 화면에 "← 사무소로" 버튼**: 확인 없이 의뢰를 끝내고 사무소로 (`StageRun.leave_run`, 결과는 실패와 같음)
- 테스트 (2026-11-24 머지 직전): 847개 중 846 통과. 실패 1개 `test_performance_stage_view.gd::test_slowmo_ends_by_itself`(이번 작업과 무관한 연출 화면 창 쪽, 단독 실행해도 실패). `test_card_performance.gd::test_looping_perform_still_finishes` 는 가끔 실패(시간에 따라 달라짐)
- 주의: 이어하기·불러오기는 저장 기능 전까지 비활성, 자금·하루·배지 숫자는 시스템이 없어 자리만. Figma 와 픽셀 단위 비교·다듬기는 아직

## 의뢰 스테이지 작업 기록 (2026-11-07~10, `main` 머지 — PR #3)

- 2026-11-08: 사무소 허브, 로스터, 캐릭터 페이지, 카드 공방, 공허 지도, 파티 선택, ESC 메뉴, 비스듬한 전투 격자, 브람 덱·유닛을 만들었다가 **전부 되돌림** (`3a823f6`). 씬·데이터를 에디터가 아니라 헤드리스 스크립트로 만들었기 때문. 지금은 코드가 없고 git 기록에만 있음 (`eedcfb6`~`dd22343`). 그림 파일만 다시 넣음 (`f899b9c`)
- 2026-11-09: 머지 전 정리 — 생성기 "첫 열은 모두 전투" 규칙 추가, `CLAUDE.md` 1층 규칙을 새 규칙으로 수정, `title_screen.gd`·`stage_map.gd`·`stage_node_view.gd` 를 `Scripts/ui/` 로 이동, 잘리던 지도를 화면 가운데로 옮기고 노드 글자 가운데 정렬
- 2026-11-09: `feat/office-hub` 를 `main` 에 머지 (PR #2)
- 2026-11-10: 의뢰 진행 복구 (`feat/stage-run`). 로직·테스트·씬은 `0c84bcc` 에서 가져옴. 씬 3개(`stage_map`, `stage_node_view`, `room_screen`)는 예전에 Godot 이 저장한 파일을 그대로 되살린 것
- MCP 주의: 에디터가 켜져 있어도 같은 씬을 연달아 고치면 마지막 변경만 남고, `add-input-action` 은 입력 설정을 문자열로 잘못 저장함. MCP 로 고친 뒤에는 파일을 확인할 것

남은 문제:

- 노션 1층 설계는 2026-11-07 기록 기준으로 아직 3줄×5칸·휴식 규칙 그대로
- 기획 결정 필요: 파티 위치를 다음 전투로 이어갈지(지금은 이어짐), 대신 맞기를 브람 자신에게 쓸 수 있게 둘지(지금은 SP 만 쓰고 효과 없음)
- 의뢰 파티가 비면 전투 화면이 만피 새 아군을 만듦. 지금은 도달할 수 없지만 파티 선택을 넣을 때 막아야 함

## 전투 시스템 (카드·효과·턴) — 완료

- 설계: [docs/superpowers/specs/2026-11-03-card-effect-system-design.md](superpowers/specs/2026-11-03-card-effect-system-design.md)
- 구현 계획: [docs/superpowers/plans/2026-11-03-card-effect-system.md](superpowers/plans/2026-11-03-card-effect-system.md)
- 브랜치: `feat/battle-system` (`main` 머지 — PR #1)

| # | 단계 | 상태 | 커밋 |
|---|---|---|---|
| 1 | 공통 타입 (편, 스탯, 이벤트, 상수) | ✅ 완료 | `e5a97a1` |
| 2 | 이벤트 관리자 (구독 순서, 처리 중 해제, 연쇄 상한 10) | ✅ 완료 | `227818c` |
| 3 | 데이터 구조, 유닛 스탯(% → 고정값), 상태 중첩, 배율 | ✅ 완료 | `308a28c` |
| 4 | 격자·근접·광역, 피해(방어도 → HP, 스태미너), 상태 부여·제거 | ✅ 완료 | `6c558d9` |
| 5 | 효과 부품 (피해, 방어도, 회복, 상태, 수치 변경, 전용 스크립트) | ✅ 완료 | `2e3f1e9` |
| 6 | 카드 사용 (조건, SP·상태 비용, 대상, 카드 대체, 소멸 → 제외) | ✅ 완료 | `9d9b3dc` |
| 7 | 덱과 턴 진행 (속도 순, 즉시 재정렬, 드로우, 라운드 방어도 초기화, 전투 종료) | ✅ 완료 | `fda7b7f` |
| 8 | 상태 트리거 (출혈·혈갑·핏방울), 패시브·장비 | ✅ 완료 | `8f85a76` |
| 9 | 이동 (이동속도만큼, 유닛 칸 통과 불가) | ✅ 완료 | `85bbc28` |
| 10 | 적 행동 (일반 적 1장, 보스 순서대로) | ✅ 완료 | `fca12d6` |

## 계획과 다르게 정한 것

- 전투 Task 1: 브랜치·GUT 설치·문서 커밋은 카드 가져오기 작업 때 이미 끝나 있어서 건너뜀
- 전투 Task 3: `CardData`와 비용·조건·효과 기반 클래스는 카드 가져오기 작업 때 이미 만들어져 있어서, 새로 만들지 않고 기존 파일에 필요한 부분만 더함
- 전투 Task 3: 상태·보정·트리거의 선택형 칸(스탯 종류, 이벤트 등)은 숫자 대신 드롭다운으로 보이게 함 — 에디터에서 `.tres`를 만들기 쉽게
- 전투 Task 3: 상태·장비 데이터에 화면용 이름·설명 칸 추가

- 전투 Task 4: 죽은 유닛에게는 피해·회복·방어도가 들어가지 않음. 회복 이벤트의 수치는 실제로 회복된 양

- 2026-11-04 규칙 변경 (사용자 결정): 속도 = 최소~최대 범위, 라운드마다 행동마다 굴림 / 행동 횟수 스탯 추가, 행동 하나 = 온전한 차례 / 속도 보정은 굴린 값에 / 격자 크기는 전투마다(행 공통, 열은 편마다). Task 1·3·4 코드와 Task 7·9 계획에 반영 (`c3de9c7`)

- 전투 Task 5: 상태 부여 수치가 0 이하로 계산되면 걸지 않음. 회복은 공격 스탯 기준만(고정값 회복 없음)

- 전투 Task 6 (사용자 요청): 제외 더미 추가. 키워드에 카드 Effects 처럼 **규칙 부품 목록(Rules)**을 두고, `ExileAfterUseRule`(사용 후 제외)이 있는 키워드가 붙은 카드는 사용 후 제외로 감. 소멸 키워드에 이 부품을 넣어 사용. Godot 쪽 칸이라 다시 가져와도 유지
- 전투 Task 6: 카드 대체는 손패에서만, 사용 후에는 원래 카드가 묘지·제외로 감

- 2026-11-04: 에디터 크래시(총 5회) 유력 원인 — `auto_reload` 플러그인이 에디터가 직접 저장한 씬(@tool 갤러리)까지 강제로 다시 불러옴. 플러그인 끔

- 전투 Task 7: 드로우 페이즈에 죽은 유닛(출혈 등)은 대기 페이즈 없이 차례가 끝남. 한쪽이 전멸하면 다음 차례 없음

- 2026-11-04 (사용자 결정): 행동 중 드로우는 덱이 비면 못 뽑음(버린 더미를 섞는 건 드로우 페이즈뿐)

- 전투 Task 8: 패시브 상태는 전투 시작 시 수치 0으로 붙음 (핏방울처럼 쌓는 패시브가 0부터 세도록)
- 2026-11-04 (사용자 결정): 상태로 생긴 피해는 아무도 준 것이 아님 — 건 유닛은 기억만(필터 "주인이 건 상태"로 쓸 수 있음), 스태미너 회복·치명 없음 / 장비는 착용하면 항상 적용(유닛 생성 시부터, 전투 밖에서도)

- 2026-11-04 (사용자 확정): 핏방울 = 적이 받은 출혈 피해 전부만큼 쌓임 (누가 걸었든). 트리거 필터 "대상이 주인의 적" 추가

- 전투 Task 9: 이동 규칙은 `Scripts/battle/battle_movement.gd` 로 분리 (battle.gd 600줄 제한). 죽은 유닛은 길을 막지 않음

- 전투 Task 10: 적 행동은 `Scripts/battle/enemy_ai.gd` 로 분리
- 2026-11-05 (사용자 결정): 적이 뽑은 카드를 못 쓰면 한 장 더 뽑아서 사용(보스는 순서상 다음 카드). 적 원거리 대상 = 아군 어그로 비율 가중 랜덤(모두 0이면 균등)

- 2026-11-05 리뷰 반영: 죽은 유닛의 상태 트리거는 반응하지 않음 / 같은 유닛으로 다음 전투를 열면 스태미너·방어도 리셋, 장비 외 상태 제거, 패시브 새로 시작, HP 는 유지 / 패시브(태그 PASSIVE)는 수치 0 이 되어도 사라지지 않음

- 2026-11-16 코드 리뷰 반영: HP 는 항상 0 ~ 최대 HP (`BattleUnit.hp` setter). 넘치는 피해를 받아도 피해 이벤트 도중 HP 가 음수가 아니고, 최대 HP 를 올리던 상태가 사라지거나 수치가 줄면 현재 HP 도 최대까지 내려감. 테스트 `tests/battle/test_battle_unit.gd`, `test_battle_damage.gd`
- 2026-11-16 코드 리뷰 반영: 카드 가져오기 — 웹 에디터에서 카드(키워드)를 지우고 같은 폴더에 같은 이름으로 새로 만든 뒤 가져오면 새 파일이 지워지던 문제 수정. zip 에 없는 파일을 저장 전에 먼저 지움 (`addons/card_importer/card_importer.gd`)
- 2026-11-16 코드 리뷰 반영: 상태 수치 소모 비용(`StatusCost`)에 손패 미리보기 추가 — 핏방울 소모 카드처럼 소모량에 비례하는 카드의 손패 숫자가 0 으로 나오던 문제 (`BlockCost` 에는 이미 있었음)
- 2026-11-16 코드 리뷰 반영: 아군이 자기 차례에 죽으면(반사 피해 등) 그 차례를 바로 끝내고 다음 차례로 (`BattleSession._pass_if_dead`, 엔드 페이즈 없이) / 전원 행동 횟수가 0 인 라운드는 다음 라운드로 넘김, 100 번 연속이면 멈춤 (`Battle.next_turn`, `BattleTypes.EMPTY_ROUND_LIMIT`) — 전에는 둘 다 전투가 멈추거나 죽은 캐릭터의 차례 종료를 직접 눌러야 했음
- 2026-11-16 코드 리뷰 반영: 줌 펀치가 겹치면 앞의 줌이 끝나면서 확대 중심을 되돌려 화면이 튀던 문제 — 새 줌이 시작되면 앞의 줌을 멈춤 (`battle_screen.gd` `_on_zoom`)

- 2026-11-05: `battle.gd` 분리 — 덱 규칙은 `battle_deck.gd`, 카드 사용은 `battle_card_play.gd` (이동 `battle_movement.gd`, 적 행동 `enemy_ai.gd` 와 같은 방식). battle.gd 508줄

## 구조 변경

- 2026-11-24: `feat/ui-frame`(테마·타이틀·메인 메뉴·사무소)을 PR 없이 `main` 에 머지 (`main` 의 문서 커밋 2개를 먼저 합치고 fast-forward). 메인 씬은 그대로 `title_screen.tscn`, 의뢰가 끝나면 시작 화면 대신 사무소로. 팀원의 `hongyeon` 브랜치(홍연 그림 교체)는 `feat/ui-frame` 위에서 만든 것이라 머지해도 충돌 없음
- 2026-11-21: 브랜치 정리 — `feat/shop`(카드 연출·소비 아이템·상점·전투 보상·연출 타임라인·피격 반응)을 `main` 에 fast-forward 머지. 그 안에 다 들어 있던 `feat/bram-sprites`·`feat/card-performance` 와 `feat/shop` 은 로컬·원격 모두 삭제. 지금 브랜치는 `main` 하나
- 2026-11-19: 전투 화면 씬에 월드 묶음 `World`(Background·AllyGrid·EnemyGrid)·`WorldFront`(PerformanceLayer·FloatLayer) 추가 — 연출 카메라가 UI 를 빼고 움직이게. 노드는 모두 `%이름` 으로 찾으므로 경로 영향 없음. 헤드리스로 씬을 고칠 때는 원래 PackedScene 에 `pack` 하고 `--editor` 모드로 저장해야 uid 가 유지됨
- 2026-11-17 (코드 리뷰 반영): ① 전투가 끝나도 `Battle` 이 메모리에서 안 풀리던 것 — 되돌아가는 참조(`BattleUnit.battle`, `StatusInstance.owner·applier`, 규칙 객체 4개의 `.battle`)를 약한 참조(WeakRef)로. ② 상점에서 산 뒤 강화한 카드도 원래 카드의 동작 이름을 씀(`CardPool.find_base`). ③ 아이템 특수 효과 피해의 전투 기록이 "(상태)" 대신 아이템 이름. ④ 안 쓰는 `StageRun.Room.SHOP` 삭제. ⑤ 폴더의 `.tres` 찾기(.remap 처리)를 `Scripts/util/res_dir.gd`(`ResDir.tres_paths`) 하나로 — 카드 목록·키워드·소비 아이템·카드 갤러리. ⑥ 카드 갤러리의 덱 제목·카드 줄을 씬의 숨긴 틀(`SectionTitleTemplate`·`CardRowTemplate`)에서 복제. ⑦ 오래된 주석 정리. 전투 화면 스크립트(1186줄) 나누기는 보류
- 2026-11-09: 캐릭터 후보 그림 35장을 `Art_src/` 에서 뺌 (게임에 안 쓰는 그림, 저장소 밖 로컬 폴더 `C:\C\ProjectVoid_Assets` 에 보관)
- 2026-11-07: 메인 씬을 시작 화면으로 지정 (`project.godot`)
- 2026-11-04: 게임 스크립트를 모두 `Scripts/` 폴더로 옮김 (`Scripts/battle`, `Scripts/cards`, `Scripts/statuses`, `Scripts/ui`). 씬·데이터·테스트·플러그인은 제자리
- 2026-11-06: 전투 배경 = 배경 씬. `BattleData.background`(PackedScene) → 전투 화면이 `Background/BackgroundLayer` 에 붙임. 배경 씬은 `Scenes/backgrounds/` (첫 배경: `mountain_shrine.tscn`, 겹 1장). 패럴랙스·마우스 따라 움직이기는 나중에 배경 씬 안에서
- 2026-11-06: 씬을 모두 `Scenes/` 로 옮김 (`ui/…` → `Scenes/ui/…`). 그림은 `Art/` (characters/<이름>, enemies/<이름>, ui, backgrounds, vfx), 원본 `.aseprite`·`.psd` 는 `Art_src/` (`.gdignore`). 카드 그림은 카드 가져오기가 관리하므로 `cards/art/` 그대로. 빈 `battle/` 폴더 삭제
- 2026-11-05: 프로젝트 기본 해상도 1920×1080 (창은 1600×900), Figma 목업 기준에 맞춤
- 2026-11-05: 리소스 안에 리소스가 필요한 데이터와 화면 씬은 에디터를 끈 상태에서 Godot 헤드리스 스크립트로 저장 (MCP 로는 중첩 리소스를 못 넣음)
- 2026-11-04: Godot 에디터가 두 번 꺼진 원인 — 에디터가 켜진 동안 바깥에서 리소스 파일을 바꾸거나 옮김, 같은 프로젝트로 두 번째 Godot 을 띄워 테스트. 테스트는 이제 프로젝트 복사본에서 실행

## 나중에 할 일
- 소비 아이템 다음 단계: 스탯 버프 아이템, 의뢰 밖(사무소) 인벤토리, 아이템 그림·전용 연출
- 상점 다음 단계: 장비 강화, 이벤트에서 얻는 공허 조각, 상점 그림·연출.

- ~~전투 데이터 리소스~~ → 2026-11-05 `BattleData` 로 완료
- 전투 화면 다음 단계: 대상에 화살표를 올렸을 때 예상 피해(28 → 23), 적 의도 표시(규칙 미정), 그림·연출, 홍연 고유 카드 효과(수치·지속 턴·속박 기획 필요)
- 유닛 스탯 가져오기: 유닛 스탯은 노션 등장인물 표에서 먼저 고친다 (2026-11-04 결정). 노션 → `entities/units/*.tres` 가져오기 툴을 만들어 스탯만 덮어쓰고 덱·패시브·장비 연결은 유지 (카드 가져오기와 같은 방식). 그전까지는 노션 값을 인스펙터에 직접 옮겨 적는다

## 기획 미정 (구현은 자리만 마련)

- 브람 임시 규칙 (2026-11-09, 노션 확정 전): HP·SP·공격·방어는 노션이 0 이라 기본값(100·3·10·10). 갈고리 걸기는 브람과 같은 행의 맨 앞 칸으로, 차 있으면 피해만. 돌 던지기·내려찍기는 쉴드 0 이면 사용 불가, 치명 없음. 대신 맞기는 상대의 공격만(상태 피해 제외). 도발은 다른 행의 근접 공격도 끌어옴. "1턴간"은 브람의 다음 차례 시작까지

- 홍연의 HP·SP·공격·방어·속도 (노션에 0 / 1~10 으로 미정 → 예시 데이터는 기본값 사용)
- 피의 갈망의 정확한 수치 (예시 데이터는 잃은 HP 1%당 공격 +0.5%), 회복·혈갑 흡수 비율

- 스태미너가 0일 때 걸리는 상태의 효과
- 방어도 초기화의 예외 상황
- 각 상태(출혈, 혈갑 등)의 구체적인 수치 감소 규칙
