@tool
class_name EnemyFramesBuilder
extends RefCounted
## 적 그림 폴더(Art/enemies/)를 읽어 전투 그림 묶음(SpriteFrames)과 적 유닛(UnitData) .tres 를 만든다 (2026-11-25).
## 에디터 메뉴 프로젝트 → 도구 → "적 그림 가져오기..." (card_importer/plugin.gd) 가 쓴다.
##
## 그림 규칙: Art/enemies/<배경>/<이름>/<이름>_<동작>.png. 동작 이름이 그대로 애니메이션 이름이 된다.
##   - 배경(무대) 폴더로 묶는 건 사용자 결정 (2026-11-25). 묶지 않은 Art/enemies/<이름>/ 도 읽는다
##   - idle = 서 있기 (반복), hit = 맞기 (한 번), attack 등 나머지 = 카드 동작 (한 번, CardData.animation 과 같은 이름)
##   - 한 동작에 여러 장이면 <이름>_<동작>_<번호>.png (번호 순서대로 한 애니메이션)
## 만드는 파일 (out_dir/<배경>/ 아래, 그림 폴더와 같은 묶음):
##   - <이름>_frames.tres : 매번 그림 폴더대로 다시 채운다. 이미 있으면 같은 파일(uid 유지)을 고쳐 쓴다
##   - <이름>.tres        : 없을 때만 만든다 (template 유닛의 스탯·덱을 복사). 있으면 battle_frames 만 비어 있을 때 채우고
##                          나머지(이름·스탯·덱·배율)는 Godot 에서 고친 값을 그대로 둔다

## 반복 재생하는 동작 (나머지는 한 번 재생하고 idle 로 돌아간다 — unit_token.gd)
const LOOP_POSES := [&"idle"]
## 동작별 재생 속도 (초당 장 수). 한 장짜리면 1/속도 초 동안 보인다. 없는 동작은 DEFAULT_SPEED
const POSE_SPEED := {&"idle": 5.0, &"hit": 3.0, &"attack": 2.0}
## POSE_SPEED 에 없는 동작의 속도
const DEFAULT_SPEED := 4.0
## 새로 만드는 적 유닛의 전투 그림 배율 (UnitData.battle_scale).
## 적 그림 캔버스는 약 480px, 홍연은 128px × 10 → 2.7 이면 홍연과 비슷한 키가 된다
const DEFAULT_SCALE := 2.7

## 마지막 apply() 결과: 새로 만든 그림 묶음 (키 = "<배경>/<이름>")
var frames_added := PackedStringArray()
## 마지막 apply() 결과: 다시 채운 (이미 있던) 그림 묶음
var frames_updated := PackedStringArray()
## 마지막 apply() 결과: 새로 만든 적 유닛
var units_added := PackedStringArray()


## art_dir 아래 적 폴더마다 동작 → 그림 경로 목록을 모은다.
## 돌려주는 값: { "<배경>/<이름>": { &"<동작>": PackedStringArray(경로, 번호 순) } }.
## 그림이 없는 폴더(배경 폴더)는 그 안을 계속 찾는다. 키는 art_dir 기준 상대 경로 (묶지 않은 적은 "<이름>").
static func scan(art_dir: String, _rel: String = "") -> Dictionary:
	var out := {}
	var here := art_dir.path_join(_rel) if _rel != "" else art_dir
	var dir := DirAccess.open(here)
	if dir == null:
		return out
	for sub in dir.get_directories():
		var rel := _rel.path_join(sub) if _rel != "" else sub
		var poses := _poses_in(here.path_join(sub), sub)
		if poses.is_empty():
			out.merge(scan(art_dir, rel))  # 배경 폴더 → 그 안의 적 폴더들
		else:
			out[rel] = poses
	return out


## folder 안의 <enemy>_<동작>[_<번호>].png 그림을 동작별로 모은다. 없으면 빈 Dictionary.
static func _poses_in(folder: String, enemy: String) -> Dictionary:
	var poses := {}
	var prefix := enemy + "_"
	var files := DirAccess.get_files_at(folder)
	files.sort()  # 번호 순서 (_1, _2 …)
	for f in files:
		if f.get_extension().to_lower() != "png" or not f.begins_with(prefix):
			continue
		# <이름>_<동작>[_<번호>].png → 동작 이름
		var rest := f.get_basename().substr(prefix.length())
		var parts := rest.split("_")
		if parts.size() > 1 and parts[-1].is_valid_int():
			parts.remove_at(parts.size() - 1)
		var pose := StringName("_".join(parts))
		if pose == &"":
			continue
		if not poses.has(pose):
			poses[pose] = PackedStringArray()
		poses[pose].append(folder.path_join(f))
	return poses


## frames 를 비우고 poses(scan 의 한 적 몫)대로 애니메이션을 채운다. 그림을 못 읽은 장은 건너뛴다.
static func fill_frames(frames: SpriteFrames, poses: Dictionary) -> void:
	# 1. 기존 애니메이션 모두 지우기 (새 SpriteFrames 의 "default" 포함)
	for anim in frames.get_animation_names():
		frames.remove_animation(anim)
	# 2. 동작마다 애니메이션 하나
	for pose in poses:
		frames.add_animation(pose)
		frames.set_animation_loop(pose, pose in LOOP_POSES)
		frames.set_animation_speed(pose, POSE_SPEED.get(pose, DEFAULT_SPEED))
		for path in poses[pose]:
			var tex := load(path) as Texture2D
			if tex:
				frames.add_frame(pose, tex)


## art_dir 의 적 그림으로 out_dir 에 그림 묶음·유닛을 만들거나 갱신한다. template = 새 유닛의 스탯·덱을 복사할 유닛.
## 결과는 frames_added / frames_updated / units_added 에 담긴다. 실패한 저장이 있으면 그 오류 문구들을 돌려준다.
func apply(art_dir: String, out_dir: String, template: UnitData) -> PackedStringArray:
	frames_added.clear()
	frames_updated.clear()
	units_added.clear()
	var errors := PackedStringArray()
	var found := scan(art_dir)
	var keys := found.keys()
	keys.sort()
	for key in keys:
		# 그림 폴더와 같은 묶음 폴더에 둔다: "<배경>/<이름>" → out_dir/<배경>/<이름>…
		var enemy: String = key.get_file()
		var folder := out_dir.path_join(key.get_base_dir()) if key.get_base_dir() != "" else out_dir
		DirAccess.make_dir_recursive_absolute(folder)
		# 1. 그림 묶음: 있으면 그 리소스를 고쳐 같은 파일에 저장 (uid·참조 유지), 없으면 새로
		var frames_path := folder.path_join("%s_frames.tres" % enemy)
		var frames: SpriteFrames = null
		if ResourceLoader.exists(frames_path):
			frames = load(frames_path) as SpriteFrames
		var is_new := frames == null
		if is_new:
			frames = SpriteFrames.new()
		fill_frames(frames, found[key])
		var err := ResourceSaver.save(frames, frames_path)
		if err != OK:
			errors.append("%s 저장 실패 (%s)" % [frames_path, error_string(err)])
			continue
		if is_new:
			frames.take_over_path(frames_path)
			frames_added.append(key)
		else:
			frames_updated.append(key)
		# 2. 유닛: 없을 때만 만든다. 있으면 그림 묶음이 비어 있을 때만 채운다
		var unit_path := folder.path_join("%s.tres" % enemy)
		if ResourceLoader.exists(unit_path):
			var unit := load(unit_path) as UnitData
			if unit and unit.battle_frames == null:
				unit.battle_frames = frames
				ResourceSaver.save(unit, unit_path)
			continue
		var made: UnitData = template.duplicate() if template else UnitData.new()
		made.display_name = enemy
		made.battle_frames = frames
		made.battle_scale = DEFAULT_SCALE
		made.battle_pixel_art = false
		err = ResourceSaver.save(made, unit_path)
		if err != OK:
			errors.append("%s 저장 실패 (%s)" % [unit_path, error_string(err)])
		else:
			units_added.append(key)
	return errors
