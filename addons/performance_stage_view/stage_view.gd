@tool
class_name PerformanceStageView
extends Control
## 에디터 하단 "연출 화면" 창 (addons/performance_stage_view). 연출 씬을 열고 애니메이션 막대를 끌면,
## 그 프레임을 실제 전투 화면처럼(배경·격자판·행위자·적 하나·실제 칸 거리로 늘린 위치·카메라 구도) 보여 준다.
## (설계 docs/superpowers/specs/2026-11-19-performance-stage-view-design.md,
##  배경 고르기·칸 하나씩 docs/superpowers/specs/2026-11-21-stage-view-background-pick-design.md)
##
## 연출에 관계있는 것만 보인다: 아군은 행위자 하나, 적은 하나(목록에서 고름, 기본 = 시험 전투의 첫 적), 격자 칸도 그 둘이 선 칸 하나씩.
## 유닛은 그림만 보이고, 그림 묶음이 없는 유닛만 편 색 박스로 대신한다 (2026-11-21).
##
## 편집 중인 연출 씬을 복제해(mirror) SubViewport 의 무대에 올리고, sync() 마다 원본의 지금 상태(애니메이션이 넣은 값)를
## 복제본에 옮긴 뒤 실제 게임과 같은 식(PerformanceSpace·CameraMath)으로 배치한다.
## 피격 반응 (2026-11-21, 설계 docs/superpowers/specs/2026-11-21-hit-reaction-preview-design.md):
## - 막대 끌기·▶ 둘 다: 직전 hit 키에서 지난 시간으로 적의 번쩍임·넉백·흔들림·hit 애니메이션을 계산해 그린다 (같은 시각 = 같은 모양)
## - ▶ 재생 중 hit 키를 지나는 순간: 효과음, 화면 흔들림, 슬로우모션(연출 씬 AnimationPlayer 속도를 잠깐 바꿨다 되돌림)
## - 위 줄 "치명타" 체크: ▶ 재생 중 show_results 키를 지나는 순간 게임의 치명타 강조(화면 흔들림 × crit_shake_boost,
##   슬로우모션 시간 × crit_hitstop_boost)도 보여 준다 (2026-11-21)
## 숫자·UI·자동 피격 이펙트는 없다 (이펙트는 연출 씬 안에 직접 짠다. 숫자는 F6 연출 미리보기 씬에서 본다).

## 배경 목록에서 배경을 골랐다 (path = 배경 씬 경로). 플러그인이 받아 기억해 둔다
signal background_selected(path: String)

## 적 목록에서 적(대상) 유닛을 골랐다 (path = 유닛 .tres 경로). 플러그인이 받아 기억해 둔다
signal enemy_selected(path: String)

## 내 칸 / 적 칸 목록에서 칸을 골랐다 (cell = 그 편 격자 칸 좌표). 플러그인이 받아 기억해 둔다
signal actor_cell_selected(cell: Vector2i)
signal enemy_cell_selected(cell: Vector2i)

## 칸을 고르지 않음 (전투 데이터의 자리를 씀)
const NO_CELL := Vector2i(-1, -1)

## 배경 목록을 채울 폴더 (안의 .tscn 이 배경 씬)
const BACKGROUNDS_DIR := "res://Scenes/backgrounds/"
## 적 목록을 채울 폴더 (하위 폴더 포함, 안의 UnitData .tres 전부 — 그림 있는 아군 유닛도 대상으로 세워 볼 수 있게)
const UNITS_DIR := "res://entities/units/"
## 적/아군 가르기에 쓰는 전투 데이터 폴더 (여기 전투들의 enemies 에 나온 유닛 = 적)
const BATTLES_DIR := "res://battles/"

## 피격 반응 공통값을 읽어 올 전투 화면 씬
const BATTLE_SCREEN := "res://Scenes/ui/battle_screen/battle_screen.tscn"
## 전투 화면(BattleScreen)에서 읽는 피격 반응 값 이름
const REACTION_KEYS := [&"hit_shake", &"hit_unit_shake", &"shake_time", &"flash_color", &"flash_time",
	&"knockback", &"knockback_return", &"hitstop_time", &"hitstop_speed", &"hit_sound", &"pitch_jitter",
	&"crit_shake_boost", &"crit_hitstop_boost"]
## 연출 씬 루트(CardPerformance)에 카드별 값이 있으면 공통값 대신 쓰는 값
## (수치는 0 미만 = 공통값, 소리는 비면 공통값, 색은 알파 0 = 공통값 — 2026-11-21 부터 피격 반응 값 전부 카드별 가능.
##  치명타 배율은 공통값만)
const OVERRIDE_KEYS := [&"hit_shake", &"hit_unit_shake", &"shake_time", &"flash_color", &"flash_time",
	&"knockback", &"knockback_return", &"hitstop_time", &"hitstop_speed", &"hit_sound", &"pitch_jitter"]

## 원본 → 복제본으로 옮길 속성 (노드 종류 상관없이 있는 것만)
const COPY_PROPS := [&"position", &"rotation", &"scale", &"visible", &"modulate", &"self_modulate", &"z_index",
	&"sprite_frames", &"animation", &"frame", &"flip_h", &"flip_v", &"offset", &"texture", &"zoom"]

@onready var _background_list: OptionButton = %BackgroundList
@onready var _enemy_list: OptionButton = %EnemyList
@onready var _actor_cell_list: OptionButton = %ActorCellList
@onready var _enemy_cell_list: OptionButton = %EnemyCellList
@onready var _hint: Label = %Hint
@onready var _world: Control = %World
@onready var _background: Control = %Background
@onready var _units: Control = %Units
@onready var _template: Node2D = %UnitTemplate  # 유닛 하나의 틀: 편 색 박스(Box) + 그림(Sprite), 유닛 박스와 같은 크기·배율

## 편 색 (unit_token.gd 의 기본값과 같게)
const ALLY_COLOR := Color("2f6f6a")
const ENEMY_COLOR := Color("7a2f3a")
@onready var _perf_layer: Node2D = %PerfLayer

var _ally_sprites: Array[Node2D] = []  # 아군 그림(틀의 Sprite) (시험 전투 아군 순서)
var _ally_frames: Array[SpriteFrames] = []  # 아군 그림 묶음 (없으면 null)
var _enemy_sprite: Node2D              # 적 하나(대상)의 그림
var _ally_cells: Array[GridCell] = []  # 아군마다 선 칸 (판이 없는 배경이면 null)
var _enemy_cell: GridCell              # 적 하나가 선 칸
var _battle: BattleData                # 무대 전투 (칸 크기·자리·유닛). 배경만 _background_path 로 바꿔 쓴다
var _background_path := ""             # 고른 배경 씬 경로 (빈 값 = 전투 데이터의 배경)
var _enemy_path := ""                  # 고른 적 유닛 경로 (빈 값 = 전투 데이터의 첫 적)
var _actor_cell_pick := NO_CELL        # 고른 행위자 칸 (NO_CELL = 행위자의 전투 데이터 칸). 행위자가 바뀌어도 유지
var _enemy_cell_pick := NO_CELL        # 고른 적 칸 (NO_CELL = 첫 적의 칸)
var _actor := 0                        # 행위자 아군 번호
var _source: Node                      # 편집 중인 연출 씬 루트
var _mirror: Node2D                    # 무대에 올린 복제본
var _shape := PackedStringArray()      # 원본 노드 경로 목록 (바뀌면 다시 복제)
var _defaults := {}                    # 피격 반응 공통값 (연출 씬이 바뀔 때 다시 읽음)
var _last_time := -1.0                 # 지난 sync 때 타임라인 시각 (▶ 중 hit 키를 지났는지 보려고)
var _slow_player: AnimationPlayer      # 슬로우모션을 건 연출 씬 AnimationPlayer (없으면 null)
var _slow_prev := 1.0                  # 걸기 전 배속
var _slow_until := 0                   # 슬로우모션이 끝나는 시각 (Time.get_ticks_msec)
var _shake_until := 0                  # 화면 흔들림이 끝나는 시각 (msec)
var _shake_strength := 0.0             # 화면 흔들림 세기 (픽셀)
var _shake_ms := 1                     # 화면 흔들림 길이 (msec)
@onready var _hit_sound: AudioStreamPlayer = %HitSound
@onready var _crit_check: CheckBox = %CritCheck  # 켜면 결과 키 때 치명타 강조


func _ready() -> void:
	_background_list.item_selected.connect(_on_background_item)
	_enemy_list.item_selected.connect(_on_enemy_item)
	_actor_cell_list.item_selected.connect(_on_actor_cell_item)
	_enemy_cell_list.item_selected.connect(_on_enemy_cell_item)
	_fill_background_list()
	_fill_enemy_list()


## 배경 폴더 dir 바로 안의 배경 씬(.tscn) 경로들, 이름 순 (내보낸 게임의 .remap 은 뗌)
static func background_paths(dir: String = BACKGROUNDS_DIR) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		var file := f.trim_suffix(".remap")
		if file.get_extension() == "tscn":
			out.append(dir.path_join(file))
	out.sort()
	return out


## 배경을 바꿔 무대를 다시 깐다. 칸 크기·자리·유닛은 그대로 무대 전투 것.
## path 가 없는 파일이거나 빈 값이면 전투 데이터의 배경을 쓴다
func set_background(path: String) -> void:
	if not is_node_ready():
		await ready
	_background_path = path if not path.is_empty() and ResourceLoader.exists(path) else ""
	_select_background_item()
	if _battle:
		set_battle(_battle)


## 유닛 폴더 dir 아래(하위 폴더 포함)의 UnitData .tres 경로들, 경로 순 (그림 묶음 등 다른 리소스는 뺌)
static func enemy_paths(dir: String = UNITS_DIR) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for p in ResDir.tres_paths(dir):
		if load(p) is UnitData:
			out.append(p)
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(enemy_paths(dir.path_join(sub)))
	out.sort()
	return out


## path 유닛이 dir 의 전투 데이터 중 하나라도 enemies 에 나오면 적 유닛 (유닛 데이터에 편 표시가 없어서 — 2026-11-21 내 판단)
static func is_enemy_unit(path: String, dir: String = BATTLES_DIR) -> bool:
	for p in ResDir.tres_paths(dir):
		var b := load(p) as BattleData
		if b and b.enemies.any(func(s: BattleSlot): return s and s.unit and s.unit.resource_path == path):
			return true
	return false


## 적(대상) 유닛을 바꿔 무대를 다시 깐다. 서는 칸은 무대 전투의 첫 적 칸 그대로.
## path 가 UnitData 가 아니거나 빈 값이면 전투 데이터의 첫 적을 쓴다
func set_enemy(path: String) -> void:
	if not is_node_ready():
		await ready
	_enemy_path = path if not path.is_empty() and ResourceLoader.exists(path) and load(path) is UnitData else ""
	_select_enemy_item()
	if _battle:
		set_battle(_battle)


## 행위자가 설 칸을 고른다 (격자 밖이면 무시). 무대를 다시 깐다
func set_actor_cell(cell: Vector2i) -> void:
	if not is_node_ready():
		await ready
	if _battle and not _in_grid(cell, _battle.ally_cols, _battle.rows):
		return
	_actor_cell_pick = cell
	if _battle:
		set_battle(_battle)


## 적이 설 칸을 고른다 (격자 밖이면 무시). 무대를 다시 깐다
func set_enemy_cell(cell: Vector2i) -> void:
	if not is_node_ready():
		await ready
	if _battle and not _in_grid(cell, _battle.enemy_cols, _battle.rows):
		return
	_enemy_cell_pick = cell
	if _battle:
		set_battle(_battle)


## 무대를 깐다: 배경 씬, 격자판 칸, 아군 전원과 첫 적 하나의 그림 (사용자 결정: 적은 하나만)
func set_battle(data: BattleData) -> void:
	# 창이 트리에 들어가기 전에 불리면 노드가 준비될 때까지 기다린다
	if not is_node_ready():
		await ready
	# 1. 지난 무대 지우기 (트리에서 바로 빼서 프레임 끝까지 겹쳐 보이지 않게)
	for c in _background.get_children():
		_background.remove_child(c)
		c.queue_free()
	for c in _units.get_children():
		if c != _template:
			_units.remove_child(c)
			c.queue_free()
	_ally_sprites.clear()
	_ally_frames.clear()
	_ally_cells.clear()
	_enemy_sprite = null
	_enemy_cell = null
	_battle = data
	_select_background_item()
	_select_enemy_item()
	if data == null:
		return
	# 2. 배경 씬과 격자판 (판이 없는 배경이면 그림을 판 대신 대략 자리에). 고른 배경이 있으면 그것
	var boards := {}
	var bg_scene: PackedScene = load(_background_path) if not _background_path.is_empty() else data.background
	if bg_scene:
		var bg := bg_scene.instantiate()
		_background.add_child(bg)
		for b in _find_boards(bg):
			boards[b.side] = b
	# 3. 유닛 그림: 칸 중심 = 실제 유닛 박스 그림 자리. 선 칸도 기억 (보일 칸 고르기용)
	#    행위자는 고른 칸이 있으면 거기에 (전투 데이터는 건드리지 않게 복제)
	_actor = clampi(_actor, 0, maxi(data.allies.size() - 1, 0))
	for i in data.allies.size():
		var s: BattleSlot = data.allies[i]
		if i == _actor and _in_grid(_actor_cell_pick, data.ally_cols, data.rows):
			s = s.duplicate()
			s.cell = _actor_cell_pick
		_ally_sprites.append(_add_unit(s, BattleTypes.Side.ALLY, data, boards))
		_ally_frames.append(s.unit.battle_frames if s.unit else null)
		_ally_cells.append(_cell_of(BattleTypes.Side.ALLY, s.cell, data, boards))
	if not data.enemies.is_empty():
		# 고른 적이 있으면 첫 적 칸에 그 유닛을 세운다 (전투 데이터는 건드리지 않게 복제)
		var slot: BattleSlot = data.enemies[0]
		if not _enemy_path.is_empty():
			slot = slot.duplicate()
			slot.unit = load(_enemy_path)
		if _in_grid(_enemy_cell_pick, data.enemy_cols, data.rows):
			slot = slot.duplicate()
			slot.cell = _enemy_cell_pick
		_enemy_sprite = _add_unit(slot, BattleTypes.Side.ENEMY, data, boards)
		# 아군 캐릭터를 적 자리에 세우면 아군 쪽(왼쪽)을 보도록 좌우 반전 (아군 그림은 오른쪽을 봄)
		_enemy_sprite.flip_h = not _enemy_path.is_empty() and not is_enemy_unit(_enemy_path)
		_enemy_cell = _cell_of(BattleTypes.Side.ENEMY, slot.cell, data, boards)
	_fill_cell_lists(data)
	_update_visible()


## 편집 중인 연출 씬 루트를 받는다. 연출 씬이 아니면 비우고 안내를 띄운다
func set_source(perf: Node) -> void:
	if not is_node_ready():
		await ready
	release_slowmo()
	_source = perf if _is_performance(perf) else null
	_defaults = {}
	_last_time = -1.0
	_rebuild_mirror()


## 행위자 아군 번호를 정한다 (플러그인이 연출 카드의 주인으로 자동 지정 — 고르는 목록은 없음, 2026-11-21)
func set_actor(index: int) -> void:
	var changed := index != _actor
	_actor = index
	# 고른 칸은 행위자에게 붙으므로 행위자가 바뀌면 다시 깐다
	if changed and _actor_cell_pick != NO_CELL and _battle and is_node_ready():
		set_battle(_battle)
		return
	_update_visible()
	_select_cell_items()


## 지금 상태를 옮겨 그린다 (에디터 프레임마다 플러그인이 부른다)
func sync() -> void:
	# 슬로우모션 시간이 지났으면 먼저 풀어 둔다
	if _slow_player and Time.get_ticks_msec() >= _slow_until:
		release_slowmo()
	if _source == null or not is_instance_valid(_source):
		_set_world(Transform2D.IDENTITY)
		return
	if _paths(_source) != _shape:
		_rebuild_mirror()
	# 1. 원본의 지금 상태 → 복제본
	for path in _shape:
		var from := _source.get_node_or_null(path)
		var to := _mirror.get_node_or_null(path)
		if from and to:
			for p in COPY_PROPS:
				if p in from and p in to:
					# 동작 이름은 복제본에 들어 있는 그림 묶음에 그 이름이 있을 때만 옮긴다 (없는 이름·빈 묶음이면 엔진 에러).
					# 행위자에게 유닛 그림 묶음을 씌울 때는 아래에서 있는 이름만 다시 맞춘다
					if p == &"animation" and to is AnimatedSprite2D 							and (to.sprite_frames == null or not to.sprite_frames.has_animation(from.get(p))):
						continue
					to.set(p, from.get(p))
	# 행위자의 그림 묶음으로 (실제 게임은 play(행위자 battle_frames)). 묶음이 없는 아군이면 씬의 것 그대로.
	# 원본에서 동작 이름·프레임 번호를 옮겨 받은 뒤 묶음만 바꾼다
	var frames: SpriteFrames = _ally_frames[_actor] if _actor < _ally_frames.size() else null
	var m_actor := _mirror.get_node_or_null(^"Actor")
	if frames and m_actor is AnimatedSprite2D:
		var anim_name: StringName = m_actor.animation
		var fr: int = m_actor.frame
		m_actor.sprite_frames = frames
		if frames.has_animation(anim_name):
			m_actor.animation = anim_name
			m_actor.frame = fr
	# 2. 행위자 그림 자리에 Home, 같은 크기로 (실제 게임 PerformanceQueue 와 같은 식)
	_update_visible()
	var sprite := _ally_sprites[_actor] if _actor < _ally_sprites.size() else null
	var actor := _mirror.get_node_or_null(^"Actor") as Node2D
	var home := _local_pos(_mirror, ^"Home", Vector2.ZERO)
	var target := _local_pos(_mirror, ^"Target", home)
	_mirror.visible = true
	if sprite:
		var sx := _in_world(sprite)
		var s := PerformanceSpace.root_scale(sx.get_scale(), actor.scale if actor else Vector2.ONE)
		_mirror.scale = s
		_mirror.position = PerformanceSpace.root_position(sx.origin, home, s)
	# 3. Target → 적 그림 자리로 늘리기 (복제본의 직계 Node2D, Home·Target 제외)
	var real_target := target
	if _enemy_sprite:
		# 유닛(틀) 자리 기준 — 그림 자신은 피격 흔들림으로 움직이므로
		real_target = _mirror.transform.affine_inverse() * _in_world(_enemy_sprite.get_parent() as Node2D).origin
	for c in _mirror.get_children():
		if c is Node2D and c.name != &"Home" and c.name != &"Target":
			c.position = PerformanceSpace.map_point(c.position, home, target, home, real_target)
	# 4. Target 미리보기 그림은 에디터용
	var t_node := _mirror.get_node_or_null(^"Target")
	if t_node:
		for c in t_node.get_children():
			if c is CanvasItem:
				c.visible = false
	# 5. 피격 반응: 지금 시각의 적 모양, ▶ 중이면 hit 키를 지나는 순간의 실시간 반응
	var now_t := _source_time()
	if now_t >= 0.0:
		_draw_hit_reaction(now_t, sprite)
		_play_hit_events(now_t)
	# 6. 카메라: perform 0초 자세 대비 지금 자세 (둘 다 같은 식으로 늘린 위치)
	var cam := _mirror.get_node_or_null(^"Camera") as Node2D
	var src_cam := _source.get_node_or_null(^"Camera") as Node2D
	var anim := _perform(_source)
	if cam == null or src_cam == null:
		_set_world(Transform2D.IDENTITY)
		return
	var v0 := camera_values_at(anim, src_cam, 0.0) if anim else {"position": src_cam.position, "rotation": src_cam.rotation, "zoom": _zoom_of(src_cam)}
	var p0 := PerformanceSpace.map_point(v0.position, home, target, home, real_target)
	var cam0 := CameraMath.camera_xform(p0, v0.rotation, v0.zoom)
	var now := CameraMath.camera_xform(cam.position, cam.rotation, _zoom_of(cam))
	_set_world(CameraMath.world_xform(_mirror.transform, cam0, now))


## 이 연출을 쓰는 카드를 덱에 가진 아군 번호 (없으면 0)
static func default_actor(data: BattleData, perf_path: String, cards_dir: String) -> int:
	var ids := {}
	for c in _cards_in(cards_dir):
		if c.performance and c.performance.resource_path == perf_path:
			ids[c.id] = true
	for i in data.allies.size():
		var u: UnitData = data.allies[i].unit
		if u and u.deck.any(func(d: CardData): return d and ids.has(d.id)):
			return i
	return 0


## 애니메이션 anim 의 time 초에서 Camera 의 위치·회전·줌. 트랙이 없는 값은 cam 노드의 지금 값
## (트랙 경로: Camera:position / :position:x / :position:y / :zoom / :zoom:x / :zoom:y / :rotation, 값·Bezier 트랙)
static func camera_values_at(anim: Animation, cam: Node2D, time: float) -> Dictionary:
	var pos := cam.position
	var rot := cam.rotation
	var zoom := _zoom_of(cam)
	for t in anim.get_track_count():
		var path := String(anim.track_get_path(t))
		if not path.begins_with("Camera:"):
			continue
		var v: Variant
		match anim.track_get_type(t):
			Animation.TYPE_BEZIER:
				v = anim.bezier_track_interpolate(t, time)
			Animation.TYPE_VALUE:
				v = anim.value_track_interpolate(t, time)
			_:
				continue
		match path.trim_prefix("Camera:"):
			"position": pos = v
			"position:x": pos.x = v
			"position:y": pos.y = v
			"zoom": zoom = v
			"zoom:x": zoom.x = v
			"zoom:y": zoom.y = v
			"rotation": rot = v
	return {"position": pos, "rotation": rot, "zoom": zoom}


## 슬로우모션을 걸어 둔 연출 씬 AnimationPlayer 의 배속을 원래대로 되돌린다.
## 느려진 값이 씬에 저장되지 않게 플러그인이 저장 직전·창이 숨을 때도 부른다
func release_slowmo() -> void:
	if _slow_player and is_instance_valid(_slow_player):
		_slow_player.speed_scale = _slow_prev
	_slow_player = null


## 화면 흔들림이 진행 중인지 (테스트용)
func is_screen_shaking() -> bool:
	return Time.get_ticks_msec() < _shake_until


## 애니메이션 anim 의 hit Call Method 키 시각들, 빠른 순
static func hit_times(anim: Animation) -> PackedFloat32Array:
	return method_times(anim, &"hit")


## 애니메이션 anim 에서 method 를 부르는 Call Method 키 시각들, 빠른 순
static func method_times(anim: Animation, method: StringName) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if anim == null:
		return out
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_METHOD:
			continue
		for k in anim.track_get_key_count(t):
			if anim.method_track_get_name(t, k) == method:
				out.append(anim.track_get_key_time(t, k))
	out.sort()
	return out


# --- 읽기용 (테스트·플러그인) ---

## 아군 i 번 그림
func ally_sprite(i: int) -> Node2D:
	return _ally_sprites[i]


## 적 하나(대상)의 그림
func enemy_sprite() -> Node2D:
	return _enemy_sprite


## 무대에 올린 연출 복제본 (연출 씬이 아니면 null)
func mirror() -> Node2D:
	return _mirror


## 카메라가 움직이는 월드 묶음
func world() -> Control:
	return _world


# --- 내부 ---

## 편집 중인 연출 씬의 perform 타임라인 지금 시각 (perform 을 고른 적이 없으면 -1)
func _source_time() -> float:
	var ap := _source.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if ap == null or ap.assigned_animation != &"perform":
		return -1.0
	return ap.current_animation_position


## 피격 반응 값: 연출 씬 루트의 카드별 값이 있으면 그것, 아니면 전투 화면 공통값
func _reaction(key: StringName) -> Variant:
	if _defaults.is_empty():
		var bs: Node = load(BATTLE_SCREEN).instantiate()
		for k in REACTION_KEYS:
			_defaults[k] = bs.get(k)
		bs.free()
	var d: Variant = _defaults.get(key)
	if _source and key in OVERRIDE_KEYS:
		var o: Variant = _source.get(key)
		if o is AudioStream or (o is float and o >= 0.0) or (o is Color and o.a > 0.0):
			return o
	return d


## 지금 시각 t 의 적 그림 모양 (게임 BattleScreen._on_hit 의 번쩍임·넉백·흔들림 + UnitToken.play_hit 을 시간의 함수로).
## hit 키가 여러 개면 직전 것 하나만 본다. actor_sprite = 행위자 그림 (넉백 방향 = 행위자 반대쪽)
func _draw_hit_reaction(t: float, actor_sprite: Node2D) -> void:
	var sp := _enemy_sprite as AnimatedSprite2D
	if sp == null:
		return
	var base_offset: Vector2 = (_template.get_node(^"Sprite") as AnimatedSprite2D).offset
	# 1. 반응 없는 모양으로
	sp.modulate = Color.WHITE
	sp.offset = base_offset
	sp.position = Vector2.ZERO
	var frames := sp.sprite_frames
	if frames and frames.has_animation(&"idle") and sp.animation != &"idle":
		sp.animation = &"idle"
	# 2. 직전 hit 키
	var hits := hit_times(_perform(_source))
	var idx := -1
	for i in hits.size():
		if hits[i] <= t:
			idx = i
	if idx < 0:
		return
	var dt := t - hits[idx]
	# 3. 번쩍임: flash_color → 흰색 (flash_time 초)
	var flash_time: float = _reaction(&"flash_time")
	if dt < flash_time:
		sp.modulate = (_reaction(&"flash_color") as Color).lerp(Color.WHITE, dt / flash_time)
	# 4. 넉백: 행위자 반대쪽으로 밀렸다가 knockback_return 초 동안 EASE_OUT QUAD 로 제자리 (게임과 같은 곡선)
	var push: float = _reaction(&"knockback")
	var back: float = _reaction(&"knockback_return")
	if push > 0.0 and back > 0.0 and dt < back and actor_sprite:
		var dir := signf(_in_world(sp.get_parent() as Node2D).origin.x - _in_world(actor_sprite.get_parent() as Node2D).origin.x)
		var sx := absf(_in_world(sp).get_scale().x)
		var left := pow(1.0 - dt / back, 2.0)
		sp.offset = base_offset + Vector2(dir * push * left / (sx if sx != 0.0 else 1.0), 0)
	# 5. 흔들림: 세기 × 남은 비율 안에서 무작위 (같은 시각이면 같은 모양이 되게 hit 번호·프레임으로 씨앗)
	var shake: float = _reaction(&"hit_unit_shake")
	var shake_time: float = _reaction(&"shake_time")
	if shake > 0.0 and dt < shake_time:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(idx, int(dt * 60.0)))
		var amount := shake * (1.0 - dt / shake_time)
		sp.position = Vector2(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount))
	# 6. hit 애니메이션: 있으면 지난 시간에 맞는 프레임, 다 끝났으면 idle
	if frames and frames.has_animation(&"hit"):
		var fps := frames.get_animation_speed(&"hit")
		var acc := 0.0
		for f in frames.get_frame_count(&"hit"):
			acc += frames.get_frame_duration(&"hit", f) / (fps if fps > 0.0 else 1.0)
			if dt < acc:
				sp.animation = &"hit"
				sp.frame = f
				break


## ▶ 재생 중 막대가 hit 키 / (치명타 체크 시) show_results 키를 지나는 순간의 실시간 반응 (막대 끌기·뒤로 감기에는 안 함)
func _play_hit_events(t: float) -> void:
	var ap := _source.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	var playing := ap != null and ap.is_playing() and _last_time >= 0.0 and t >= _last_time
	var from := _last_time
	_last_time = t
	if not playing:
		return
	var anim := _perform(_source)
	if _crossed(method_times(anim, &"hit"), from, t):
		_on_play_hit(ap)
	if _crit_check.button_pressed and _crossed(method_times(anim, &"show_results"), from, t):
		_on_play_crit(ap)


## times 중 하나가 (from, to] 사이에 있는지
static func _crossed(times: PackedFloat32Array, from: float, to: float) -> bool:
	for h in times:
		if from < h and h <= to:
			return true
	return false


## 치명타 강조 (게임 BattleScreen._emphasize 의 치명타 쪽): 화면 흔들림 × crit_shake_boost, 슬로우모션 시간 × crit_hitstop_boost
func _on_play_crit(ap: AnimationPlayer) -> void:
	var shake: float = _reaction(&"hit_shake")
	var boost: float = _reaction(&"crit_shake_boost")
	_start_screen_shake(shake * boost, _reaction(&"shake_time"))
	var stop: float = _reaction(&"hitstop_time")
	var stop_boost: float = _reaction(&"crit_hitstop_boost")
	_start_slowmo(ap, stop * stop_boost, _reaction(&"hitstop_speed"))


## 화면(무대 World) 흔들림 시작: strength 픽셀, time 초
func _start_screen_shake(strength: float, time: float) -> void:
	_shake_strength = strength
	_shake_ms = maxi(int(time * 1000.0), 1)
	_shake_until = Time.get_ticks_msec() + _shake_ms


## 슬로우모션 시작: 연출 씬 AnimationPlayer 를 speed 배속으로 time 초 동안 (겹치면 처음 배속을 기억해 두고 끝 시각만 바꿈)
func _start_slowmo(ap: AnimationPlayer, time: float, speed: float) -> void:
	if ap == null or time <= 0.0 or speed >= 1.0:
		return
	if _slow_player == null:
		_slow_player = ap
		_slow_prev = ap.speed_scale
	ap.speed_scale = maxf(speed, 0.0)
	_slow_until = Time.get_ticks_msec() + int(time * 1000.0)


## hit 키를 지남: 효과음, 화면 흔들림, 슬로우모션
func _on_play_hit(ap: AnimationPlayer) -> void:
	# 1. 효과음 (음높이는 매번 조금씩 다르게 — 게임과 같게)
	var snd: AudioStream = _reaction(&"hit_sound")
	if snd:
		var jitter: float = _reaction(&"pitch_jitter")
		_hit_sound.stream = snd
		_hit_sound.pitch_scale = 1.0 + randf_range(-jitter, jitter)
		_hit_sound.play()
	# 2. 화면 흔들림 (무대 World 를 흔든다)
	_start_screen_shake(_reaction(&"hit_shake"), _reaction(&"shake_time"))
	# 3. 슬로우모션: 연출 씬 AnimationPlayer 를 hitstop_speed 배속으로 hitstop_time 초 동안
	_start_slowmo(ap, _reaction(&"hitstop_time"), _reaction(&"hitstop_speed"))


## 틀을 복제해 칸 중심에 놓고 그림(Sprite)을 돌려준다. 박스는 편 색, 그림 묶음이 있으면 idle
func _add_unit(slot: BattleSlot, side: int, data: BattleData, boards: Dictionary) -> AnimatedSprite2D:
	var u := _template.duplicate() as Node2D
	u.visible = true
	_units.add_child(u)
	u.position = _cell_center(side, slot.cell, data, boards)
	(u.get_node(^"Box") as ColorRect).color = ALLY_COLOR if side == BattleTypes.Side.ALLY else ENEMY_COLOR
	var s := u.get_node(^"Sprite") as AnimatedSprite2D
	if slot.unit and slot.unit.battle_frames:
		s.sprite_frames = slot.unit.battle_frames
		s.animation = &"idle"
	return s


## 칸 중심 (World 좌표). 격자판이 없으면 대략 자리 (아군 왼쪽, 적 오른쪽)
func _cell_center(side: int, cell: Vector2i, data: BattleData, boards: Dictionary) -> Vector2:
	var board: BattleBoard = boards.get(side)
	var cols := data.ally_cols if side == BattleTypes.Side.ALLY else data.enemy_cols
	if board and board.supports(cols, data.rows):
		var used: Dictionary = board.use_cells(cols, data.rows)
		var c: GridCell = used.get(cell)
		if c:
			return _world.get_global_transform().affine_inverse() * (c.get_global_transform() * c.center())
	var x := 960.0 + (-1.0 if side == BattleTypes.Side.ALLY else 1.0) * (100.0 + 130.0 * (cell.x if side == BattleTypes.Side.ENEMY else (cols - 1 - cell.x)))
	return Vector2(x, 400.0 + 130.0 * cell.y)


## side 편 cell 칸의 격자판 칸 (판이 없거나 크기가 안 맞으면 null). _cell_center 와 같은 판 고르기
func _cell_of(side: int, cell: Vector2i, data: BattleData, boards: Dictionary) -> GridCell:
	var board: BattleBoard = boards.get(side)
	var cols := data.ally_cols if side == BattleTypes.Side.ALLY else data.enemy_cols
	if board and board.supports(cols, data.rows):
		return board.use_cells(cols, data.rows).get(cell)
	return null


## 연출에 관계있는 것만 보이게: 아군은 행위자 하나(연출 씬이 있으면 그 그림도 Actor 가 대신하므로 숨김),
## 격자 칸은 행위자 칸과 적 칸 하나씩
func _update_visible() -> void:
	for i in _ally_sprites.size():
		var unit := _ally_sprites[i].get_parent() as CanvasItem
		unit.visible = i == _actor
		# 연출 중 행위자는 Actor 가 대신 그리므로 그림도 박스도 숨긴다
		var replaced := i == _actor and _mirror != null
		_ally_sprites[i].visible = not replaced
		_show_box(_ally_sprites[i], not replaced)
	if _enemy_sprite:
		_show_box(_enemy_sprite, true)
	# 칸: 판의 켜진 칸을 모두 끄고 둘만 켠다
	for c in _background.find_children("*", "GridCell", true, false):
		c.visible = false
	var actor_cell: GridCell = _ally_cells[_actor] if _actor < _ally_cells.size() else null
	for c in [actor_cell, _enemy_cell]:
		if c:
			c.visible = true


## 유닛 sprite 의 편 색 박스: 보일 유닛(shown)이고 그림 묶음이 없을 때만 그림 대신 보인다
func _show_box(sprite: AnimatedSprite2D, shown: bool) -> void:
	(sprite.get_parent().get_node(^"Box") as CanvasItem).visible = shown and sprite.sprite_frames == null


## cell 이 cols×rows 격자 안인지
static func _in_grid(cell: Vector2i, cols: int, rows: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


## 내 칸·적 칸 목록을 이 전투의 격자 크기로 채운다 (글자 "열,행", 메타데이터 = 칸 좌표)
func _fill_cell_lists(data: BattleData) -> void:
	for pair in [[_actor_cell_list, data.ally_cols], [_enemy_cell_list, data.enemy_cols]]:
		var list: OptionButton = pair[0]
		list.clear()
		for y in data.rows:
			for x in pair[1]:
				list.add_item("%d,%d" % [x, y])
				list.set_item_metadata(list.item_count - 1, Vector2i(x, y))
	_select_cell_items()


## 목록에서 지금 행위자·적 칸 줄을 고른 상태로
func _select_cell_items() -> void:
	if not is_node_ready() or _battle == null:
		return
	var a := _actor_cell_pick
	if a == NO_CELL and _actor < _battle.allies.size():
		a = _battle.allies[_actor].cell
	var e := _enemy_cell_pick
	if e == NO_CELL and not _battle.enemies.is_empty():
		e = _battle.enemies[0].cell
	for pair in [[_actor_cell_list, a], [_enemy_cell_list, e]]:
		var list: OptionButton = pair[0]
		for i in list.item_count:
			if list.get_item_metadata(i) == pair[1]:
				list.select(i)
				break


func _on_actor_cell_item(index: int) -> void:
	var cell: Vector2i = _actor_cell_list.get_item_metadata(index)
	set_actor_cell(cell)
	actor_cell_selected.emit(cell)


func _on_enemy_cell_item(index: int) -> void:
	var cell: Vector2i = _enemy_cell_list.get_item_metadata(index)
	set_enemy_cell(cell)
	enemy_cell_selected.emit(cell)


## 배경 목록을 폴더에서 채운다
func _fill_background_list() -> void:
	_background_list.clear()
	for p in background_paths():
		_background_list.add_item(p.get_file().get_basename())
		_background_list.set_item_metadata(_background_list.item_count - 1, p)
	_select_background_item()


## 목록에서 지금 배경 줄을 고른 상태로 (고른 배경이 없으면 전투 데이터의 배경)
func _select_background_item() -> void:
	if not is_node_ready():
		return
	var path := _background_path
	if path.is_empty() and _battle and _battle.background:
		path = _battle.background.resource_path
	for i in _background_list.item_count:
		if _background_list.get_item_metadata(i) == path:
			_background_list.select(i)
			return


## 적 목록을 유닛 폴더에서 채운다 (이름 = 유닛 표시 이름, 메타데이터 = 경로)
func _fill_enemy_list() -> void:
	_enemy_list.clear()
	for p in enemy_paths():
		var u: UnitData = load(p)
		_enemy_list.add_item(u.display_name if not u.display_name.is_empty() else p.get_file().get_basename())
		_enemy_list.set_item_metadata(_enemy_list.item_count - 1, p)
	_select_enemy_item()


## 목록에서 지금 적 줄을 고른 상태로 (고른 적이 없으면 전투 데이터의 첫 적)
func _select_enemy_item() -> void:
	if not is_node_ready():
		return
	var path := _enemy_path
	if path.is_empty() and _battle and not _battle.enemies.is_empty() and _battle.enemies[0].unit:
		path = _battle.enemies[0].unit.resource_path
	for i in _enemy_list.item_count:
		if _enemy_list.get_item_metadata(i) == path:
			_enemy_list.select(i)
			return


func _on_enemy_item(index: int) -> void:
	var path: String = _enemy_list.get_item_metadata(index)
	set_enemy(path)
	enemy_selected.emit(path)


func _on_background_item(index: int) -> void:
	var path: String = _background_list.get_item_metadata(index)
	set_background(path)
	background_selected.emit(path)


func _find_boards(node: Node) -> Array[BattleBoard]:
	var out: Array[BattleBoard] = []
	for c in node.get_children():
		if c is BattleBoard:
			out.append(c)
		out.append_array(_find_boards(c))
	return out


func _rebuild_mirror() -> void:
	if _mirror:
		_mirror.queue_free()
		_mirror = null
	_shape = PackedStringArray()
	_hint.visible = _source == null
	_update_visible()
	if _source == null:
		return
	# 씬 파일에서 다시 만들지 않고 지금 노드 그대로 복제 (편집 중 추가한 노드도 포함되게)
	_mirror = _source.duplicate(Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS) as Node2D
	# 복제본은 그림만: 스크립트·애니메이션 플레이어는 뺀다 (원본의 값을 옮겨 받기만 함)
	_mirror.set_script(null)
	# 복제본의 Camera2D 가 켜져 있으면 무대 화면을 가로채 구도가 두 번 들어가므로 끈다
	for c in _mirror.find_children("*", "Camera2D", true, false):
		c.enabled = false
	for ap in _mirror.find_children("*", "AnimationPlayer", true, false):
		ap.get_parent().remove_child(ap)
		ap.free()
	_perf_layer.add_child(_mirror)
	_shape = _paths(_source)
	_update_visible()


## root 아래 노드들의 경로 목록 (AnimationPlayer 제외)
func _paths(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for n in root.find_children("*", "", true, false):
		if not n is AnimationPlayer:
			out.append(String(root.get_path_to(n)))
	return out


func _is_performance(n: Node) -> bool:
	if n == null or not n is Node2D:
		return false
	var s: Script = n.get_script()
	return s != null and s.get_global_name() == &"CardPerformance"


## n 의 World 좌표 기준 변환 (카메라로 움직인 World 자신의 변환은 빠짐)
func _in_world(n: Node2D) -> Transform2D:
	return _world.get_global_transform().affine_inverse() * n.get_global_transform()


func _set_world(x: Transform2D) -> void:
	_world.pivot_offset = Vector2.ZERO
	_world.position = x.origin
	# 화면 흔들림: 남은 비율만큼 무작위로 (카메라 구도 위에 더함)
	var left := _shake_until - Time.get_ticks_msec()
	if left > 0 and _shake_strength > 0.0:
		var a := _shake_strength * float(left) / float(_shake_ms)
		_world.position += Vector2(randf_range(-a, a), randf_range(-a, a))
	_world.rotation = x.get_rotation()
	_world.scale = x.get_scale()


static func _local_pos(root: Node, path: NodePath, fallback: Vector2) -> Vector2:
	var n := root.get_node_or_null(path) as Node2D
	return n.position if n else fallback


static func _zoom_of(cam: Node2D) -> Vector2:
	return cam.zoom if cam is Camera2D else Vector2.ONE


static func _perform(root: Node) -> Animation:
	var ap := root.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if ap and ap.has_animation(&"perform"):
		return ap.get_animation(&"perform")
	return null


## dir 아래(하위 폴더 포함) 카드들 (.remap 처리)
static func _cards_in(dir: String) -> Array[CardData]:
	var out: Array[CardData] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_cards_in(dir.path_join(sub)))
	for f in d.get_files():
		var path := dir.path_join(f.trim_suffix(".remap"))
		if path.ends_with(".tres"):
			var c := load(path) as CardData
			if c:
				out.append(c)
	return out
