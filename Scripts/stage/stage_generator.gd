class_name StageGenerator
extends RefCounted
## 스테이지 지도를 랜덤 + 규칙으로 만든다. StageMap 화면이 스테이지에 들어갈 때마다 부른다.
##
## 규칙 (2026-11-07 사용자 결정):
##   - 3행. 시작(2행) → 가운데 3열 × 3행 = 전투 6 + 이벤트 3 → 상점(2행) → 보스(2행)
##   - 한 행에 이벤트는 최대 2개
##   - 시작은 첫 열 3개 모두와 이어지고, 마지막 열 3개는 모두 상점으로 모인다
##   - 가운데 노드는 다음 열의 1개 또는 2개와 이어진다 (같은 행 또는 바로 위/아래 행만)
##   - 모든 노드는 들어오는 길이 하나 이상 있고, 길끼리 X 자로 엇갈리지 않는다
## 방식: 랜덤으로 뽑고 → 규칙 검사 → 어긋나면 다시 뽑는다

const ROWS := 3                          ## 행 수
const MID_ROW := 1                       ## 가운데 행 (화면의 2행). 시작·상점·보스가 놓인다
const MID_COLUMNS := 3                   ## 전투·이벤트가 놓이는 열 수 (열 1 ~ 3)
const SHOP_COLUMN := MID_COLUMNS + 1     ## 상점 열
const BOSS_COLUMN := MID_COLUMNS + 2     ## 보스 열
const BATTLE_COUNT := 6                  ## 가운데 전투 노드 수
const EVENT_COUNT := 3                   ## 가운데 이벤트 노드 수
const MAX_EVENTS_PER_ROW := 2            ## 한 행에 놓일 수 있는 이벤트 최대 수
const MAX_TRIES := 100                   ## 다시 뽑기 최대 횟수 (사실상 몇 번 안에 통과)

var _rng := RandomNumberGenerator.new()


## seed_value: 같은 값이면 항상 같은 지도 (테스트용). 0 이면 매번 다른 지도.
func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value


## 지도 한 장을 만든다.
## 돌려주는 배열: [0] = 시작, 그다음 가운데 9개(열 순서, 같은 열은 위→아래), 그다음 상점, 마지막 = 보스
func generate() -> Array[StageNode]:
	# 1. 시작 노드
	var start := StageNode.new(StageNode.Kind.START, 0, MID_ROW)

	# 2. 가운데 노드: 종류를 먼저 정하고 격자에 놓는다. grid[열 - 1][행]
	var kinds := _roll_kinds()
	var grid: Array = []
	for c in MID_COLUMNS:
		var column_nodes: Array[StageNode] = []
		for r in ROWS:
			column_nodes.append(StageNode.new(kinds[r * MID_COLUMNS + c], c + 1, r))
		grid.append(column_nodes)

	# 3. 상점·보스 노드
	var shop := StageNode.new(StageNode.Kind.SHOP, SHOP_COLUMN, MID_ROW)
	var boss := StageNode.new(StageNode.Kind.BOSS, BOSS_COLUMN, MID_ROW)

	# 4. 길 잇기: 시작 → 첫 열 전부 / 가운데 열끼리 랜덤 / 마지막 열 전부 → 상점 → 보스
	for node in grid[0]:
		start.link_to(node)
	for c in MID_COLUMNS - 1:
		_link_columns(grid[c], grid[c + 1])
	for node in grid[MID_COLUMNS - 1]:
		node.link_to(shop)
	shop.link_to(boss)

	# 5. 한 배열로 모아서 돌려준다
	var all: Array[StageNode] = [start]
	for column_nodes in grid:
		all.append_array(column_nodes)
	all.append(shop)
	all.append(boss)
	return all


# --- 종류 정하기 ---

## 가운데 9칸의 종류. 인덱스 = 행 * MID_COLUMNS + 열(0부터). 규칙: 한 행에 이벤트 최대 2개
func _roll_kinds() -> Array:
	var kinds: Array = []
	for i in BATTLE_COUNT:
		kinds.append(StageNode.Kind.BATTLE)
	for i in EVENT_COUNT:
		kinds.append(StageNode.Kind.EVENT)
	for t in MAX_TRIES:
		_shuffle(kinds)
		if _kinds_ok(kinds):
			return kinds
	return kinds


## 모든 행의 이벤트 수가 MAX_EVENTS_PER_ROW 이하인지
func _kinds_ok(kinds: Array) -> bool:
	for r in ROWS:
		var events := 0
		for c in MID_COLUMNS:
			if kinds[r * MID_COLUMNS + c] == StageNode.Kind.EVENT:
				events += 1
		if events > MAX_EVENTS_PER_ROW:
			return false
	return true


# --- 길 잇기 ---

## 두 열 사이의 길을 뽑아서 잇는다. 규칙에 맞는 길을 못 찾으면 곧은 길(같은 행끼리)로 잇는다.
func _link_columns(from: Array, to: Array) -> void:
	for t in MAX_TRIES:
		var links := _roll_links()
		if _links_ok(links):
			for link in links:
				from[link.x].link_to(to[link.y])
			return
	for r in ROWS:
		from[r].link_to(to[r])


## 길 후보를 랜덤으로 뽑는다. 길 하나 = Vector2i(출발 행, 도착 행).
## 노드마다 1개 또는 2개, 도착은 같은 행 또는 바로 위/아래 행
func _roll_links() -> Array[Vector2i]:
	var links: Array[Vector2i] = []
	for r in ROWS:
		var options: Array = []
		for d in [-1, 0, 1]:
			if r + d >= 0 and r + d < ROWS:
				options.append(r + d)
		_shuffle(options)
		var count := _rng.randi_range(1, 2)
		for i in count:
			links.append(Vector2i(r, options[i]))
	return links


## 검사: 다음 열의 모든 노드에 들어오는 길이 있는지 + 길끼리 엇갈리지 않는지
func _links_ok(links: Array[Vector2i]) -> bool:
	# 1. 들어오는 길이 없는 노드가 있으면 탈락
	for r in ROWS:
		var has_incoming := false
		for link in links:
			if link.y == r:
				has_incoming = true
		if not has_incoming:
			return false
	# 2. 엇갈림: 위에서 출발한 길이 더 아래로 도착하면 X 자가 된다
	for a in links:
		for b in links:
			if a.x < b.x and a.y > b.y:
				return false
	return true


## 배열을 이 생성기의 랜덤으로 섞는다 (seed 가 같으면 같은 결과가 나오게)
func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
