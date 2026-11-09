extends Node
## 의뢰(스테이지) 한 판의 진행 상태. 자동 로드(프로젝트 설정 → 전역 → 자동 로드) "StageRun" 으로 항상 떠 있어서
## 씬이 바뀌어도(지도 → 전투 → 지도) 지도·현재 위치·파티 체력이 남는다.
##
## 흐름:
##   시작 화면 → 지도(StageMap)가 start_run() → 노드 고르고 enter_selected()
##     전투·보스 → 전투 화면(stage 모드) → 승리 complete_node() / 패배 fail_run()
##     이벤트·상점 → 방 화면(RoomScreen) → 선택지·다음 버튼 complete_node()
##   complete_node() 후 보스까지 끝났으면 방 화면(의뢰 성공) → "처음으로" end_run()
## 규칙 (CLAUDE.md 의뢰 스테이지): 의뢰 안에서는 체력 유지, HP 0 파티원은 남은 전투 제외,
##   의뢰가 끝나면 전원 회복(다음 start_run 에서 파티를 새로 만든다)

## 방 화면이 무엇을 보여줄지
enum Room { EVENT, SHOP, CLEAR }

## 씬 경로 (파일을 옮기면 여기도 고친다)
const TITLE_SCENE := "res://Scenes/ui/title_screen/title_screen.tscn"
const STAGE_MAP_SCENE := "res://Scenes/ui/stage_map/stage_map.tscn"
const BATTLE_SCENE := "res://Scenes/ui/battle_screen/battle_screen.tscn"
const ROOM_SCENE := "res://Scenes/ui/room_screen/room_screen.tscn"
## 지금은 모든 전투(보스 포함)가 이 시험 전투를 쓴다. 노드별 전투 데이터는 나중에
const DEFAULT_BATTLE := preload("res://battles/test_battle.tres")

## 지도 진행 상태. 의뢰 중이 아니면 null
var progress: StageProgress = null
## 의뢰 파티 (전투마다 같은 유닛을 다시 넣어서 HP 를 유지한다)
var party: Array[BattleUnit] = []


## 의뢰 중인지 (지도가 만들어져 있는지)
func is_active() -> bool:
	return progress != null


## 새 의뢰를 시작한다: 지도를 새로 만들고 파티를 가득 찬 체력으로 새로 만든다.
## seed_value: 0 이면 매번 다른 지도
func start_run(seed_value: int = 0) -> void:
	progress = StageProgress.new(StageGenerator.new(seed_value).generate())
	party.clear()
	for u in DEFAULT_BATTLE.make_units():
		if u.side == BattleTypes.Side.ALLY:
			party.append(u)


## 의뢰를 끝내고 상태를 비운다 (다음 start_run 에서 전원 회복된 파티로 시작)
func end_run() -> void:
	progress = null
	party.clear()


## 커서가 가리키는 노드를 실행한다 (지도에서 스페이스·엔터·고른 노드 다시 클릭).
## 전투·보스 → 전투 화면, 이벤트·상점 → 방 화면
func enter_selected() -> void:
	if not is_active():
		return
	var node := progress.enter()
	if node == null:
		return
	if node.is_battle():
		_go(BATTLE_SCENE)
	else:
		_go(ROOM_SCENE)


## 지금 전투 노드에 들어가 있는지 (전투 화면이 의뢰 모드로 돌지 판단)
func in_battle() -> bool:
	return is_active() and progress.entering != null and progress.entering.is_battle()


## 지금 전투 노드의 전투 데이터
func battle_data() -> BattleData:
	return DEFAULT_BATTLE


## 전투에 나갈 파티: 살아 있는 파티원만 (HP 0 이면 남은 전투에서 빠진다)
func living_party() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in party:
		if u.alive and u.hp > 0:
			out.append(u)
	return out


## 방 화면이 보여줄 것: 보스까지 끝났으면 의뢰 성공, 아니면 들어가 있는 노드 종류(이벤트/상점)
func room() -> Room:
	if is_active() and progress.is_finished():
		return Room.CLEAR
	if is_active() and progress.entering and progress.entering.kind == StageNode.Kind.SHOP:
		return Room.SHOP
	return Room.EVENT


## 들어가 있던 노드를 끝낸다 (전투 승리, 이벤트 선택, 상점 다음).
## 보스였으면 방 화면(의뢰 성공), 아니면 지도로 돌아간다
func complete_node() -> void:
	if not is_active():
		_go(TITLE_SCENE)
		return
	progress.complete()
	if progress.is_finished():
		_go(ROOM_SCENE)
	else:
		_go(STAGE_MAP_SCENE)


## 의뢰 실패 (전투 패배): 의뢰를 끝내고 시작 화면으로
func fail_run() -> void:
	end_run()
	_go(TITLE_SCENE)


## 의뢰 성공 화면의 "처음으로": 의뢰를 끝내고 시작 화면으로
func finish_run() -> void:
	end_run()
	_go(TITLE_SCENE)


## 씬을 바꾼다. 씬 안에서 부르면 그 프레임이 끝난 뒤에 바뀐다
func _go(path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(path)
