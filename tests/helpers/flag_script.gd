extends RefCounted
# ScriptEffect 테스트용: 실행되면 ctx.values["ran"] 을 true 로.

func apply(ctx: EffectContext) -> void:
	ctx.values["ran"] = true
