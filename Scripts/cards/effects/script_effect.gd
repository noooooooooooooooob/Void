@tool
class_name ScriptEffect
extends CardEffect
## 전용 스크립트 효과. 부품 조합으로 만들 수 없는 1장짜리 효과를 위한 예외용. (설계 문서 1장)
## effect_script 는 apply(ctx: EffectContext) 함수를 가진 스크립트여야 한다.
## 실행할 때마다 그 스크립트의 새 인스턴스를 만들어 apply(ctx) 를 부른다.
## 같은 효과가 카드 2장 이상에 쓰이면 전용 스크립트 대신 효과 부품으로 만든다 (팀 기준).
## 예) 혈갑: 공격태세의 "공격을 한 번 더"

## 실행할 스크립트 (apply(ctx) 를 구현). Object 의 내장 속성 이름인 script 와 겹치지 않게 effect_script.
@export var effect_script: GDScript


func apply(ctx: EffectContext) -> void:
	if effect_script == null:
		return
	effect_script.new().apply(ctx)
