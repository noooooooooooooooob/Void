extends GutTest
# 에디터 "연출 화면" 창: 시험 전투 무대 위에 편집 중인 연출 씬의 지금 상태를 실제 게임과 같은 배치·카메라로 그린다.

const VIEW := "res://addons/performance_stage_view/stage_view.tscn"
const FIST := "res://Scenes/performances/bram_stone_fist.tscn"
const BATTLE := "res://battles/test_battle.tres"
const PerfBuild := preload("res://tests/performances/test_card_performance.gd")
const EPS := Vector2(1, 1)

func _view() -> PerformanceStageView:
	var v: PerformanceStageView = load(VIEW).instantiate()
	add_child_autofree(v)
	v.set_battle(load(BATTLE))
	return v

func _fist() -> Node2D:
	var p: Node2D = load(FIST).instantiate()
	add_child_autofree(p)
	return p

# 창의 World 좌표로 본 노드 위치
func _in_world(v: PerformanceStageView, n: Node2D) -> Vector2:
	return v.world().get_global_transform().affine_inverse() * n.global_position

func _shown_units(v: PerformanceStageView) -> Array:
	return v.get_node("%Units").get_children().filter(func(c): return c.visible and c.get_node("Sprite").visible)

func _shown_cells(v: PerformanceStageView) -> Array:
	return v.get_node("%Background").find_children("*", "GridCell", true, false).filter(func(c): return c.is_visible_in_tree())

func test_shows_only_actor_and_enemy():
	# 연출 씬이 없으면 행위자 그림 + 적 하나만 (다른 아군은 숨김)
	var v := _view()
	var shown := _shown_units(v)
	assert_eq(shown.size(), 2)
	assert_true(v.ally_sprite(0).is_visible_in_tree())
	assert_true(v.enemy_sprite().is_visible_in_tree())

func test_other_allies_hidden_with_performance():
	var v := _view()
	v.set_source(_fist())
	v.sync()
	# 행위자 그림은 Actor 가 대신하므로 적 하나만 보인다
	assert_eq(_shown_units(v).size(), 1)

func test_only_actor_and_enemy_cells_visible():
	var v := _view()
	var data: BattleData = load(BATTLE)
	assert_eq(_shown_cells(v).size(), 2)
	if data.allies.size() > 1:
		var before := _shown_cells(v)
		v.set_actor(1)
		var after := _shown_cells(v)
		assert_eq(after.size(), 2)
		assert_ne(before, after)

func test_background_paths_lists_scenes():
	var paths := PerformanceStageView.background_paths("res://Scenes/backgrounds/")
	assert_has(paths, "res://Scenes/backgrounds/mountain_shrine.tscn")

func test_background_list_filled():
	var v := _view()
	var list: OptionButton = v.get_node("%BackgroundList")
	assert_eq(list.item_count, PerformanceStageView.background_paths("res://Scenes/backgrounds/").size())

func test_set_background_replaces_scene():
	var v := _view()
	var path := "res://Scenes/backgrounds/mountain_shrine.tscn"
	v.set_background(path)
	var bgs := v.get_node("%Background").get_children().filter(func(c): return not c.is_queued_for_deletion())
	assert_eq(bgs.size(), 1)
	assert_eq(bgs[0].scene_file_path, path)
	assert_eq(_shown_cells(v).size(), 2)
	assert_not_null(v.enemy_sprite())

func test_set_background_unknown_keeps_battle_background():
	var v := _view()
	v.set_background("res://Scenes/backgrounds/없는배경.tscn")
	var bgs := v.get_node("%Background").get_children().filter(func(c): return not c.is_queued_for_deletion())
	assert_eq(bgs.size(), 1)
	assert_eq(bgs[0].scene_file_path, (load(BATTLE) as BattleData).background.resource_path)

const BRAM := "res://entities/units/bram_welburn.tres"
const ENEMY_A := "res://entities/units/enemies/mountain_shrine/cracked_komainu.tres"  # 시험 전투의 첫 적 (2026-11-25)

func _bram_index() -> int:
	var data: BattleData = load(BATTLE)
	for i in data.allies.size():
		if data.allies[i].unit.resource_path == BRAM:
			return i
	return -1

func _box(sprite: Node2D) -> CanvasItem:
	return sprite.get_parent().get_node("Box")

func test_box_hidden_when_unit_has_sprite():
	# 그림이 있는 유닛은 그림만 (박스 숨김)
	var v := _view()
	v.set_actor(_bram_index())
	assert_true(v.ally_sprite(_bram_index()).is_visible_in_tree())
	assert_false(_box(v.ally_sprite(_bram_index())).is_visible_in_tree())

func test_box_shown_when_unit_has_no_sprite():
	# 그림이 없는 유닛(시험용 적 A)은 박스로 대신
	var v := _view()
	v.set_enemy("res://entities/units/test/test_enemy_a.tres")
	assert_true(_box(v.enemy_sprite()).is_visible_in_tree())

func test_actor_box_hidden_with_performance():
	# 연출 중에는 Actor 가 행위자를 대신하므로 행위자 자리에 빈 박스가 남지 않는다
	var data: BattleData = load(BATTLE).duplicate()
	var allies: Array[BattleSlot] = [data.allies[0]]  # 그림 없는 아군을 행위자로
	data.allies = allies
	var v: PerformanceStageView = load(VIEW).instantiate()
	add_child_autofree(v)
	v.set_battle(data)
	v.set_source(_fist())
	v.sync()
	assert_false(_box(v.ally_sprite(0)).is_visible_in_tree())

func test_enemy_paths_lists_units_only():
	var paths := PerformanceStageView.enemy_paths("res://entities/units/")
	assert_has(paths, ENEMY_A)
	assert_has(paths, "res://entities/units/hongyeon.tres")
	assert_does_not_have(paths, "res://entities/units/bram_frames.tres")

func test_enemy_list_filled_and_selects_battle_enemy():
	var v := _view()
	var list: OptionButton = v.get_node("%EnemyList")
	assert_eq(list.item_count, PerformanceStageView.enemy_paths().size())
	assert_eq(list.get_item_metadata(list.selected), ENEMY_A)

func test_set_enemy_replaces_target_on_same_cell():
	var v := _view()
	var before := _in_world(v, v.enemy_sprite())
	v.set_enemy(BRAM)
	assert_eq(v.enemy_sprite().sprite_frames, (load(BRAM) as UnitData).battle_frames)
	assert_almost_eq(_in_world(v, v.enemy_sprite()), before, EPS)
	assert_false(_box(v.enemy_sprite()).is_visible_in_tree())
	var list: OptionButton = v.get_node("%EnemyList")
	assert_eq(list.get_item_metadata(list.selected), BRAM)

func test_ally_unit_as_enemy_is_flipped():
	# 아군 캐릭터를 적 자리에 세우면 적 쪽을 보도록 좌우 반전
	var v := _view()
	v.set_enemy(BRAM)
	assert_true(v.enemy_sprite().flip_h)

func test_enemy_unit_not_flipped():
	var v := _view()
	assert_false(v.enemy_sprite().flip_h)
	v.set_enemy(ENEMY_A)
	assert_false(v.enemy_sprite().flip_h)

func test_is_enemy_unit_from_battles():
	assert_true(PerformanceStageView.is_enemy_unit(ENEMY_A, "res://battles/"))
	assert_false(PerformanceStageView.is_enemy_unit(BRAM, "res://battles/"))
	assert_false(PerformanceStageView.is_enemy_unit("res://entities/units/hongyeon.tres", "res://battles/"))

func test_set_enemy_unknown_keeps_battle_enemy():
	var v := _view()
	v.set_enemy("res://entities/units/없는유닛.tres")
	assert_eq(v.enemy_sprite().sprite_frames, (load(ENEMY_A) as UnitData).battle_frames)
	var list: OptionButton = v.get_node("%EnemyList")
	assert_eq(list.get_item_metadata(list.selected), ENEMY_A)

func _list_value(v: PerformanceStageView, list_name: String) -> Variant:
	var list: OptionButton = v.get_node(list_name)
	return list.get_item_metadata(list.selected)

func test_cell_lists_cover_grid_and_select_slot_cells():
	var v := _view()
	var data: BattleData = load(BATTLE)
	var a: OptionButton = v.get_node("%ActorCellList")
	var e: OptionButton = v.get_node("%EnemyCellList")
	assert_eq(a.item_count, data.ally_cols * data.rows)
	assert_eq(e.item_count, data.enemy_cols * data.rows)
	assert_eq(_list_value(v, "%ActorCellList"), data.allies[0].cell)
	assert_eq(_list_value(v, "%EnemyCellList"), data.enemies[0].cell)

func test_set_actor_cell_moves_actor():
	var v := _view()
	var before := _in_world(v, v.ally_sprite(0))
	var data: BattleData = load(BATTLE)
	var cell := Vector2i(0, 0) if data.allies[0].cell != Vector2i(0, 0) else Vector2i(1, 0)
	v.set_actor_cell(cell)
	assert_ne(_in_world(v, v.ally_sprite(0)), before)
	assert_eq(_list_value(v, "%ActorCellList"), cell)
	assert_eq(_shown_cells(v).size(), 2)

func test_set_enemy_cell_moves_enemy():
	var v := _view()
	var before := _in_world(v, v.enemy_sprite())
	var data: BattleData = load(BATTLE)
	var cell := Vector2i(0, 0) if data.enemies[0].cell != Vector2i(0, 0) else Vector2i(1, 0)
	v.set_enemy_cell(cell)
	assert_ne(_in_world(v, v.enemy_sprite()), before)
	assert_eq(_list_value(v, "%EnemyCellList"), cell)

func test_cell_outside_grid_ignored():
	var v := _view()
	var data: BattleData = load(BATTLE)
	v.set_enemy_cell(Vector2i(99, 99))
	assert_eq(_list_value(v, "%EnemyCellList"), data.enemies[0].cell)

func test_actor_cell_kept_when_actor_changes():
	var v := _view()
	v.set_actor_cell(Vector2i(0, 0))
	v.set_actor(_bram_index())
	assert_eq(_list_value(v, "%ActorCellList"), Vector2i(0, 0))

func test_default_actor_is_card_owner():
	var data: BattleData = load(BATTLE)
	var i := PerformanceStageView.default_actor(data, FIST, "res://cards/data/")
	assert_eq(data.allies[i].unit.display_name, "브람 웰번")

func test_actor_on_home_sits_on_actor_sprite():
	var v := _view()
	var src := _fist()
	src.get_node("Actor").position = src.get_node("Home").position  # 저장된 씬은 막대를 옮긴 자리일 수 있음
	v.set_source(src)
	v.set_actor(PerformanceStageView.default_actor(load(BATTLE), FIST, "res://cards/data/"))
	v.sync()
	var actor: Node2D = v.mirror().get_node("Actor")
	var i := PerformanceStageView.default_actor(load(BATTLE), FIST, "res://cards/data/")
	assert_almost_eq(_in_world(v, actor), _in_world(v, v.ally_sprite(i)), EPS)
	assert_false(v.ally_sprite(i).is_visible_in_tree())

func test_actor_on_target_sits_on_enemy():
	var v := _view()
	var src := _fist()
	src.get_node("Actor").position = src.get_node("Target").position
	v.set_source(src)
	v.sync()
	assert_almost_eq(_in_world(v, v.mirror().get_node("Actor")), _in_world(v, v.enemy_sprite()), EPS)

func test_target_preview_hidden_in_mirror():
	var v := _view()
	v.set_source(_fist())
	v.sync()
	assert_false(v.mirror().get_node("Target/Preview").visible)

func test_camera_zoom_moves_world():
	var v := _view()
	var src := _fist()
	src.get_node("Camera").zoom = Vector2(2, 2)  # 0초 값은 1
	v.set_source(src)
	v.sync()
	assert_almost_eq(v.world().scale, Vector2(2, 2), Vector2(0.01, 0.01))

func test_no_camera_world_identity():
	var v := _view()
	var p := PerfBuild.build([], 0.2)
	add_child_autofree(p)
	v.set_source(p)
	v.sync()
	assert_eq(v.world().scale, Vector2.ONE)
	assert_eq(v.world().position, Vector2.ZERO)

func test_non_performance_source_shows_hint():
	var v := _view()
	var n := Node2D.new()
	add_child_autofree(n)
	v.set_source(n)
	v.sync()
	assert_null(v.mirror())
	assert_true(v.get_node("%Hint").visible)

func test_rebuilds_mirror_when_source_changes():
	var v := _view()
	var src := _fist()
	v.set_source(src)
	v.sync()
	var fx := Sprite2D.new()
	fx.name = "Spark"
	src.add_child(fx)
	fx.owner = src
	v.sync()
	assert_not_null(v.mirror().get_node_or_null("Spark"))

func test_follows_source_state_each_sync():
	var v := _view()
	v.set_actor(_bram_index())  # 돌주먹의 주인 (punch 동작이 브람 그림 묶음에 있음)
	var src := _fist()
	v.set_source(src)
	v.sync()
	src.get_node("Actor").animation = &"punch"
	v.sync()
	assert_eq(v.mirror().get_node("Actor").animation, &"punch")

func test_camera_values_at_zero_reads_track():
	var src := _fist()
	var anim: Animation = src.get_node("AnimationPlayer").get_animation(&"perform")
	src.get_node("Camera").zoom = Vector2(3, 3)
	var vals := PerformanceStageView.camera_values_at(anim, src.get_node("Camera"), 0.0)
	assert_almost_eq(vals.zoom, Vector2.ONE, Vector2(0.001, 0.001))

func test_calls_before_ready_wait_for_ready():
	var v: PerformanceStageView = load(VIEW).instantiate()
	v.set_battle(load(BATTLE))
	v.set_source(_fist())
	add_child_autofree(v)
	await wait_process_frames(1)
	assert_not_null(v.mirror())
	assert_not_null(v.enemy_sprite())

func test_whole_game_screen_scaled_into_view():
	# 창 크기가 달라도 1920×1080 게임 화면 전체를 줄여서 보여 준다 (잘리지 않게)
	var v := _view()
	var vp: SubViewport = v.find_child("Viewport", true, false)
	assert_eq(vp.size_2d_override, Vector2i(1920, 1080))
	assert_true(vp.size_2d_override_stretch)

func test_units_show_side_colored_box_like_game():
	var v := _view()
	var ally_box: ColorRect = v.ally_sprite(0).get_parent().get_node("Box")
	var enemy_box: ColorRect = v.enemy_sprite().get_parent().get_node("Box")
	# 그림 묶음이 있는 유닛은 박스를 숨긴다 (홍연·브람 모두 그림 있음) — 색만 확인
	assert_eq(ally_box.color, Color("2f6f6a"))
	assert_eq(enemy_box.color, Color("7a2f3a"))

func test_mirror_root_visible_even_if_source_hidden():
	var v := _view()
	var src := _fist()
	src.visible = false
	v.set_source(src)
	v.sync()
	assert_true(v.mirror().visible)

func test_mirror_cameras_never_take_over_viewport():
	var v := _view()
	var src := _fist()
	src.get_node("Camera").enabled = true
	v.set_source(src)
	v.sync()
	assert_false(v.mirror().get_node("Camera").enabled)

func test_actor_frames_follow_selected_ally():
	var data: BattleData = load(BATTLE).duplicate()
	var slot := BattleSlot.new()
	slot.unit = UnitData.new()
	slot.unit.display_name = "그림있는아군"
	var frames := SpriteFrames.new()  # 실제 유닛 묶음처럼 연출에 나오는 동작을 갖춤
	for anim in [&"idle", &"punch"]:
		frames.add_animation(anim)
		frames.add_frame(anim, PlaceholderTexture2D.new())
	slot.unit.battle_frames = frames
	slot.cell = data.allies[0].cell
	var allies: Array[BattleSlot] = [slot]
	allies.append_array(data.allies.slice(1))
	data.allies = allies
	var v: PerformanceStageView = load(VIEW).instantiate()
	add_child_autofree(v)
	v.set_battle(data)
	v.set_source(_fist())
	v.set_actor(0)
	v.sync()
	assert_eq(v.mirror().get_node("Actor").sprite_frames, frames)

# --- 피격 반응 (2026-11-21, 설계 docs/superpowers/specs/2026-11-21-hit-reaction-preview-design.md) ---
# 돌주먹의 hit 키는 0.3초

const HIT := 0.3

# 연출 씬의 AnimationPlayer 를 t 초에 세워 두고 창을 그린다 (에디터에서 막대를 끈 것과 같게)
func _scrub(v: PerformanceStageView, src: Node, t: float) -> void:
	var ap: AnimationPlayer = src.get_node("AnimationPlayer")
	if ap.assigned_animation != &"perform":
		ap.play(&"perform")
		ap.pause()
	ap.seek(t, true)
	v.sync()

func _with_source() -> Array:
	var v := _view()
	var src := _fist()
	v.set_source(src)
	v.sync()
	return [v, src]

func test_no_reaction_before_hit():
	var vs := _with_source()
	_scrub(vs[0], vs[1], HIT - 0.05)
	assert_eq(vs[0].enemy_sprite().modulate, Color.WHITE)
	assert_eq(vs[0].enemy_sprite().offset, SpritePivot.foot_offset(vs[0].enemy_sprite().sprite_frames))

func test_flash_right_after_hit_then_back():
	var vs := _with_source()
	_scrub(vs[0], vs[1], HIT + 0.01)
	assert_gt(vs[0].enemy_sprite().modulate.r, 1.0)
	_scrub(vs[0], vs[1], HIT + 0.3)
	assert_eq(vs[0].enemy_sprite().modulate, Color.WHITE)

func test_knockback_pushes_away_then_returns():
	var vs := _with_source()
	_scrub(vs[0], vs[1], HIT + 0.01)
	assert_gt(vs[0].enemy_sprite().offset.x, 0.0)  # 적은 오른쪽 — 공격자 반대쪽으로 밀림
	_scrub(vs[0], vs[1], 0.69)
	assert_eq(vs[0].enemy_sprite().offset, SpritePivot.foot_offset(vs[0].enemy_sprite().sprite_frames))

func test_card_override_flash_time_in_view():
	# 연출 씬 루트의 카드별 값이 창에도 들어간다 (번쩍임을 길게)
	var v := _view()
	var src := _fist()
	src.flash_time = 1.0
	v.set_source(src)
	_scrub(v, src, HIT + 0.3)
	assert_gt(v.enemy_sprite().modulate.r, 1.0)

func test_scrub_is_repeatable():
	# 막대를 같은 곳에 두면 흔들림까지 같은 모양
	var vs := _with_source()
	_scrub(vs[0], vs[1], HIT + 0.05)
	var a: Vector2 = vs[0].enemy_sprite().position
	_scrub(vs[0], vs[1], 0.1)
	_scrub(vs[0], vs[1], HIT + 0.05)
	assert_eq(vs[0].enemy_sprite().position, a)

func test_enemy_hit_animation_shown_after_hit():
	var data: BattleData = load(BATTLE).duplicate()
	var foe := BattleSlot.new()
	foe.unit = UnitData.new()
	foe.cell = data.enemies[0].cell
	var frames := SpriteFrames.new()
	for anim in [&"idle", &"hit"]:
		if not frames.has_animation(anim):
			frames.add_animation(anim)
		frames.add_frame(anim, PlaceholderTexture2D.new())
		frames.add_frame(anim, PlaceholderTexture2D.new())
	frames.set_animation_speed(&"hit", 10.0)
	frames.set_animation_loop(&"hit", false)
	foe.unit.battle_frames = frames
	var enemies: Array[BattleSlot] = [foe]
	data.enemies = enemies
	var v: PerformanceStageView = load(VIEW).instantiate()
	add_child_autofree(v)
	v.set_battle(data)
	var src := _fist()
	v.set_source(src)
	_scrub(v, src, HIT + 0.15)  # 10fps 두 장 → 두 번째 장
	assert_eq(v.enemy_sprite().animation, &"hit")
	assert_eq(v.enemy_sprite().frame, 1)
	_scrub(v, src, HIT - 0.1)
	assert_eq(v.enemy_sprite().animation, &"idle")

func test_playing_through_hit_slows_source_then_release():
	var vs := _with_source()
	var ap: AnimationPlayer = vs[1].get_node("AnimationPlayer")
	ap.play(&"perform")
	ap.seek(HIT - 0.02, true)
	vs[0].sync()
	ap.seek(HIT + 0.01, true)
	vs[0].sync()
	assert_lt(ap.speed_scale, 1.0)
	vs[0].release_slowmo()
	assert_eq(ap.speed_scale, 1.0)

func test_slowmo_ends_by_itself():
	var vs := _with_source()
	# 슬로우모션 시간을 테스트가 정한다 — 돌주먹 씬의 카드별 값(지금 0.5초)은 연출 조정으로 바뀌므로 기대지 않는다
	vs[1].hitstop_time = 0.1
	var ap: AnimationPlayer = vs[1].get_node("AnimationPlayer")
	ap.play(&"perform")
	ap.seek(HIT - 0.02, true)
	vs[0].sync()
	ap.seek(HIT + 0.01, true)
	vs[0].sync()
	await wait_seconds(0.3)
	vs[0].sync()
	assert_eq(ap.speed_scale, 1.0)

func test_scrubbing_through_hit_does_not_slow():
	# 막대 끌기(재생 아님)는 슬로우모션·소리 없이 모양만
	var vs := _with_source()
	_scrub(vs[0], vs[1], HIT - 0.02)
	_scrub(vs[0], vs[1], HIT + 0.01)
	assert_eq((vs[1].get_node("AnimationPlayer") as AnimationPlayer).speed_scale, 1.0)

func test_playing_through_hit_shakes_screen_and_sets_sound():
	var vs := _with_source()
	var snd := AudioStreamWAV.new()
	vs[1].hit_sound = snd
	var ap: AnimationPlayer = vs[1].get_node("AnimationPlayer")
	ap.play(&"perform")
	ap.seek(HIT - 0.02, true)
	vs[0].sync()
	ap.seek(HIT + 0.01, true)
	vs[0].sync()
	assert_true(vs[0].is_screen_shaking())
	assert_eq((vs[0].get_node("%HitSound") as AudioStreamPlayer).stream, snd)
	vs[0].release_slowmo()

# --- 치명타 강조 미리보기 (2026-11-21): 위 줄 "치명타" 체크 → ▶ 중 show_results 키를 지날 때 치명타 강조 ---

# hit 0.1초, 결과 0.3초 — 결과 키만 지나가게 해서 hit 반응과 섞이지 않게
func _crit_source(v: PerformanceStageView) -> Node:
	var p := PerfBuild.build([[0.1, "hit", []], [0.3, "show_results", []]], 0.6)
	add_child_autofree(p)
	v.set_source(p)
	return p

func _play_across(v: PerformanceStageView, src: Node, from: float, to: float) -> AnimationPlayer:
	var ap: AnimationPlayer = src.get_node("AnimationPlayer")
	ap.play(&"perform")
	ap.seek(from, true)
	v.sync()
	ap.seek(to, true)
	v.sync()
	return ap

func test_crit_check_off_no_emphasis_at_results():
	var v := _view()
	var src := _crit_source(v)
	var ap := _play_across(v, src, 0.25, 0.31)
	assert_eq(ap.speed_scale, 1.0)
	assert_false(v.is_screen_shaking())

func test_crit_check_on_emphasis_at_results():
	var v := _view()
	var src := _crit_source(v)
	(v.get_node("%CritCheck") as CheckBox).button_pressed = true
	var ap := _play_across(v, src, 0.25, 0.31)
	assert_lt(ap.speed_scale, 1.0)
	assert_true(v.is_screen_shaking())
	v.release_slowmo()

# 2026-11-25: 인스펙터에서 바꾼 스머지 값이 연출 화면 복제본에도 바로 들어간다 (씬을 다시 열지 않아도)
func test_smear_values_follow_source():
	var vs := _with_source()
	var src_smear: SmearDriver = vs[1].get_node("Actor/Smear")
	src_smear.length_ratio = 1.5
	src_smear.max_length = 900.0
	src_smear.decay_time = 0.4
	src_smear.min_move = 5.0
	vs[0].sync()
	var m: SmearDriver = vs[0].mirror().get_node("Actor/Smear")
	assert_eq([m.length_ratio, m.max_length, m.decay_time, m.min_move], [1.5, 900.0, 0.4, 5.0])
