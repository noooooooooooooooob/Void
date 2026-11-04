extends SceneTree
## GDScript 파일들을 게임이 실제로 불러오는 방식 그대로 load() 해서 문법·참조 오류를 검사하는 헤드리스 스크립트.
## GUT 전체를 돌리기 전에 "일단 파싱은 되나"를 빠르게 확인할 때 쓴다.
## 출처: donchitos/claude-code-game-studios `.claude/scripts/godot-parse-check.gd` (MIT).
##
## 사용법 — 반드시 프로젝트 "복사본"에서 (에디터와 .godot 캐시 충돌 방지, CLAUDE.md 참고).
## class_name 조회에 필요한 클래스 캐시를 만들려고 먼저 --import 를 한 번 돌린다:
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://.claude/scripts/godot_parse_check.gd -- res://Scripts/battle/battle_unit.gd res://Scripts/cards/card_data.gd
##
## 결과: 스크립트마다 `ok: <경로>` 또는 `PARSE FAIL: <경로>` (실패 위에 Godot 의 오류 줄이 찍힘).
## 종료 코드: 0 = 전부 성공, 1 = 하나라도 실패, 2 = 경로를 안 줌.
##
## --check-only 를 안 쓰는 이유: 오토로드가 등록되지 않은 상태로 컴파일해서,
## 오토로드 이름을 쓰는 정상 코드도 "Identifier not found" 로 실패한다.
## _initialize() 는 오토로드 등록 뒤에 불리므로 여기서 load 한다. (_init() 은 등록 전이라 똑같이 실패)


func _initialize() -> void:
	# `--` 뒤에 넘긴 res:// 경로들
	var paths := OS.get_cmdline_user_args()
	if paths.is_empty():
		printerr("godot_parse_check: 검사할 스크립트가 없습니다. `--` 뒤에 res:// 경로를 넘기세요.")
		quit(2)
		return
	var failed := 0
	for path in paths:
		# 불러오기 실패(null) 또는 파싱 오류로 인스턴스를 만들 수 없으면 실패로 센다
		var script := load(path) as Script
		if script == null or not script.can_instantiate():
			printerr("PARSE FAIL: ", path)
			failed += 1
		else:
			print("ok: ", path)
	quit(1 if failed > 0 else 0)
