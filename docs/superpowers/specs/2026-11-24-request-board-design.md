# 의뢰 게시판 설계

작성 2026-11-24 · 브랜치 `feat/request-board` (UI 뼈대 다음 단계)
디자인 원본: Figma `Project Void UI Wireframes` › **v6 · 연보라 사이드 패널** › **01-A 의뢰 게시판** (패널 노드 `77:146`)
(https://www.figma.com/design/cPKjLHuAgOEmvdLHLDsYnr/Project-Void-UI-Wireframes?node-id=77-74)

## 1. 왜 만드는가

사무소의 의뢰 게시판 패널에는 지금 임시 버튼 "시험 의뢰 출발" 하나뿐이다. Figma 01-A 처럼 **의뢰 목록 → 고르기 → 자세히 보기 → 의뢰 수락**을 만들어,
게임 흐름 "사무소 → 의뢰 선택 → 스테이지" 의 앞부분을 제대로 채운다.

- 성공: 사무소 → 의뢰 게시판 → 카드를 고르면 오른쪽에 의뢰인·설명·정보·목표·보상이 바뀐다 → "의뢰 수락" → 스테이지 지도. 의뢰가 끝나면 사무소로.
- 비목표: 자금·명성·사원 등급·카드 팩·재료 시스템, 목표 진행(체크), 스토리 진행에 따른 해금, 의뢰마다 다른 지도·적, 공허 지도 패널 내용.

## 2. 범위 (Claude 결정 2026-11-24, 사용자가 "알아서 정해"라고 함)

| Figma 요소 | 이번에 | 이유 |
|---|---|---|
| 필터 칩 (전체 N / 본 이야기 / 반복 의뢰) | **동작함** — 누르면 목록이 걸러짐 | 데이터만 있으면 됨 |
| 의뢰 카드 (칩·번호·제목·의뢰인·보상 글·난이도 ◆◆◆) | **동작함** — 클릭·↑↓/W·S 로 고르기 | |
| 잠긴 카드 (LOCKED, "3장 완료 후 해금") | **모양만** — `RequestData.locked` 칸으로 잠금, 고를 수 없음 | 스토리 진행 저장이 없음 |
| 오른쪽 자세히 (초상·이름·장·제목·인용·권장 등급·지역·적 정보) | **글을 데이터에서** 보여 줌 | 등급·지역은 글일 뿐 |
| 긴급 도장 | `urgent` 면 보임 | |
| 목표 (OBJECTIVES) | **글 목록만**, 체크 칸은 모두 빈 칸 | 목표 진행 시스템 없음 |
| 보상 (REWARDS) 칸 4개 + 글 | **빈 칸 4개 + 글** | 보상 아이템 시스템 없음 |
| 의뢰 수락 | **동작함** → 의뢰 시작 → 스테이지 지도 | |
| 지도에서 보기 | **공허 지도 패널(02)을 연다** (지금은 빈 틀) | 패널 이동만 |

모든 의뢰는 지금 있는 **1층 의뢰(랜덤 지도)** 를 그대로 시작한다. 어떤 의뢰를 골랐는지는 `StageRun.current_request` 에 남겨 둔다 (나중에 의뢰별 지도·보상에 씀).

## 3. 데이터 — `RequestData` (`Scripts/requests/request_data.gd`, `.tres` 는 `requests/`)

| 칸 | 타입 | 예 | 화면 |
|---|---|---|---|
| `code` | String | `REQ-0312` | 카드 오른쪽 위 |
| `title` | String | `하수도에서 올라온 검은 것` | 카드 제목 (`3장 · ` 은 자동), 자세히 제목 |
| `kind` | enum MAIN / REPEAT | MAIN | 칩·필터·장 줄 |
| `chapter` | int | 3 | 본 이야기만. `3장 · 제목`, `CHAPTER 03  —  MAIN STORY` |
| `urgent` | bool | true | 카드 칩 "긴급", 도장 |
| `client_ko` / `client_en` | String | 하수도 감독관 / Sewer Overseer | 카드 "의뢰인 · …", 초상 밑 |
| `portrait` | Texture2D | (없음) | 초상 칸. 없으면 "의뢰인 초상" 글 |
| `quote` | String (여러 줄) | “밤마다…” | 인용 |
| `rank` / `region` / `enemies` | String | 3급 이상 / 남부 · 하수도 / 괴한 ×1 · 잡졸 ×2 | 정보 3줄 |
| `objectives` | PackedStringArray | 하수도 입구 조사 … | 목표 목록 |
| `reward_text` | String | 자금 500 · 카드 팩 ×1 | 카드 아래 글, 보상 칸 밑 글 |
| `difficulty` | int 1~3 | 3 | 카드 ◆ 개수 |
| `locked` / `unlock_hint` | bool / String | true / 3장 완료 후 해금 | 잠긴 카드 |

- 목록 순서 (`RequestData.sort_for_board`): 잠기지 않은 것 먼저 → 긴급 먼저 → 본 이야기 먼저(장 순서) → 번호 순. Figma 의 순서와 같다.
- 필터 (`RequestData.Filter`): ALL / MAIN / REPEAT. "전체 N" 의 N 은 전체 의뢰 수(잠긴 것 포함, Figma "전체 4").
- 예시 의뢰 4개 = Figma 그대로 (3장 하수도 · 남부 항구 창고 청소 · 광산촌 잔류 공허 처리 · 4장 잠김). 반복 의뢰 둘의 인용·정보·목표는 임시 글.

## 4. 화면

### 4-1. `Scenes/ui/office_screen/request_card.tscn` (`RequestCard`, 520×146 / 잠김 520×92)
Figma 77:168(선택) · 77:179(보통) · 77:201(잠김). 판 그림 3개를 상태에 따라 바꿔 보인다.
- 칩(NinePatchRect): 긴급 = Rose 꽉 찬 칩 + Ink 글, 반복 = Teal 테두리 칩 + Teal 글, 본 이야기(긴급 아님) = 연보라 테두리 칩 + "본편".
- 선택: 빛나는 판(`card_plate_selected.svg`) + 제목 Accent. 보통: 제목 Text.
- 난이도 ◆ 3개: `difficulty` 개만 밝게(`diff_on.svg`), 나머지 `diff_off.svg`.
- 마우스 클릭 → `pressed` 시그널 (잠긴 카드는 안 보냄).

### 4-2. `Scenes/ui/office_screen/requests_board.tscn` (`RequestsBoard`, 1304×736)
의뢰 게시판 패널의 `Content` 자리(패널 기준 48,168)에 넣는다. 좌표는 Figma 패널 좌표 − (48,168).
- 왼쪽: 필터 칩 3개(0,0), 카드 목록 VBox(0,44, 폭 520, 사이 14). 카드는 `request_card.tscn` 을 데이터 수만큼 instantiate.
- 가운데 세로 구분선(552,0, 높이 720).
- 오른쪽 `Detail`(584,0, 720×736): 초상 판 250×340 · 이름(Teal)·영문, 장 줄 · 제목(34, 두 줄까지) · 인용 막대+글, 정보 3줄(라벨 Mono + 값) + 구분선, 목표 머리 + 목표 줄들(빈 체크 칸 + 글), 보상 머리 + 빈 칸 4개 + 글, 버튼 2개(지도에서 보기 · 의뢰 수락), 긴급 도장(-14°).
- 조작: 클릭으로 고르기, ↑↓/W·S 로 위아래(잠긴 카드는 건너뜀, 끝에서 멈춤), Enter·Space·E 로 수락. 패널이 보일 때만 키를 받는다.
- 시그널: `accepted(request)`, `map_requested`. 씬을 바꾸는 일은 사무소가 한다.

### 4-3. 사무소 연결 (`office_screen.gd`)
- `%RequestsBoard.accepted` → `StageRun.start_request(request)` (의뢰 시작 + 스테이지 지도로).
- `%RequestsBoard.map_requested` → 공허 지도 패널(2번) 열기.
- 임시 버튼 `TestQuestButton` 과 `stage_scene` 칸은 지운다.
- 게시판은 의뢰 게시판 패널(`Panels/Requests`)의 바로 아래 자식으로 넣고 자리 (48,168) — 패널 틀 안쪽 노드에는 MCP·인스턴스로 자식을 넣기 어려워서. 패널의 "준비 중" 글은 새 칸 `OfficePanel.show_placeholder` 를 꺼서 숨긴다.

## 5. 그림 (`Art/ui/requests/`, Figma 에서 받음)

| 파일 | Figma 노드 | 크기 |
|---|---|---|
| `card_plate.svg` / `card_plate_selected.svg` / `card_plate_locked.svg` | 77:180 / 77:169 / 77:202 | 521×147 / 558×184(빛) / 521×93 |
| `chip_filled.svg` (전체·긴급 꽉 찬 모양, 연보라) · `chip_urgent.svg` (Rose) · `chip_main.svg` · `chip_repeat.svg` | 77:163 · 77:171 · 77:165 · 77:182 | NinePatch 로 늘림 (여백 6) |
| `diff_on.svg` / `diff_off.svg` | 77:176 / 77:188 | 11×11 |
| `client_portrait.svg` | 77:208 | 251.5×341.5 |
| `check_off.svg` | 77:234 | 23×23 |
| `reward_slot.svg` | 77:239 | 73×73 |
| `button_map.svg` / `button_accept.svg` | 77:244 / 77:246 | 221×61 / 279×105(빛) |
| `stamp_outer.svg` / `stamp_inner.svg` | 77:249 / 77:250 | 132 / 116 |
| `rule_diamond.svg` | 77:161 | 10×10 |

빛(`<filter>`)이 든 `card_plate_selected.svg`·`button_accept.svg` 는 Godot 이 빛을 빼고 가져올 수 있다 (UI 뼈대 때와 같음).

## 6. 구조

| 파일 | 종류 | 하는 일 |
|---|---|---|
| `Scripts/requests/request_data.gd` | Resource | 의뢰 한 건 + 글 만들기·정렬·필터 (GUT) |
| `Scripts/ui/request_card.gd` | Control | 카드 한 장 모양 |
| `Scripts/ui/requests_board.gd` | Control | 필터·목록·고르기·자세히·수락 |
| `Scripts/stage/stage_run.gd` | 자동 로드 | `start_request`, `current_request` 추가 |
| `Scripts/ui/office_screen.gd` | Control | 게시판 시그널 연결, 임시 버튼 삭제 |

## 7. 테스트

- `tests/requests/test_request_data.gd` — 카드 제목·장 줄, 정렬, 필터, 고를 수 있는지
- `tests/ui/test_requests_board.gd` — 처음 선택, 필터, 잠김 건너뛰기, 키 이동, 수락·지도 시그널, 자세히 글
- `tests/stage/test_stage_run.gd` — `start_request` 가 의뢰를 기억하고 시작, `end_run` 이 지움
- `tests/ui/test_office_screen.gd` — 수락하면 의뢰 시작, 지도에서 보기 → 2번 패널
