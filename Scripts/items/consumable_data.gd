@tool
class_name ConsumableData
extends Resource
## 소비 아이템 하나 (회복약 등). 가방(Inventory)에 들어가고, 전투 중 아군 한 명에게 쓰면 사라진다.
## 데이터 파일은 items/consumables/<이름>.tres. 카드와 별개인 리소스다 (SP·덱·손패 규칙을 쓰지 않음).
## 칸은 두 부류로 나뉜다 (장비와 같은 분담, 설계: docs/superpowers/specs/2026-11-17-consumable-items-design.md):
##   - 웹 카드 에디터가 담당: id, 이름·설명, 키워드, 그림, 사용 대상(target), 범위(area), 효과 줄(lines).
##     카드 가져오기(ConsumableImporter)가 덮어쓴다.
##   - Godot 이 담당: effects (특수 효과). 가져오기가 건드리지 않는다.
## 대상·범위·음수 규칙: docs/superpowers/specs/2026-11-17-consumable-targets-design.md

## 쓸 수 있는 편. 새 값은 맨 뒤에 붙인다 (.tres 에 숫자로 저장됨).
enum Target {
	ALLY,   ## 아군에게만
	ENEMY,  ## 적에게만
	BOTH,   ## 아군·적 아무나
}

## 웹 에디터의 아이템 id. 직접 만든 시험 아이템은 비워 둔다 (id 없는 파일은 가져오기가 건드리지 않음).
@export var id: String
## 화면에 보일 이름 (한국어)
@export var display_name: String
## 영어 이름
@export var name_en: String
## 설명 (한국어)
@export_multiline var description_ko: String
## 설명 (영어)
@export_multiline var description_en: String
## 키워드 id 목록 (cards/keywords/ 의 키워드를 카드와 함께 쓴다. KeywordData.find 로 찾음)
@export var keywords: PackedStringArray = []
## 그림 경로 (res://items/consumables/art/…). 비어 있으면 그림 없음.
@export var art: String
## 쓸 수 있는 편 (기본 아군. 예전 아이템도 아군)
@export var target: Target = Target.ALLY
## 범위: 고른 유닛 칸 기준 오프셋 (카드 area 와 같은 좌표, -2..2). 비어 있으면 고른 유닛 한 명.
## 고른 유닛과 같은 편 격자에서만 찾는다. 칠하지 않은 (0,0) 은 고른 유닛도 빠진다 (카드 광역과 같은 규칙).
@export var area: Array[Vector2i] = []
## 효과 줄. 쓰면 위에서부터 차례로 범위 안 대상마다 적용된다.
@export var lines: Array[ConsumableLine] = []

@export_group("Godot")
## 특수 효과 (카드와 같은 효과 부품). lines 뒤에 실행된다. 행위자 없음, 주인·대상 = 아이템을 받은 유닛.
@export var effects: Array[CardEffect] = []


## side 편(BattleTypes.Side) 유닛에게 쓸 수 있는지 (target 기준).
func allows_side(side: int) -> bool:
	match target:
		Target.ALLY:
			return side == BattleTypes.Side.ALLY
		Target.ENEMY:
			return side == BattleTypes.Side.ENEMY
	return true


## 효과 줄 전체를 줄바꿈으로 이은 글. 예) "HP 회복 +30\nSP 회복 +2"
func describe_lines() -> String:
	var out := PackedStringArray()
	for l in lines:
		if l:
			out.append(l.describe())
	return "\n".join(out)
