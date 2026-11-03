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
## 이번 차례에 남은 이동력 (칸)
var move_left: int = 0
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
	BattleTypes.Stat.SPEED: "speed",
	BattleTypes.Stat.MOVE: "move",
	BattleTypes.Stat.CRIT_RATE: "crit_rate",
	BattleTypes.Stat.CRIT_DAMAGE: "crit_damage",
	BattleTypes.Stat.AGGRO: "aggro",
	BattleTypes.Stat.STAMINA: "max_stamina",
}


## 유닛을 만든다. HP 와 스태미너는 최대치로 시작한다.
func _init(unit_data: UnitData, unit_side: int, unit_cell: Vector2i) -> void:
	data = unit_data
	side = unit_side
	cell = unit_cell
	hp = data.max_hp
	stamina = data.max_stamina


## 지금 스탯 값. 기본값에 붙어 있는 모든 상태의 보정을 적용한다.
## 공식 (기획 결정): floor(기본 × (1 + %보정 합 / 100)) + 고정보정 합
## 값을 저장해 두지 않고 매번 계산한다 (HP 에 따라 변하는 보정이 있으므로).
func get_stat(stat: int) -> int:
	var base: int = data.get(_BASE_FIELDS[stat])
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
## 반환: 이번에 제거됐으면 true.
func change_stacks(id: String, delta: int) -> bool:
	var inst := get_status(id)
	if inst == null:
		return false
	inst.stacks += delta
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
