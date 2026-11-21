extends Node
## 의뢰(스테이지) 한 판의 진행 상태. 자동 로드(프로젝트 설정 → 전역 → 자동 로드) "StageRun" 으로 항상 떠 있어서
## 씬이 바뀌어도(지도 → 전투 → 지도) 지도·현재 위치·파티 체력이 남는다.
##
## 흐름:
##   사무소(의뢰 게시판) → 지도(StageMap)가 start_run() → 노드 고르고 enter_selected()
##     전투·보스 → 전투 화면(stage 모드) → 승리 complete_node() / 패배 fail_run()
##     이벤트 → 방 화면(RoomScreen) → 선택지 complete_node()
##     상점 → 상점 화면(ShopScreen) → 나가기 complete_node()
##   complete_node() 후 보스까지 끝났으면 방 화면(의뢰 성공) → "처음으로" end_run() → 사무소
## 규칙 (CLAUDE.md 의뢰 스테이지): 의뢰 안에서는 체력 유지, HP 0 파티원은 남은 전투 제외,
##   의뢰가 끝나면 전원 회복(다음 start_run 에서 파티를 새로 만든다)

## 방 화면이 무엇을 보여줄지
## 상점은 상점 화면(ShopScreen)이 맡아서 방 화면에는 오지 않는다 (2026-11-17)
enum Room { EVENT, CLEAR }

## 씬 경로 (파일을 옮기면 여기도 고친다)
## 의뢰가 끝나면(성공·실패) 돌아갈 사무소 (2026-11-21, 그전엔 시작 화면)
const OFFICE_SCENE := "res://Scenes/ui/office_screen/office_screen.tscn"
const STAGE_MAP_SCENE := "res://Scenes/ui/stage_map/stage_map.tscn"
const BATTLE_SCENE := "res://Scenes/ui/battle_screen/battle_screen.tscn"
const ROOM_SCENE := "res://Scenes/ui/room_screen/room_screen.tscn"
## 상점 노드가 여는 상점 화면 (상점 설계 2026-11-17)
const SHOP_SCENE := "res://Scenes/ui/shop_screen/shop_screen.tscn"
## 일반 전투 노드가 쓰는 전투 데이터 (지금은 시험 전투 하나. 노드별 전투 데이터는 나중에)
const DEFAULT_BATTLE := preload("res://battles/test_battle.tres")
## 보스 노드가 쓰는 전투 데이터 (2026-11-17: 보스 보상 공허 조각 50 을 따로 두려고 분리)
const BOSS_BATTLE := preload("res://battles/boss_battle.tres")
## 드랍 후보가 되는 소비 아이템 폴더 (이 폴더의 .tres 전부. 하위 폴더는 보지 않는다)
const ITEM_DIR := "res://items/consumables"

## 지도 진행 상태. 의뢰 중이 아니면 null
var progress: StageProgress = null
## 의뢰 파티 (전투마다 같은 유닛을 다시 넣어서 HP 를 유지한다)
var party: Array[BattleUnit] = []
## 파티 공용 가방 (소비 아이템 5칸). 의뢰 시작 때 비어 있고 의뢰가 끝나면 비워진다 — 의뢰 밖으로 가져가지 못한다
var inventory := Inventory.new()
## 공허 조각 지갑. 의뢰 시작 때 0 이고 의뢰가 끝나면 사라진다 (상점 설계 2026-11-17)
var wallet := Wallet.new()


## 의뢰 중인지 (지도가 만들어져 있는지)
func is_active() -> bool:
	return progress != null


## 새 의뢰를 시작한다: 지도를 새로 만들고 파티를 가득 찬 체력으로 새로 만든다.
## seed_value: 0 이면 매번 다른 지도
func start_run(seed_value: int = 0) -> void:
	progress = StageProgress.new(StageGenerator.new(seed_value).generate())
	party.clear()
	inventory = Inventory.new()
	wallet = Wallet.new()
	for u in DEFAULT_BATTLE.make_units():
		if u.side == BattleTypes.Side.ALLY:
			party.append(u)


## 의뢰를 끝내고 상태를 비운다 (다음 start_run 에서 전원 회복된 파티로 시작)
func end_run() -> void:
	progress = null
	party.clear()
	inventory = Inventory.new()
	wallet = Wallet.new()


## 커서가 가리키는 노드를 실행한다 (지도에서 스페이스·엔터·고른 노드 다시 클릭).
## 열 화면은 scene_for 가 정한다
func enter_selected() -> void:
	if not is_active():
		return
	var node := progress.enter()
	if node == null:
		return
	_go(scene_for(node))


## 노드 종류마다 여는 화면: 전투·보스 → 전투 화면, 상점 → 상점 화면, 이벤트 → 방 화면
func scene_for(node: StageNode) -> String:
	if node.is_battle():
		return BATTLE_SCENE
	if node.kind == StageNode.Kind.SHOP:
		return SHOP_SCENE
	return ROOM_SCENE


## 지금 전투 노드에 들어가 있는지 (전투 화면이 의뢰 모드로 돌지 판단)
func in_battle() -> bool:
	return is_active() and progress.entering != null and progress.entering.is_battle()


## 지금 들어가 있는 노드가 보스 전투인지 (보스는 이기면 의뢰가 끝나므로 아이템 드랍이 없다)
func is_boss_battle() -> bool:
	return is_active() and progress.entering != null and progress.entering.kind == StageNode.Kind.BOSS


## dir 폴더의 소비 아이템 전부 (드랍 후보). 폴더가 없거나 아이템이 없으면 빈 배열.
## (.remap 처리는 ResDir.tres_paths 가 한다)
func item_pool(dir: String = ITEM_DIR) -> Array[ConsumableData]:
	var out: Array[ConsumableData] = []
	for path in ResDir.tres_paths(dir):
		var item := load(path) as ConsumableData
		if item:
			out.append(item)
	return out


## 전투 승리 드랍 판정: chance(0~1) 확률로 pool 중 하나를 같은 확률로 고른다. 꽝이거나 pool 이 비었으면 null.
## rng 는 전투 난수(Battle.rng)와 다른 것을 넘긴다 — 같은 시드의 전투 결과가 드랍 때문에 달라지지 않게.
func roll_item_drop(chance: float, pool: Array[ConsumableData], rng: RandomNumberGenerator) -> ConsumableData:
	if pool.is_empty() or rng.randf() >= chance:
		return null
	return pool[rng.randi_range(0, pool.size() - 1)]


## 지금 전투 노드의 전투 데이터: 보스 노드면 보스용, 아니면 일반
func battle_data() -> BattleData:
	if is_boss_battle():
		return BOSS_BATTLE
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
	return Room.EVENT


## 들어가 있던 노드를 끝낸다 (전투 승리, 이벤트 선택, 상점 다음).
## 보스였으면 방 화면(의뢰 성공), 아니면 지도로 돌아간다
func complete_node() -> void:
	if not is_active():
		_go(OFFICE_SCENE)
		return
	progress.complete()
	if progress.is_finished():
		_go(ROOM_SCENE)
	else:
		_go(STAGE_MAP_SCENE)


## 의뢰 실패 (전투 패배): 의뢰를 끝내고 사무소로
func fail_run() -> void:
	end_run()
	_go(OFFICE_SCENE)


## 지도·전투 화면의 "← 사무소로" 버튼: 확인 없이 의뢰를 끝내고 사무소로 (2026-11-21 사용자 결정).
## 결과는 실패와 같다 — 파티 체력·가방·공허 조각이 모두 사라진다
func leave_run() -> void:
	end_run()
	_go(OFFICE_SCENE)


## 의뢰 성공 화면의 "처음으로": 의뢰를 끝내고 사무소로
func finish_run() -> void:
	end_run()
	_go(OFFICE_SCENE)


## 씬을 바꾼다. 씬 안에서 부르면 그 프레임이 끝난 뒤에 바뀐다
func _go(path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(path)
