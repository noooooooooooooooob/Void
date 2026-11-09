@tool
class_name PullEffect
extends CardEffect
## 대상을 그 편 격자의 맨 앞 열, 행위자와 같은 행으로 끌어온다. 이동력은 쓰지 않는다.
## 그 칸에 다른 유닛이 있으면 움직이지 않는다. 범위가 넓어도 먼저 도착한 대상만 그 칸을 차지한다.
## 예) 갈고리 걸기: ATK 60% 피해 → 끌어오기


func apply(ctx: EffectContext) -> void:
	var row := stat_unit(ctx).cell.y
	for t in resolve_targets(ctx):
		ctx.battle.force_move(t, Vector2i(ctx.battle.cols_of(t.side) - 1, row))
