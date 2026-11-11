# 전투 격자판 칸 원근 사각형 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 격자판 칸을 배경 원근에 맞는 임의의 사각형으로 만들고, 보드 네 모서리 자동 분할과 칸별 꼭짓점 조정을 에디터 핸들로 제공한다.

**Architecture:** 순수 계산은 `BoardShape`(호모그래피·핸들 찾기), 그리기와 클릭은 `GridCell`, 칸 배치는 `BattleBoard`, 드래그는 새 에디터 플러그인이 맡는다. 칸 Control 의 위치·크기는 사각형의 경계 상자로 계산되고, 원본 데이터는 `BattleBoard.corners` 와 `GridCell.custom_corners` 다.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1

**Spec:** `docs/superpowers/specs/2026-11-11-board-cell-shape-design.md`

## Global Constraints

- 전투 규칙·격자 좌표·`board_position`·`use_cells` 의 칸 켜는 규칙은 바꾸지 않는다. 보드가 없는 배경의 기본 격자는 네모 유지.
- 테스트 외 모든 스크립트에 한국어 주석: 클래스 맨 위 `##`, `@export`·공개 함수·시그널 위 `##`.
- 에디터가 켜져 있으면 `.tscn`·`.tres`·`project.godot` 을 바깥에서 쓰지 않는다. Task 2, 4, 5 시작 전에 `tasklist | grep -i godot` 로 꺼진 것을 확인하고, 켜져 있으면 사용자에게 꺼 달라고 한다.
- GoPeak `scene-node-set` 은 쓰지 않는다. 씬은 복사본에서 Godot 헤드리스로 저장하고, 씬 맨 위 `uid` 와 `[ext_resource]` 의 `uid` 가 원본과 같은지 `git diff` 로 확인해 지워졌으면 되살린 뒤 원본에 옮긴다.
- 커밋은 사용자가 요청할 때만 한다. 지금 작업 트리의 미커밋 변경(칸 최소 크기 해제, 자식 편집 가능) 위에서 작업한다.
- **복사본 테스트:** 프로젝트를 `.git`·`.godot` 빼고 스크래치패드로 복사 → 복사본 `project.godot` 에서 `MCPRuntime` 줄과 `godot_mcp_editor`·`godot_mcp_runtime` 플러그인 제거 → `--headless --path . --log-file <별도> --import` → `--headless --path . --log-file <별도> -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`. 통과 기준은 `All tests passed!`.

## Review Focus

1. 네 모서리가 일직선이 되도록 드래그 (호모그래피 분모 0): 오류 없이 평행 사변형 계산으로 대체 → Task 1 테스트.
2. 인스펙터에서 `custom_corners` 에 4개가 아닌 점을 넣음: 자동 칸으로 취급 → Task 3 테스트.
3. 꼭짓점을 교차시켜 꼬인 사각형을 만듦: `draw_colored_polygon` 오류 없이 외곽선만 그림 → Task 2 테스트.
4. 다시 하기로 배치를 또 호출: 직접 잡은 칸이 유지되고 결과가 같음 → Task 3 테스트.
5. 원근 칸에서 유닛 박스 위치: 경계 상자 중심이 아니라 네 꼭짓점 평균에 놓임 → Task 3 테스트.

---

### Task 1: BoardShape 계산

**Files:**
- Create: `Scripts/ui/board_shape.gd`
- Test: `tests/ui/test_board_shape.gd`

**Interfaces:**
- Produces: `class_name BoardShape extends RefCounted`
  - `static func point_at(corners: PackedVector2Array, uv: Vector2) -> Vector2`
  - `static func cell_quad(corners: PackedVector2Array, col: int, row: int, gap: float, grid: int = 5) -> PackedVector2Array` — 순서: 왼쪽 위, 오른쪽 위, 오른쪽 아래, 왼쪽 아래
  - `static func nearest_handle(points: PackedVector2Array, at: Vector2, radius: float) -> int` — 반경 안 가장 가까운 점의 번호, 없으면 -1

- [ ] **Step 1: 실패하는 테스트 작성**

```gdscript
const SQ := PackedVector2Array([Vector2(0,0), Vector2(650,0), Vector2(650,650), Vector2(0,650)])
const TRAP := PackedVector2Array([Vector2(200,0), Vector2(450,0), Vector2(650,300), Vector2(0,300)])

func test_corners_map_exactly():
	assert_almost_eq(BoardShape.point_at(TRAP, Vector2(0,0)), TRAP[0], Vector2(.01,.01))
	assert_almost_eq(BoardShape.point_at(TRAP, Vector2(1,0)), TRAP[1], Vector2(.01,.01))
	assert_almost_eq(BoardShape.point_at(TRAP, Vector2(1,1)), TRAP[2], Vector2(.01,.01))
	assert_almost_eq(BoardShape.point_at(TRAP, Vector2(0,1)), TRAP[3], Vector2(.01,.01))

func test_square_is_linear():
	assert_almost_eq(BoardShape.point_at(SQ, Vector2(.5,.5)), Vector2(325,325), Vector2(.01,.01))

func test_far_rows_are_shorter():
	var far := BoardShape.cell_quad(TRAP, 2, 0, 0.0)
	var near := BoardShape.cell_quad(TRAP, 2, 4, 0.0)
	assert_lt(far[3].y - far[0].y, near[3].y - near[0].y)

func test_cell_quad_gap_is_centered():
	var q := BoardShape.cell_quad(SQ, 0, 0, 10.0 / 130.0)
	assert_almost_eq(q[0], Vector2(5,5), Vector2(.01,.01))
	assert_almost_eq(q[2], Vector2(125,125), Vector2(.01,.01))

func test_collinear_corners_do_not_crash():
	var line := PackedVector2Array([Vector2(0,0), Vector2(1,0), Vector2(2,0), Vector2(3,0)])
	var p := BoardShape.point_at(line, Vector2(.5,.5))
	assert_true(is_finite(p.x) and is_finite(p.y))

func test_nearest_handle():
	assert_eq(BoardShape.nearest_handle(SQ, Vector2(648,3), 10.0), 1)
	assert_eq(BoardShape.nearest_handle(SQ, Vector2(300,300), 10.0), -1)
```

- [ ] **Step 2: 복사본 테스트. 기대: `BoardShape` 없음으로 실패**

- [ ] **Step 3: `board_shape.gd` 구현**

단위 정사각형 → 사각형 호모그래피. `x0..x3` 은 corners 순서.

```
dx1=x1-x2  dx2=x3-x2  sx=x0-x1+x2-x3   (y 도 같은 식)
den=dx1*dy2-dx2*dy1
g=(sx*dy2-dx2*sy)/den   h=(dx1*sy-sx*dy1)/den    # den≈0 이면 g=h=0
a=x1-x0+g*x1  b=x3-x0+h*x3  c=x0
d=y1-y0+g*y1  e=y3-y0+h*y3  f=y0
결과 = ((a*u+b*v+c)/(g*u+h*v+1), (d*u+e*v+f)/(g*u+h*v+1))
```

`cell_quad` 의 단위 좌표: 왼쪽 `(col + gap/2)/grid`, 오른쪽 `(col + 1 - gap/2)/grid`, 행도 같다.

- [ ] **Step 4: 복사본 테스트. 기대: 통과**

### Task 2: GridCell 사각형 그리기·클릭

**Files:**
- Modify: `Scripts/ui/grid_cell.gd`
- Modify: `Scenes/ui/battle_screen/grid_cell.tscn` (루트 `ColorRect` → `Control`, `Mark` 자식 제거, `custom_minimum_size` 120 유지)
- Test: `tests/ui/test_battle_parts.gd`

**Interfaces:**
- Produces (`@tool`, `extends Control`):
  - `signal custom_corners_changed`
  - `@export var fill_color: Color = Color(0.16470589, 0.15294118, 0.2, 1)`
  - `@export var custom_corners: PackedVector2Array` — 판 기준, 세터에서 시그널 발생
  - `var quad: PackedVector2Array` — 칸 기준, 비면 네모
  - `func apply_quad(board_quad: PackedVector2Array) -> void` — 위치·크기를 경계 상자로, `quad` 를 칸 기준으로, 다시 그리기
  - `func center() -> Vector2` — 칸 기준. 비면 `size.max(custom_minimum_size) * 0.5`, 있으면 네 꼭짓점 평균
  - `func can_fill() -> bool` — `quad` 가 비었거나 `Geometry2D.triangulate_polygon` 결과가 있으면 true
  - `set_mark`, `mark_color`, `pressed`, `setup` 은 그대로

- [ ] **Step 1: 실패하는 테스트 작성 (`test_battle_parts.gd`)**

```gdscript
const CELL := "res://Scenes/ui/battle_screen/grid_cell.tscn"
const DIAMOND := PackedVector2Array([Vector2(50,0), Vector2(100,50), Vector2(50,100), Vector2(0,50)])

func test_quad_sets_bounds_and_local_points():
	var c: GridCell = _scene(CELL)
	c.custom_minimum_size = Vector2.ZERO
	c.apply_quad(PackedVector2Array([Vector2(60,10), Vector2(110,60), Vector2(60,110), Vector2(10,60)]))
	assert_eq(c.position, Vector2(10,10))
	assert_eq(c.size, Vector2(100,100))
	assert_eq(c.quad, DIAMOND)

func test_click_only_inside_quad():
	var c: GridCell = _scene(CELL)
	c.custom_minimum_size = Vector2.ZERO
	c.apply_quad(DIAMOND)
	assert_true(c._has_point(Vector2(50,50)))
	assert_false(c._has_point(Vector2(3,3)))

func test_no_quad_is_full_rect():
	var c: GridCell = _scene(CELL)
	assert_true(c._has_point(Vector2(3,3)))
	assert_eq(c.center(), Vector2(60,60))

func test_center_is_corner_average():
	var c: GridCell = _scene(CELL)
	c.custom_minimum_size = Vector2.ZERO
	c.apply_quad(PackedVector2Array([Vector2(0,0), Vector2(40,0), Vector2(100,60), Vector2(0,60)]))
	assert_eq(c.center(), Vector2(35,30))

func test_twisted_quad_cannot_fill():
	var c: GridCell = _scene(CELL)
	c.custom_minimum_size = Vector2.ZERO
	c.apply_quad(PackedVector2Array([Vector2(0,0), Vector2(100,100), Vector2(100,0), Vector2(0,100)]))
	assert_false(c.can_fill())
```

- [ ] **Step 2: 복사본 테스트. 기대: `apply_quad` 없음으로 실패**

- [ ] **Step 3: `grid_cell.gd` 구현.** `_draw`: `can_fill()` 이면 `fill_color` 로 채우고 지금 표시 색을 덧칠, 아니면 `draw_polyline` 외곽선만. `quad` 가 비면 `draw_rect`. `_has_point`: `quad` 가 비면 `Rect2(Vector2.ZERO, size).has_point`, 있으면 `Geometry2D.is_point_in_polygon`. `set_mark` 는 색을 저장하고 `queue_redraw`. `_mark` 노드 참조 제거.

- [ ] **Step 4: 복사본에서 헤드리스로 `grid_cell.tscn` 재저장 후 uid 확인 (Global Constraints). 복사본 테스트. 기대: 전부 통과**

- [ ] **Step 5: 씬을 원본에 옮긴다 (에디터 꺼짐 재확인)**

### Task 3: BattleBoard 배치와 유닛 박스

**Files:**
- Modify: `Scripts/ui/battle_board.gd`
- Modify: `Scripts/ui/battle_screen.gd:362`
- Test: `tests/ui/test_battle_board.gd`, `tests/ui/test_battle_screen.gd`

**Interfaces:**
- Consumes: `BoardShape.cell_quad`, `GridCell.apply_quad`, `GridCell.custom_corners`, `GridCell.custom_corners_changed`, `GridCell.center`
- Produces (`@tool`):
  - `@export var corners: PackedVector2Array = [(-5,-5), (645,-5), (645,645), (-5,645)]` — 650 정사각형. 틈 절반만큼 밖으로 잡아 지금의 130 간격·120 크기 배치와 정확히 같다
  - `@export_range(0.0, 0.49) var cell_gap: float = 10.0 / 130.0`
  - `func layout_cells() -> void`
  - `func cell_corners(col: int, row: int) -> PackedVector2Array` — 그 칸의 판 기준 꼭짓점. `custom_corners` 가 정확히 4개면 그것, 아니면 자동 값

- [ ] **Step 1: 실패하는 테스트 작성.** 기존 `test_each_cell_can_be_sized_freely` 는 지우고 아래로 바꾼다. `test_cells_have_no_minimum_and_start_at_120_in_place` 는 그대로 통과해야 한다.

```gdscript
const TRAP := PackedVector2Array([Vector2(200,0), Vector2(450,0), Vector2(650,650), Vector2(0,650)])

func test_board_corners_reshape_cells():
	var b := _board(A)
	b.corners = TRAP
	var far: GridCell = b.get_node(BattleBoard.cell_name(2, 0))
	var near: GridCell = b.get_node(BattleBoard.cell_name(2, 4))
	assert_lt(far.size.y, near.size.y)

func test_custom_corners_win_over_auto():
	var b := _board(A)
	var c: GridCell = b.get_node(BattleBoard.cell_name(1, 1))
	var mine := PackedVector2Array([Vector2(10,10), Vector2(50,10), Vector2(50,70), Vector2(10,70)])
	c.custom_corners = mine
	assert_eq(c.position, Vector2(10,10))
	assert_eq(c.size, Vector2(40,60))
	b.corners = TRAP
	assert_eq(c.position, Vector2(10,10))

func test_wrong_point_count_is_auto():
	var b := _board(A)
	var c: GridCell = b.get_node(BattleBoard.cell_name(1, 1))
	c.custom_corners = PackedVector2Array([Vector2(1,1), Vector2(2,2), Vector2(3,1)])
	assert_eq(c.position, Vector2(130,130))

func test_layout_twice_keeps_shape():
	var b := _board(A)
	var c: GridCell = b.get_node(BattleBoard.cell_name(1, 1))
	c.custom_corners = PackedVector2Array([Vector2(10,10), Vector2(50,10), Vector2(50,70), Vector2(10,70)])
	b.layout_cells()
	b.layout_cells()
	assert_eq(c.size, Vector2(40,60))
```

`test_battle_screen.gd` 에는 배경 보드의 칸 하나에 사다리꼴 `custom_corners` 를 준 뒤, 그 칸의 유닛 박스 중심이 `cell.center()` 와 같은지 확인하는 테스트를 기존 보드 테스트(247행 근처)의 준비 코드를 재사용해 추가한다.

- [ ] **Step 2: 복사본 테스트. 기대: 새 테스트 실패**

- [ ] **Step 3: 구현.** `_ready` 에서 칸의 `custom_corners_changed` 를 `layout_cells` 에 연결(이미 연결됐으면 건너뜀)하고 `layout_cells()` 호출. `corners`·`cell_gap` 세터는 노드가 준비됐을 때 `layout_cells()` 호출. 판 칸은 `cell_corners` → `apply_quad`. `battle_screen.gd:362` 는 `t.position = cell.center() - t.custom_minimum_size * 0.5` 로.

- [ ] **Step 4: 복사본 테스트. 기대: 전부 통과**

### Task 4: 에디터 핸들 플러그인

**Files:**
- Create: `addons/board_shape_editor/plugin.cfg`, `addons/board_shape_editor/plugin.gd`
- Modify: `project.godot` (`editor_plugins/enabled` 에 추가, 에디터 꺼진 상태에서)

**Interfaces:**
- Consumes: `BattleBoard.corners`, `BattleBoard.cell_corners`, `GridCell.custom_corners`, `GridCell.cell`이 아닌 노드 이름 `Cell_<열>_<행>` 으로 판 자리 파악, `BoardShape.nearest_handle`

- [ ] **Step 1: `plugin.gd` 구현 (`@tool extends EditorPlugin`).**
  - `_handles(object)`: `BattleBoard` 또는 `GridCell` (부모가 `BattleBoard` 일 때만).
  - `_edit`·`_make_visible` 로 대상 저장. `update_overlays()` 호출.
  - 판 기준 → 화면: `board.get_viewport_transform() * board.get_global_transform()`.
  - `_forward_canvas_draw_over_viewport(overlay)`: 네 점에 핸들 원과 외곽선.
  - `_forward_canvas_gui_input(event)`: 왼쪽 누름에서 `BoardShape.nearest_handle` (반경 10px) 로 핸들을 잡으면 `true` 를 돌려 입력을 먹는다. 이동 중엔 값을 직접 바꾸고, 놓을 때 `get_undo_redo()` 로 이전 값·새 값을 `add_do_property`/`add_undo_property` 해 한 번에 기록한다.
  - 칸의 첫 드래그: `custom_corners` 가 4개가 아니면 `board.cell_corners(col, row)` 를 시작값으로 삼는다. 실행 취소하면 원래 값(빈 배열)으로 돌아간다.

- [ ] **Step 2: 복사본에서 플러그인을 켠 상태로 `--headless --editor --quit` 실행. 기대: 로그에 `board_shape_editor` 관련 `SCRIPT ERROR`·`Parse Error` 없음**

- [ ] **Step 3: 복사본 테스트. 기대: 전부 통과**

### Task 5: 배경 시작 값과 마무리

**Files:**
- Modify: `Scenes/backgrounds/mountain_shrine.tscn`
- Modify: `docs/progress.md`, `CLAUDE.md` (격자판 조정법 한 줄)

- [ ] **Step 1: `mountain_shrine.tscn` 에 사용자가 옮긴 칸 값이 있는지 확인.** `Ally Board/Cell_` 로 시작하는 노드 블록이 있으면 멈추고 사용자에게 알린다.

- [ ] **Step 2: 복사본에서 헤드리스로 시작 값 저장 후 uid 확인.** 시안 A 기준(3행 × 4열), 판 기준 좌표:
  - `Ally Board.corners = [(122,278), (732,278), (683,939), (-536,939)]`
  - `Enemy Board.corners = [(1,280), (611,280), (1269,941), (49,941)]`

- [ ] **Step 3: 복사본 테스트. 기대: 전부 통과. 씬 인스턴스로 켜지는 칸의 화면 좌표를 출력해 바닥 범위(y 약 620~990) 안인지 확인**

- [ ] **Step 4: 씬을 원본에 옮기고 플러그인을 켠 `project.godot` 도 옮긴다 (에디터 꺼짐 재확인).** `docs/progress.md`·`CLAUDE.md` 갱신

- [ ] **Step 5: 사용자 확인 요청.** 에디터에서 보드 모서리·칸 꼭짓점 드래그, Ctrl+Z, 게임 실행 후 칸 클릭
