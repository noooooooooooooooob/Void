extends Node
## 의뢰(공허 하나에 들어가서 보스까지) 한 판의 진행 상태. 자동 로드(프로젝트 설정 → 전역 → 자동 로드) "StageRun" 으로 항상 떠 있어서
## 씬이 바뀌어도(지도 → 전투 → 지도) 지도·현재 위치·파티 체력이 남는다.
##
## 흐름:
##   공허 지도에서 공허 선택 → start_run(공허) → 스테이지 지도(StageMap)에서 노드 고르고 enter_selected()
##     전투·보스 → 전투 화면(의뢰 모드) → 승리 complete_node() / 패배 fail_run()
##     이벤트·상점 → 방 화면(RoomScreen) → 선택지·다음 버튼 complete_node()
##   complete_node() 후 보스까지 끝났으면 방 화면(의뢰 성공) → finish_run() → 공허 지도
## 규칙 (CLAUDE.md 의뢰 스테이지): 의뢰 안에서는 체력 유지, HP 0 파티원은 남은 전투 제외, 의뢰가 끝나면 전원 회복
##   (다음 start_run 에서 파티를 새로 만든다). 보스 승리 = 성공, 패배 = 실패 → 둘 다 월드맵(공허 지도)으로 복귀

## 방 화면이 무엇을 보여줄지
enum Room { EVENT, SHOP, CLEAR }

## 지금은 모든 전투(보스 포함)가 이 시험 전투의 적 구성을 쓴다. 노드별 전투 데이터는 나중에
const DEFAULT_BATTLE := preload("res://battles/test_battle.tres")
## 사원 명부. 파티는 앞에서부터 전투 데이터의 아군 자리 수만큼
const ROSTER := preload("res://entities/roster.tres")

## 지도 진행 상태. 의뢰 중이 아니면 null
var progress: StageProgress = null
## 지금 들어가 있는 공허 (개발용으로 공허 없이 시작하면 null)
var site: VoidSiteData = null
## 의뢰 파티 (전투마다 같은 유닛을 다시 넣어서 HP 를 유지한다)
var party: Array[BattleUnit] = []
## 정화(성공)한 공허 id → true. 게임을 끄면 사라진다 (저장은 아직 없음)
var cleared_sites: Dictionary = {}
## false 면 화면을 실제로 바꾸지 않고 last_screen 에만 적는다 (테스트용)
var navigate := true
## 마지막으로 가려고 한 화면 (Router.Screen)
var last_screen: int = -1


## 의뢰 중인지 (지도가 만들어져 있는지)
func is_active() -> bool:
	return progress != null


## p_site 공허로 새 의뢰를 시작한다: 지도를 새로 만들고 사원 명부 캐릭터로 파티를 가득 찬 체력으로 새로 만든다.
## p_site: 들어갈 공허 (null 이면 공허 없이 — 배경은 전투 데이터 것). seed_value: 0 이면 매번 다른 지도
func start_run(p_site: VoidSiteData = null, seed_value: int = 0) -> void:
	site = p_site
	progress = StageProgress.new(StageGenerator.new(seed_value).generate())
	# 파티: 명부 캐릭터를 전투 데이터의 아군 자리에 앞에서부터 하나씩
	party.clear()
	var slots := DEFAULT_BATTLE.allies
	for i in mini(ROSTER.units.size(), slots.size()):
		party.append(BattleUnit.new(ROSTER.units[i], BattleTypes.Side.ALLY, slots[i].cell))


## 의뢰를 끝내고 상태를 비운다 (다음 start_run 에서 전원 회복된 파티로 시작)
func end_run() -> void:
	progress = null
	site = null
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
		_go(Router.Screen.BATTLE)
	else:
		_go(Router.Screen.ROOM)


## 지금 전투 노드에 들어가 있는지 (전투 화면이 의뢰 모드로 돌지 판단)
func in_battle() -> bool:
	return is_active() and progress.entering != null and progress.entering.is_battle()


## 지금 전투 노드의 전투 데이터 (적 구성·격자)
func battle_data() -> BattleData:
	return DEFAULT_BATTLE


## 전투 배경 씬: 들어가 있는 공허의 배경, 공허가 없으면 전투 데이터의 배경
func battle_background() -> PackedScene:
	if site and site.background:
		return site.background
	return battle_data().background


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


## 공허 id 를 정화했는지 (공허 지도 표시용)
func is_cleared(site_id: String) -> bool:
	return cleared_sites.has(site_id)


## 들어가 있던 노드를 끝낸다 (전투 승리, 이벤트 선택, 상점 다음).
## 보스였으면 방 화면(의뢰 성공), 아니면 스테이지 지도로 돌아간다
func complete_node() -> void:
	if not is_active():
		_go(Router.Screen.VOID_MAP)
		return
	progress.complete()
	if progress.is_finished():
		_go(Router.Screen.ROOM)
	else:
		_go(Router.Screen.STAGE_MAP)


## 의뢰 실패 (전투 패배): 의뢰를 끝내고 공허 지도로 (정화 기록 없음)
func fail_run() -> void:
	end_run()
	_go(Router.Screen.VOID_MAP)


## 의뢰 성공 화면의 버튼: 공허를 정화 기록에 넣고 의뢰를 끝낸 뒤 공허 지도로
func finish_run() -> void:
	if is_active() and progress.is_finished() and site:
		cleared_sites[site.id] = true
	end_run()
	_go(Router.Screen.VOID_MAP)


## 화면을 바꾼다 (navigate 가 false 면 기록만)
func _go(screen: int) -> void:
	last_screen = screen
	if navigate:
		Router.goto(screen)
