@tool
extends EditorPlugin
## "연출 화면" 플러그인. 오른쪽 독에 PerformanceStageView(stage_view.tscn)를 붙이고,
## (하단 애니메이션 패널과 동시에 보이게 — 2026-11-19 사용자 요청. 독 메뉴로 떼어 내 크게 띄울 수도 있다)
## 편집 중인 씬이 바뀌면 창에 넘기고, 창이 보일 때만 에디터 프레임마다 다시 그리게 한다.
## (설계 docs/superpowers/specs/2026-11-19-performance-stage-view-design.md)

## 무대로 쓸 전투 (설계: 시험 전투 고정)
const BATTLE := "res://battles/test_battle.tres"
## 고른 배경을 기억하는 에디터 프로젝트 메타데이터 칸 (에디터를 다시 켜도 같은 배경)
const META_SECTION := "performance_stage_view"
const META_BACKGROUND := "background"
const META_ENEMY := "enemy"
const META_ACTOR_CELL := "actor_cell"
const META_ENEMY_CELL := "enemy_cell"
## 연출 카드를 찾을 폴더 (기본 행위자 정하기용)
const CARDS_DIR := "res://cards/data/"

var _view: PerformanceStageView
var _battle: BattleData


func _enter_tree() -> void:
	_view = preload("res://addons/performance_stage_view/stage_view.tscn").instantiate()
	_view.name = "연출 화면"  # 독 탭 제목
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _view)
	_battle = load(BATTLE)
	_view.set_battle.call_deferred(_battle)
	# 지난번에 고른 배경 (파일이 지워졌으면 창이 전투 데이터의 배경으로 돌아간다)
	var saved: String = EditorInterface.get_editor_settings().get_project_metadata(META_SECTION, META_BACKGROUND, "")
	if not saved.is_empty():
		_view.set_background.call_deferred(saved)
	_view.background_selected.connect(_on_background_selected)
	# 지난번에 고른 적 (파일이 지워졌으면 전투 데이터의 첫 적)
	var saved_enemy: String = EditorInterface.get_editor_settings().get_project_metadata(META_SECTION, META_ENEMY, "")
	if not saved_enemy.is_empty():
		_view.set_enemy.call_deferred(saved_enemy)
	_view.enemy_selected.connect(_on_enemy_selected)
	# 지난번에 고른 칸 (없으면 전투 데이터의 자리)
	var es := EditorInterface.get_editor_settings()
	var a_cell: Vector2i = es.get_project_metadata(META_SECTION, META_ACTOR_CELL, PerformanceStageView.NO_CELL)
	var e_cell: Vector2i = es.get_project_metadata(META_SECTION, META_ENEMY_CELL, PerformanceStageView.NO_CELL)
	if a_cell != PerformanceStageView.NO_CELL:
		_view.set_actor_cell.call_deferred(a_cell)
	if e_cell != PerformanceStageView.NO_CELL:
		_view.set_enemy_cell.call_deferred(e_cell)
	_view.actor_cell_selected.connect(func(c: Vector2i): es.set_project_metadata(META_SECTION, META_ACTOR_CELL, c))
	_view.enemy_cell_selected.connect(func(c: Vector2i): es.set_project_metadata(META_SECTION, META_ENEMY_CELL, c))
	scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred(EditorInterface.get_edited_scene_root())


func _exit_tree() -> void:
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if _view:
		remove_control_from_docks(_view)
		_view.queue_free()
		_view = null


## 편집 씬이 바뀜: 창에 넘기고, 이 연출을 쓰는 카드의 주인을 행위자로
func _on_scene_changed(root: Node) -> void:
	if _view == null:
		return
	_view.set_source(root)
	if root and _battle and _view.mirror():
		_view.set_actor(PerformanceStageView.default_actor(_battle, root.scene_file_path, CARDS_DIR))


## 배경을 고르면 기억해 둔다
func _on_background_selected(path: String) -> void:
	EditorInterface.get_editor_settings().set_project_metadata(META_SECTION, META_BACKGROUND, path)


## 적을 고르면 기억해 둔다
func _on_enemy_selected(path: String) -> void:
	EditorInterface.get_editor_settings().set_project_metadata(META_SECTION, META_ENEMY, path)


## 씬 저장 직전: 피격 슬로우모션으로 느려진 AnimationPlayer 배속이 씬에 저장되지 않게 되돌린다
func _save_external_data() -> void:
	if _view:
		_view.release_slowmo()


## 창이 보일 때만 그린다 (다른 탭·다른 씬일 때 에디터를 느리게 하지 않게). 숨으면 슬로우모션도 푼다
func _process(_delta: float) -> void:
	if _view == null:
		return
	if _view.is_visible_in_tree():
		_view.sync()
	else:
		_view.release_slowmo()
