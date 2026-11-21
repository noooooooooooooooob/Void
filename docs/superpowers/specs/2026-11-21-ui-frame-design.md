# UI 뼈대 (타이틀 · 메인 메뉴 · 사무소) 설계

작성 2026-11-21 · 브랜치 `feat/ui-frame` (예정)
디자인 원본: Figma `Project Void UI Wireframes` › 페이지 **v6 · 연보라 사이드 패널**
(https://www.figma.com/design/cPKjLHuAgOEmvdLHLDsYnr/Project-Void-UI-Wireframes?node-id=77-2)

## 1. 왜 만드는가

지금 게임은 회색 시작 화면 → 바로 스테이지 지도로 들어간다. v6 와이어프레임의 **사무소(로비) 중심 구조**를 먼저 깔아 두면,
그다음부터는 의뢰 게시판·사원 명부 같은 패널을 하나씩 채우기만 하면 된다.

- 성공: 게임을 켜면 타이틀 → 아무 키 → 메인 메뉴 → 새 게임 → 사무소. 왼쪽 레일 메뉴 7개를 누르면 오른쪽에 패널이 열리고 ESC·닫기로 닫힌다.
  의뢰 게시판 패널의 임시 버튼으로 지금 있는 의뢰(스테이지 지도)에 들어가고, 의뢰가 끝나면 사무소로 돌아온다.
- 비목표: 패널 7개의 실제 내용, 저장·불러오기, 설정 화면, 제작진 화면, 자금·하루 경과·사원 등급·피로도 시스템, 전투 HUD(08) 다듬기.

## 2. 범위 (사용자 결정 2026-11-21)

1. **공용 테마** — v6 연보라 팔레트로 버튼·패널·글자 스타일
2. **타이틀 → 메인 메뉴** (T-A, T-B) — 지금 `title_screen` 을 v6 모양으로 바꾼다
3. **사무소** (00-A) — 왼쪽 레일 + 오른쪽 위 자금·설정 HUD + 패널 자리
4. **패널 7개는 빈 틀** — 번호·제목·닫기만, 내용은 "준비 중". 다음 차례는 의뢰 게시판

배경 그림(메인 메뉴 키 아트, 사무소 배경)은 **사용자가 준비** — 그때까지 단색(Ink) + 연보라 그라데이션.

## 3. 디자인 규칙 (Figma 00-B 노트에서)

### 색 (`Scripts/ui/ui_palette.gd` 상수와 테마에 같은 값)
| 이름 | 값 | 쓰는 곳 |
|---|---|---|
| Ink | `#1A1626` | 화면 바탕, 밝은 버튼 위 글자 |
| Panel | `#29243B` | 패널 바탕 |
| Plate | `#3D3554` | 칩·작은 판 |
| Accent Lilac | `#CCB8FF` | 강조 글자, 선택 막대, 선택된 메뉴 |
| Line | `#B3A1E0` | 테두리·구분선 (투명도 16~55%) |
| Button 그라데이션 | `#E0D1FF → #AD94F0` | 주 버튼 (하루 마치기, 의뢰 수락) |
| Text | `#F2EDFC` | 본문 글자 |
| Sub | `#ADA3CC` | 보조 글자 (영문 부제, 상태) |
| Dim | `#786E94` | 번호, 작은 라벨 |
| Teal | `#66D1C7` | 스킬·완료 |
| Rose Red | `#F0738C` | 긴급·공격, 새 소식 배지 |
| Amber | `#F5CC80` | 자금·기사, 승급 가능 배지 |

### 글꼴 (모두 Google Fonts, OFL — 프로젝트에 넣어 배포 가능)
| 글꼴 | 쓰는 곳 |
|---|---|
| Noto Serif KR Bold | 한글 제목 (메뉴 이름, 패널 제목, 로고) |
| Noto Sans KR Regular/Medium | 한글 본문·상태 글 |
| Cormorant Garamond SemiBold Italic | 영문 부제 (Requests, Void Purifier) |
| IBM Plex Mono Medium/SemiBold | 번호·라벨·숫자 (01, FUNDS, DAY 03) |

`Art/fonts/` 에 넣는다. 테마 기본 글꼴은 Noto Sans KR, 나머지는 라벨마다 `theme_type_variation` 으로 고른다 (아래 4).

### 화면 크기
기준 1920×1080 (Figma 프레임과 같음). 프로젝트 설정이 이미 이 크기면 그대로.

## 4. 테마 `Scenes/ui/void_theme.tres`

프로젝트 설정 `gui/theme/custom` 에 지정해 모든 화면이 기본으로 쓴다 (기존 전투·상점 화면도 글꼴·색이 바뀜 → 깨지는 곳은 그 씬에서 덮어씀).

라벨 변형 (Label 의 Theme Type Variation 칸에 이름을 적는다):
| 변형 이름 | 글꼴 | 크기 | 색 |
|---|---|---|---|
| `TitleKo` | Noto Serif KR Bold | 25 | Text |
| `TitleEn` | Cormorant SemiBold Italic | 18 | Sub 80% |
| `MonoNumber` | IBM Plex Mono SemiBold | 14 | Dim |
| `MonoLabel` | IBM Plex Mono Medium | 11, 자간 넓게 | Dim |
| `StatusText` | Noto Sans KR Regular | 13 | Sub |
| `PanelTitle` | Noto Serif KR Bold | 48 | Text |
| `PanelTitleEn` | Cormorant SemiBold Italic | 28 | Sub |
| `LogoKo` | Noto Serif KR Bold | 108, 연보라 빛 그림자 | Text |
| `LogoEn` | Cormorant SemiBold Italic | 50 | Accent |

버튼 변형: `PrimaryButton`(그라데이션 판 그림, Ink 글자), `GhostButton`(투명 바탕 + Line 테두리, ESC 닫기·설정).

## 5. 화면

### 5-1. 타이틀 + 메인 메뉴 — `Scenes/ui/title_screen/title_screen.tscn` (메인 씬 그대로, uid 유지)

한 씬 안에서 두 상태를 오간다 (Figma 설명: "로고가 왼쪽 위로 이동하며 메뉴 페이드 인").

- **TITLE 상태 (T-A)**: 가운데 로고(영문 소제목 · 공허 정화자 · Void Purifier · 가제 · 선과 다이아몬드), 아래 "PRESS ANY KEY / 아무 키나 누르세요" 가 천천히 깜빡임. 로고·문구 뒤에 어두운 판(`logo_backdrop.svg`, `press_key_backdrop.svg`).
- 아무 키·클릭 → **MENU 상태 (T-B)**: 로고가 왼쪽 위(120, 110)로 0.5초 이동하며 작아지지 않음(같은 크기), 가운데 정렬 → 왼쪽 정렬. 메뉴·하단 안내가 페이드 인. 판들은 페이드 아웃, 왼쪽 어둡게(Left Fade)가 페이드 인.
- **메뉴 6줄**: 01 이어하기 / 02 새 게임 / 03 불러오기 / 04 설정 / 05 제작진 / 06 종료. 줄 = 번호(Mono) + 한글(Serif 28) + 영문(Cormorant 20).
  - 커서 줄: 왼쪽 연보라 막대 4px + 오른쪽으로 옅어지는 바탕 + 오른쪽 끝 화살표, 글자 Accent.
  - 조작: ↑↓·W/S 이동(끝에서 반대쪽으로 돌아감, 비활성 줄은 건너뜀), Enter/Space 실행, 마우스 올리면 커서 이동·클릭 실행, ESC → TITLE 상태로.
  - **이어하기·불러오기**: 저장 기능이 없어 비활성(흐리게, 커서가 건너뜀). 처음 커서는 첫 활성 줄(새 게임).
  - **최근 저장 카드**(이어하기 오른쪽): 저장이 없으니 숨김. 저장 기능이 생기면 이어하기에 커서가 있을 때만 보임.
  - **새 게임** → 사무소. **설정·제작진** → 아직 화면 없음, 누르면 아무 일 없이 "준비 중" 안내 한 줄. **종료** → 게임 종료.
- 아래: 왼쪽 버전 `v0.1.0`, 오른쪽 `ENTER 선택 · ↑↓ 이동 · ESC 뒤로`. 오른쪽 세로 글 `VOID PURIFIER — DISTRICT 07 — EST. 1924`.

### 5-2. 사무소 — `Scenes/ui/office_screen/office_screen.tscn` (새 씬)

- **배경**: 사용자 그림 자리(`TextureRect`, 비어 있으면 Ink) + 연보라 그라데이션.
- **왼쪽 레일** (폭 440, 항상 보임): 머리(◆ 주인공 사무소 / The Protagonist's Bureau / DAY 03 · AFTERNOON · CLOUDY), 구분선, `INDEX — 07`, 메뉴 7줄, 아래 **하루 마치기** 주 버튼(지금은 동작 없음), 오른쪽 세로 글.
  - 메뉴 줄 = `rail_menu_item.tscn` 7개: 01 의뢰 게시판 Requests · 02 공허 지도 Void Map · 03 사원 명부 Personnel · 04 승급장 Promotion Hall · 05 스파 Spa · 06 창고 Storage · 07 일지 Journal.
  - 줄 오른쪽 상태 글·배지(Rose 숫자 = 새 소식, Amber = 할 수 있는 일)는 칸만 두고 지금은 비움 (시스템 없음).
  - 열린 패널의 줄은 선택 모양(막대 + 바탕 + 패널 쪽 화살표·연결선).
- **오른쪽 위 HUD**: 자금 판(◆ FUNDS · 자금 / 숫자 / cr. / +) + 설정 버튼. 자금 시스템이 없어 숫자는 `office_screen.gd` 의 `funds` 값(기본 0). 설정은 "준비 중".
- **패널 자리**: (480, 96) 1400×944. 한 번에 패널 하나만 열림. 같은 메뉴를 다시 누르거나 ESC·닫기 → 닫힘. 다른 메뉴 → 바로 바꿔 열림.
- 아무 패널도 안 열렸을 때 오른쪽 아래 안내 "메뉴를 고르면 오른쪽에 창이 열립니다".
- 키보드: 1~7 숫자키로 메뉴 열기, ESC 로 닫기 (패널이 없을 때 ESC 는 아무 일 없음).

### 5-3. 패널 틀 — `Scenes/ui/office_screen/office_panel.tscn` (새 씬, 7번 instance)

- 바탕 그림(`panel_bg.svg`) + 머리: `No.01 / 07`, 제목(PanelTitle) + 영문(PanelTitleEn), 오른쪽 `BUREAU / REQUESTS` 경로 글, `ESC 닫기` 버튼, 머리 밑 선.
- **Content** (MarginContainer): 패널마다 내용이 들어갈 자리. 지금은 "준비 중" 글 하나.
- 값은 인스펙터 칸(`number`, `title_ko`, `title_en`, `path_label`)으로 — 같은 씬을 7번 넣고 칸만 다르게.
- 열기/닫기: 0.18초 페이드 + 왼쪽에서 16px 밀려 들어옴.
- 나중에 각 패널을 채울 때는 이 씬을 **상속한 씬**(`requests_panel.tscn` …)을 만들어 Content 아래에 넣는다.

### 5-4. 의뢰 게시판 임시 버튼

의뢰 게시판 패널의 Content 에 **"시험 의뢰 출발"** 버튼 하나 → 스테이지 지도(`StageMap` 이 알아서 `start_run`). 의뢰 게시판을 제대로 만들 때 지운다.

## 6. 흐름 변경

- `StageRun` 의 의뢰 실패·성공·비정상 종료가 돌아가는 곳: 시작 화면 → **사무소** (`OFFICE_SCENE`).
- 타이틀의 `next_scene`(스테이지 지도) 칸은 없앤다 → 새 게임은 `office_scene` 칸(사무소 씬).

## 7. 구조

| 파일 | 종류 | 하는 일 |
|---|---|---|
| `Scripts/ui/ui_palette.gd` | 상수 | v6 색 (스크립트에서 색을 바꿀 때) |
| `Scripts/ui/menu_cursor.gd` | RefCounted | 메뉴 커서: 위/아래(돌아감, 비활성 건너뜀), 처음 위치. GUT 로 테스트 |
| `Scripts/ui/main_menu_item.gd` | Control | 메인 메뉴 한 줄 (번호·이름·영문, 선택·비활성 모양) |
| `Scripts/ui/title_screen.gd` | Control | 타이틀 ↔ 메뉴 상태, 키 입력, 메뉴 실행 |
| `Scripts/ui/rail_menu_item.gd` | Control | 레일 메뉴 한 줄 (번호·이름·영문·상태·배지, 선택 모양) |
| `Scripts/ui/office_panel.gd` | Control | 패널 틀 (머리 글, 닫기, 열기/닫기 연출) |
| `Scripts/ui/office_screen.gd` | Control | 레일 ↔ 패널 열고 닫기, 숫자키·ESC, HUD 자금 |

노드는 모두 에디터에서 만든다 (CLAUDE.md "에디터 우선" — 이번엔 GoPeak MCP 로 Claude 가 에디터 안에서 작업). 스크립트는 값 갱신·입력·연출만.

## 8. 그림 (Figma 에서 받음, `Art/ui/`)

| 파일 | Figma 노드 | 크기 |
|---|---|---|
| `title/logo_backdrop.svg` | 94:88 Logo Backdrop | 1260×560 (그림자 포함) |
| `title/press_key_backdrop.svg` | 94:89 | 900×290 |
| `main_menu/logo_diamond.svg` | 94:34 | 10×10 |
| `main_menu/menu_arrow.svg` | 94:39 | 15×22 |
| `main_menu/save_card_plate.svg` | 94:65 | 441×231 |
| `office/rail_diamond.svg` | 81:6 | 14×14 |
| `office/rail_pointer.svg` | 81:77 | 23×34 |
| `office/badge_rose.svg`, `badge_amber.svg` | 81:19, 81:39 | 22×22 |
| `office/end_day_button.svg` | 81:59 | 405×125 (빛 포함) |
| `office/funds_plate.svg`, `funds_diamond.svg` | 77:62, 77:63 | 257×57, 14×14 |
| `office/settings_button.svg` | 77:68 | 89×57 |
| `office/panel_bg.svg` | 77:147 | 1521×1065 (그림자 포함) |
| `office/close_button.svg` | 77:158 | 95×37 |

주의: 그림자·빛이 SVG `<filter>` 로 들어간 파일(logo/press_key backdrop, save_card_plate, end_day_button, panel_bg)은 Godot SVG 가져오기가 filter 를 무시할 수 있다. 에디터에서 보고 빠졌으면 테마 StyleBoxFlat 그림자로 대신한다.

## 9. 테스트

- `tests/ui/test_menu_cursor.gd` — 커서 규칙 (씬 없이)
- `tests/ui/test_title_screen.gd` — 아무 키 → 메뉴 상태, 비활성 줄 건너뛰기, ESC → 타이틀
- `tests/ui/test_office_screen.gd` — 메뉴 → 패널 열림·제목, 같은 메뉴 다시 → 닫힘, 다른 메뉴 → 바뀜, ESC 닫힘, 숫자키
- `tests/stage/test_stage_run.gd` — 의뢰 끝나면 사무소로 (경로 상수)

씬 테스트는 씬을 에디터에서 만든 뒤 통과해야 한다.
