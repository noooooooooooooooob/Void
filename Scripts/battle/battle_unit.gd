class_name BattleUnit
extends RefCounted
## 전투 중인 유닛 한 명 (아군 캐릭터 또는 적).
## 기본 스탯은 UnitData 에서 읽고, HP·SP·방어도·스태미너·상태·덱 같은 "지금 상태"는 여기서 들고 있다.
##
## 상태 붙이기·떼기는 보통 Battle.apply_status / change_stacks / remove_status 를 통해 한다.
## (그쪽이 이벤트 발행·트리거 구독·행동 순서 갱신까지 처리한다.)
## 여기 있는 add_status / change_stacks / remove_status 는 데이터만 바꾸는 하위 단계다.

## 기본 데이터 (스탯, 덱, 패시브, 장비)
var data: UnitData
## 편 (BattleTypes.Side)
var side: int
## 자기 편 격자 안의 칸 (열, 행). 열은 클수록 앞(상대 쪽).
var cell: Vector2i
## 현재 HP / SP / 방어도 / 스태미너
var hp: int
var sp: int = 0
var block: int = 0
var stamina: int
## 살아 있는지. HP 가 0 이 되면 false.
var alive: bool = true
## 붙어 있는 상태들
var statuses: Array[StatusInstance] = []
## 덱 / 손패 / 버린 카드 더미 (캐릭터마다 따로)
var deck: Array[CardData] = []
var hand: Array[CardData] = []
var discard: Array[CardData] = []
## 제외 더미: 이번 전투에서 다시 돌아오지 않는 카드 (소멸 키워드 등). 덱을 다시 섞을 때도 쓰지 않는다.
var exiled: Array[CardData] = []
## 이번 차례에 남은 이동력 (칸)
var move_left: int = 0
## 이번 라운드에 행동마다 굴린 속도 (보정 전 값). roll_speeds 가 채운다. 크기 = 행동 횟수.
var speed_rolls: Array[int] = []
## 보스가 다음에 쓸 카드의 순번 (보스는 덱 순서대로 쓴다)
var boss_index: int = 0
## 전투에 들어온 순서. 속도가 같을 때 순서를 정하는 기준.
var initial_index: int = 0
## 이 유닛이 속한 전투 (Battle). Battle 이 넣어 준다.
var battle

## 스탯 종류 → UnitData 의 기본값 필드 이름
const _BASE_FIELDS := {
	BattleTypes.Stat.HP: "max_hp",
	BattleTypes.Stat.SP: "max_sp",
	BattleTypes.Stat.ATTACK: "attack",
	BattleTypes.Stat.DEFENSE: "defense",
	BattleTypes.Stat.MOVE: "move",
	BattleTypes.Stat.CRIT_RATE: "crit_rate",
	BattleTypes.Stat.CRIT_DAMAGE: "crit_damage",
	BattleTypes.Stat.AGGRO: "aggro",
	BattleTypes.Stat.STAMINA: "max_stamina",
	BattleTypes.Stat.ACTIONS: "actions_per_round",
}


## 유닛을 만든다. HP 와 스태미너는 최대치로 시작한다.
## 장비는 착용하고 있으면 항상 적용되므로(사용자 결정), 만드는 순간 장비의 상태를 붙인다.
## (전투 밖 — 예: 파티 화면 — 에서 스탯을 봐도 장비가 반영된다. 장비 트리거는 전투가 구독을 연결한다)
func _init(unit_data: UnitData, unit_side: int, unit_cell: Vector2i) -> void:
	data = unit_data
	side = unit_side
	cell = unit_cell
	hp = data.max_hp
	stamina = data.max_stamina
	for equip in data.equipment:
		if equip == null:
			continue
		for status in equip.statuses:
			if status:
				add_status(status, 0, self)


## 지금 스탯 값. 기본값에 붙어 있는 모든 상태의 보정을 적용한다.
## 공식 (기획 결정): floor(기본 × (1 + %보정 합 / 100)) + 고정보정 합
## 값을 저장해 두지 않고 매번 계산한다 (HP 에 따라 변하는 보정이 있으므로).
func get_stat(stat: int) -> int:
	if stat == BattleTypes.Stat.SPEED:
		# 속도는 범위라 기본값이 하나가 아니다. 굴린 값에 보정을 적용하는 action_speed 를 쓴다.
		push_error("BattleUnit.get_stat(SPEED) 는 쓰지 않는다. action_speed(i) / modified_speed(v) 를 쓸 것")
		return 0
	return _modified(stat, data.get(_BASE_FIELDS[stat]))


## 이번 라운드의 속도를 굴린다: 행동 횟수만큼, 속도 범위(최소~최대) 안에서 하나씩. (기획 결정)
## rng 는 전투의 난수 생성기 (같은 시드면 같은 결과).
func roll_speeds(rng: RandomNumberGenerator) -> void:
	speed_rolls.clear()
	var lo := mini(data.speed_min, data.speed_max)
	var hi := maxi(data.speed_min, data.speed_max)
	for i in maxi(0, get_stat(BattleTypes.Stat.ACTIONS)):
		speed_rolls.append(rng.randi_range(lo, hi))


## i 번째 행동의 지금 속도 = 굴린 값에 속도 보정(감속·가속)을 적용한 값.
func action_speed(i: int) -> int:
	return modified_speed(speed_rolls[i])


## 속도 값 하나에 지금 붙어 있는 속도 보정을 적용한다.
func modified_speed(rolled: int) -> int:
	return _modified(BattleTypes.Stat.SPEED, rolled)


## 기본값 base 에 붙어 있는 모든 상태의 stat 보정을 적용한다.
## 공식 (기획 결정): floor(기본 × (1 + %보정 합 / 100)) + 고정보정 합
func _modified(stat: int, base: float) -> int:
	var percent := 0.0
	var flat := 0.0
	# 보정의 배율(scale)은 이 유닛 기준으로 계산한다.
	var ctx := EffectContext.new()
	ctx.actor = self
	ctx.owner = self
	ctx.battle = battle
	for inst in statuses:
		for mod in inst.data.modifiers:
			if mod.stat != stat:
				continue
			if mod.kind == BattleTypes.ModKind.PERCENT:
				percent += mod.contribution(ctx)
			else:
				flat += mod.contribution(ctx)
	return floori(base * (1.0 + percent / 100.0)) + floori(flat)


## 상태를 붙인다. 이미 같은 id 의 상태가 있으면 수치를 더하고 부여자를 갱신한다 (기획 결정: 수치 합침).
## 반환: 붙어 있는 상태 인스턴스 (새로 만들었든 합쳤든).
func add_status(status: StatusData, stacks: int, applier: BattleUnit) -> StatusInstance:
	var inst := get_status(status.id)
	if inst:
		inst.stacks += stacks
		inst.applier = applier
		return inst
	inst = StatusInstance.new()
	inst.data = status
	inst.owner = self
	inst.applier = applier
	inst.stacks = stacks
	statuses.append(inst)
	return inst


## id 로 붙어 있는 상태를 찾는다. 없으면 null.
func get_status(id: String) -> StatusInstance:
	for inst in statuses:
		if inst.data.id == id:
			return inst
	return null


## 상태의 현재 수치. 없으면 0.
func stacks_of(id: String) -> int:
	var inst := get_status(id)
	return inst.stacks if inst else 0


## 상태 수치를 delta 만큼 바꾼다. 수치를 쓰는 상태가 0 이하가 되면 제거한다.
## 단, 패시브(태그 PASSIVE)는 0 이 되어도 남는다 — 핏방울처럼 쌓았다가 비용으로 전부 쓰는 카운터가
## 사라지면 그 전투 동안 다시 쌓이지 않기 때문 (수치는 0 아래로 내려가지 않는다).
## 반환: 이번에 제거됐으면 true.
func change_stacks(id: String, delta: int) -> bool:
	var inst := get_status(id)
	if inst == null:
		return false
	inst.stacks += delta
	if inst.stacks <= 0 and inst.data.tag == BattleTypes.StatusTag.PASSIVE:
		inst.stacks = 0
		return false
	if inst.data.uses_stacks and inst.stacks <= 0:
		remove_status(id)
		return true
	return false


## 상태를 뗀다. 반환: 뗀 인스턴스 (active = false). 없으면 null.
func remove_status(id: String) -> StatusInstance:
	var inst := get_status(id)
	if inst == null:
		return null
	statuses.erase(inst)
	inst.active = false
	return inst
