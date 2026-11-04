# Void — CLAUDE.md (Godot)

## Project Overview
**공허(Void)** 의 힘을 다루는 인물들이 등장하는 **턴제 카드 덱빌딩 로그라이트**. 2인 팀 프로젝트.

- **핵심 루프**: 월드맵에서 의뢰 선택 → 의뢰 안의 스테이지 격자 진행(전투/이벤트/상점/휴식/보스) → 보상(카드·아이템) → 파티/덱 편집 → 다음 의뢰
- **전투**: 파티(여러 캐릭터) vs 적, 격자 위 배치. 드로우 → 대기 → 카드 행동 → 엔드 페이즈. 카드는 SP 소모
- 기획 원본은 Notion **🌀 Project Void** (아래 Reference). 코드와 기획이 충돌하면 Notion의 "구현 확정" 섹션이 우선, 애매하면 질문할 것

## Tech Stack
- Engine: Godot 4.7.2 (Forward+, Jolt Physics)
- Language: GDScript
- Platform: Windows (d3d12)
- 실행 파일: `C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe`
- MCP: GoPeak (`addons/godot_mcp_editor`, `godot_mcp_runtime`, `auto_reload`) — 에디터 브리지 포트 6505
- 테스트: GUT 9.7.1 (`addons/gut`). 실행:
  `Godot_v4.7.2-stable_win64_console.exe --headless --path . --import` 후
  `... --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- 카드 데이터: 웹 카드 에디터 → 내보내기 zip → Godot **프로젝트 → 도구 → 카드 가져오기...** (`addons/card_importer`). `cards/data/` 의 `.tres` 는 웹 에디터 칸만 덮어쓰고 effects/costs/conditions 는 유지

## 확정된 게임 규칙 (Notion "구현 확정", 2026-10-11)

### 의뢰 스테이지 (1층)
- 월드맵의 모든 노드는 **의뢰**. 진입 시 스테이지 격자 진행
- 1층: 시작 → **3줄 × 5칸** → 보스. 왼→오 이동, 다음 칸은 같은 줄 앞 또는 위/아래 대각선. 진입마다 새로 생성
- 칸 비율: 전투 6 : 이벤트 2 : 상점 1, 첫 칸은 항상 전투, 마지막은 항상 보스이며 보스 전은 항상 휴
- 의뢰 내 체력 유지, HP 0 파티원은 남은 전투 제외, 의뢰 종료 시 전원 회복
- 보스 승리 = 성공(노드 클리어), 패배/도주 = 실패(월드맵 복귀). 전투 승리마다 아이템 1개

### 카드
- 공격 종류: **근접**(같은 행 맨 앞 적 자동, 없으면 사용 불가) / **원거리**(상대 아무 유닛 지정) / **아군**(자신 포함) / **자신**(즉시). 빈 칸은 지정 불가
- 광역: 기준 유닛으로부터의 `Vector2i` 오프셋 배열. 인스펙터에서 5×5 격자 클릭 편집
- 분류: 공격(빨강) / 스킬(파랑) / 특수(보라) / 적 전용(검정)
- 효과: 카드당 여러 개. 종류(피해/방어도/회복) + % + 대상(범위/자신)
  - 피해·회복 = 공격 스탯, 방어도 = 방어 스탯 기준. 수치 = 스탯 × % (내림, 최소 1)
  - 전투 중엔 계산된 수치, 덱 편집 화면에선 % 표시
- 적도 같은 카드 규칙 사용. 적만 쓰는 카드는 **적 전용(검정)** 분류 — 플레이어 덱·보상·상점에 나오지 않음
- 카드 대체: **손패에 있는 동안만** 대체 카드로 보이고 사용됨. 사용 후 묘지(버린 더미)·제외로 갈 때는 원래 카드로 돌아감 (2026-11-04)
- 키워드: 카드에 마우스를 올리면 카드 오른쪽에 키워드 이름과 설명이 뜬다 (웹 에디터와 같은 동작). 데이터는 `CardData.keywords`(id) → `cards/keywords/<id>.tres`(KeywordData)

### 스탯
- HP, SP, 공격, 방어, 속도, 이동속도, 치명확률, 치명피해, 어그로, 스태미너, 행동 횟수
- 속도 = 행동 순서(클수록 먼저), 이동속도 = 자기 차례에 격자에서 움직일 수 있는 칸 수 (상하좌우 한 칸 = 1, 기본 2)
- **속도는 최소~최대 범위**. 매 라운드 행동 횟수만큼 행동마다 따로 굴리고, 감속·가속 보정은 굴린 값에 적용. 라운드 중 속도가 바뀌면 남은 행동 즉시 재정렬 (2026-11-04)
- **행동 횟수** 스탯: 한 라운드에 행동하는 횟수(버프·장비로 변경 가능). **행동 하나 = 온전한 차례 하나** (SP 회복 → 드로우 → 행동 → 손패 전부 버림)
- **격자 크기는 전투마다 데이터로 지정**. 행 수는 양쪽 공통, 열 수는 편마다 다를 수 있음 (기본 3행×4열)
- 방어 스탯은 받는 피해를 줄이지 않음 (방어도 계수용)
- 치명타는 피해 효과에만, 대상마다 개별 판정
- 어그로는 값만 존재 (규칙 미정)
- 장비 공격 보너스는 공격 스탯에 가산

### 아직 미구현/미정 (구현 전 확인 필요)
키워드(버리기·연결 등), 덱 코스트·장수 제한, 2층 이상·공허 깊이, 이벤트/상점/휴식 효과, 궁극기 게이지, 패시브, 흐트러짐 게이지, 친밀도·협공, 장비 숙련도·등급(노말→레어→유니크→유물)

## Project Structure
```
res://
  Scripts/       # 모든 게임 스크립트(.gd) — 사용자 결정. 안은 기능별 폴더
    battle/      #   전투 로직 (턴, 피해, 상태, 이벤트)
    cards/       #   카드 데이터·비용·조건·효과·배율 부품
    statuses/    #   상태·보정·트리거·장비
    ui/          #   화면 스크립트 (card_view, card_gallery …)
  cards/         # 카드 데이터 .tres (data/<덱>/, keywords/, art/) — 카드 가져오기로 생성
  statuses/      # 상태(data/)·장비(equipment/) .tres
  entities/      # 캐릭터·적 데이터 .tres (units/)
  ui/            # 화면 씬 .tscn (card_view/, card_gallery/ …)
  addons/        # 플러그인 (GUT, GoPeak, card_importer) — 플러그인 스크립트는 여기 그대로
  tests/         # GUT 테스트 (Scripts/ 와 같은 기능별 폴더)
  docs/          # 설계·계획·진행 상황
```
- 게임 스크립트는 반드시 `Scripts/` 아래에 둔다. 씬(.tscn)·데이터(.tres)는 기능 폴더에 두고 스크립트를 참조한다
- 예외: 플러그인 스크립트(`addons/`), 테스트(`tests/`)
- 폴더는 필요할 때 만든다. 미리 다 만들지 않는다
- 원본 작업 파일(.aseprite, .psd 등)은 `.gdignore` 폴더에 둔다

## Godot 에디터 우선 원칙 (필수)
- **Godot 에디터에서 만들 수 있는 것은 무조건 에디터 자산으로 만든다.** 노드·UI 배치·스타일은 `.tscn` 씬 안의 노드로, 게임 데이터(카드·상태·장비·유닛)는 `.tres` 리소스로 만든다
- 스크립트에서 노드를 `new()`/`add_child()`로 조립하지 않는다. 예외: 데이터 개수만큼 반복 생성하는 항목(카드 목록 등) — 이때도 틀은 씬으로 만들고 instantiate/duplicate 한다
- Godot 에디터가 켜져 있으면 GoPeak MCP 에디터 도구로 씬·노드를 추가하고, 안 되면 (에디터를 끈 상태에서) Godot 이 직접 `.tscn`/`.tres` 를 저장하게 한다 (손으로 텍스트 작성 금지)
- 순수 로직(전투 계산 등 `RefCounted`)과 테스트 코드는 예외

## 주석 원칙 (필수, 테스트 코드 제외)
- 모든 스크립트에 한국어 주석을 충실히 단다. (전역 "WHY일 때만 주석" 규칙보다 이 규칙이 우선)
- 클래스 맨 위 `##`: 이 스크립트가 무엇을 하는지, 어디서 쓰는지
- `@export` 변수·공개 함수·시그널 위 `##`: 의미, 단위, 허용 값 (에디터 인스펙터 툴팁에도 표시됨)
- 함수 안: 단계가 여러 개면 단계마다, 규칙이 기획에서 온 것이면 그 규칙을 한 줄로
- 서드파티 애드온(`addons/gut`, `addons/godot_mcp_*`, `addons/auto_reload`)은 손대지 않는다

## Godot Conventions
- 파일/폴더명: snake_case (`player.tscn` / `Scripts/…/player.gd` — 씬과 스크립트는 같은 이름). 예외: 최상위 `Scripts/` 폴더
- 노드 이름: PascalCase
- 시그널: snake_case 과거형 (`health_changed`, `card_played`)
- 게임 데이터(카드, 스탯, 적)는 커스텀 `Resource` + `.tres`로
- 파일 이동/이름 변경은 Godot 에디터 FileSystem 독에서 (참조 깨짐 방지)

## 에디터 켜짐 중 작업 규칙 (필수 — 2026-11-04 에디터 크래시 2회 원인)
- 에디터가 켜져 있으면 바깥에서 `res://` 의 `.tscn`/`.tres`/폴더를 쓰거나 옮기거나 지우지 않는다. 리소스는 MCP 로 에디터 안에서 만든다
- MCP 로 안 되는 것(리소스 안에 리소스 넣기, 파일 이동 등)은 에디터를 끈 상태에서 하거나, 인스펙터 작업 순서를 안내한다
- 테스트·헤드리스 스크립트는 프로젝트 **복사본**에서 실행한다 (같은 프로젝트로 `--import` 하면 에디터가 둘이 되어 `.godot` 캐시가 충돌). 복사본에서는 MCP 플러그인·MCPRuntime 을 끄고 `--log-file` 로 로그를 따로 둔다

## Workflow
- **진행 상황은 `docs/progress.md` 에 기록한다** (팀 공유용, 커밋함). 작업 단계가 끝날 때마다 갱신
- 새 기능: brainstorming → writing-plans → TDD → 구현 → 직접 실행 확인
- 설계 스펙은 `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` (Notion 카드/의뢰 페이지가 이 경로를 참조함)
- 버그: systematic-debugging 먼저
- 씬 구조 변경 시 의존 씬 영향 범위 먼저 파악

## Reference
- Notion 허브: [🌀 Project Void](https://app.notion.com/p/3e285441ae3d8170847ec21f8ad862e2)
  - [의뢰](https://app.notion.com/p/3f485441ae3d80d3987adc76fdfa0082) · [1층 설계](https://app.notion.com/p/3f685441ae3d810a8606e392f06a18cf) · [카드](https://app.notion.com/p/43885441ae3d82558f93015a6484a538) · [세계관](https://app.notion.com/p/52585441ae3d825f97b401d1d2dbc9b3) · [아이디어 박스](https://app.notion.com/p/3dd85441ae3d8097abf0d6d874584282) · [프로젝트 관리](https://app.notion.com/p/58885441ae3d83f38f2181ed4f044c89)
- Figma 와이어프레임: 팀 폴더 (Notion Team Info 참고)
- 팀: noooooooooooooooob, Dohyune (GitHub)
