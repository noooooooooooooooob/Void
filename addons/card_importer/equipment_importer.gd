@tool
class_name EquipmentImporter
extends RefCounted
## 웹 카드 에디터 내보내기 zip 의 장비(cards.json 의 "equipment")를 Godot 장비 데이터로 바꾸는 가져오기 로직.
## 카드는 CardImporter 가, 장비는 이 클래스가 맡는다. 같은 zip 을 CardImporter.read_zip() 으로 읽고
## get_data() / get_art() 를 넘겨받아 쓴다 (plugin.gd 참고).
##
## 만드는 파일 (root 기본값 res://statuses/equipment 기준):
##   <종류>/<장비 이름>.tres   장비 (종류 = weapon / armor / accessory). 같은 폴더에 이름이 겹치면 <이름>_<id>.tres
##   art/<파일 이름>           장비 그림 (카드 그림 폴더와 따로 둔다 — 카드 그림 정리 규칙을 건드리지 않기 위해)
##
## 다시 가져올 때 규칙 (설계: docs/superpowers/specs/2026-11-10-equipment-editor-design.md):
##   - 웹 에디터 담당 칸(이름, 설명, 종류, 등급, 스탯, 키워드, 그림)만 덮어쓴다. Godot 에서 붙인 statuses 는 그대로 둔다.
##   - 파일은 이름이 아니라 파일 안의 id 로 찾는다. 이름·종류가 바뀌면 파일을 옮겨 uid 를 유지한다(유닛 참조 유지).
##   - id 가 없는 예전 장비 파일(test_sword.tres 등)은 건드리지 않는다.
##   - zip 에 없는 장비는 지운다. 단, 유닛이 착용 중이면 지우지 않고 남긴다 (사용자 결정).
##   - zip 에 "equipment" 키 자체가 없으면(예전 zip) 장비를 하나도 바꾸지 않는다.
##
## 사용 순서: load_export() → preview()로 확인 → apply().

## 웹 에디터의 스탯 키. 순서 = BattleTypes.Stat (순번이 곧 enum 값). CardExporter 도 이 표를 쓴다.
const STAT_KEYS: Array[String] = ["hp", "sp", "attack", "defense", "speed", "move",
	"crit_rate", "crit_damage", "aggro", "stamina", "actions"]

## 결과 파일을 저장할 최상위 폴더. 테스트에서는 user:// 아래 임시 폴더를 넣는다.
var root: String
## 착용 여부를 확인할 유닛 데이터 폴더 (그 아래 모든 UnitData .tres)
var units_root: String
## cards.json 을 파싱한 내용
var _data: Dictionary = {}
## zip 안의 그림 파일. "art/<파일 이름>" → 파일 내용
var _art: Dictionary = {}
## 파일 이름 다듬기·저장·삭제 같은 공용 도구 (CardImporter 의 것을 그대로 쓴다)
var _util: CardImporter


## root_dir: 장비를 저장할 폴더. units_dir: 착용 여부를 볼 유닛 폴더.
func _init(root_dir: String = "res://statuses/equipment", units_dir: String = "res://entities/units") -> void:
	root = root_dir
	units_root = units_dir
	_util = CardImporter.new(root)


## 가져올 내용을 넣는다. data: cards.json 과 같은 구조, art: "art/<파일 이름>" → 파일 내용.
func load_export(data: Dictionary, art: Dictionary = {}) -> void:
	_data = data
	_art = art


## 파일을 건드리지 않고, apply() 하면 무엇이 바뀌는지만 계산한다. 미리보기 창에 쓴다.
## 반환: { added: 새로 생길 장비 이름들, updated: 덮어쓸 장비 이름들,
##         removed: [{ name, has_statuses: Godot 에서 붙인 상태가 있는지 }],
##         kept: [{ name, units: 착용 중인 유닛 이름들 }] — zip 에 없지만 착용 중이라 남기는 장비 }
func preview() -> Dictionary:
	var out := {"added": PackedStringArray(), "updated": PackedStringArray(), "removed": [], "kept": []}
	if not _has_equipment():
		return out
	var existing := _existing()
	var incoming := {}
	for e in _list():
		var id := str(e.get("id", ""))
		incoming[id] = true
		(out.updated if existing.has(id) else out.added).append(_util._text(e, "name", "ko"))

	# 파일은 있는데 zip 에 없는 장비 = 웹 에디터에서 지운 장비. 착용 중이면 남긴다.
	var wearers := _wearers()
	for id in existing:
		if incoming.has(id):
			continue
		var eq := _util._load(existing[id]) as EquipmentData
		var name: String = eq.display_name if eq else id
		if wearers.has(existing[id]):
			out.kept.append({"name": name, "units": wearers[existing[id]]})
		else:
			out.removed.append({"name": name, "has_statuses": eq != null and not eq.statuses.is_empty()})
	return out


## 실제로 파일을 만들고, 덮어쓰고, 지운다.
func apply() -> void:
	if not _has_equipment():
		return
	var existing := _existing()  # 장비 id → 현재 파일 경로
	var targets := _paths()  # 장비 id → 저장할 경로
	var used_art := {}

	# 1. 옮겨야 하는 기존 파일은 먼저 임시 이름으로 비켜 둔다 (서로 자리를 바꿔도 덮어쓰지 않게).
	var moving := {}
	var held := {}  # 에디터가 옛 경로로 들고 있던 리소스 → 새 경로로 넘긴다 (중복 파일 방지)
	for id in targets:
		if existing.has(id) and existing[id] != targets[id]:
			if ResourceLoader.has_cached(existing[id]):
				held[id] = ResourceLoader.load(existing[id])
			var tmp: String = existing[id] + ".moving"
			DirAccess.rename_absolute(existing[id], tmp)
			moving[id] = tmp

	for e in _list():
		var id := str(e.get("id", ""))
		if not targets.has(id):
			continue
		var path: String = targets[id]
		# 2. 비켜 둔 파일을 새 경로로 옮긴다 (파일째 옮기므로 uid 유지).
		if moving.has(id):
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			DirAccess.rename_absolute(moving[id], path)
			if held.has(id):
				held[id].take_over_path(path)
		# 3. 기존 파일을 불러와 웹 칸만 고친다 → statuses 유지.
		var eq: EquipmentData = _util._load(path) as EquipmentData if existing.has(id) else null
		if eq == null:
			eq = EquipmentData.new()
		_fill(eq, e, used_art)
		eq.id = id
		_util._save(eq, path)
		existing.erase(id)

	# 4. 남은 것 = zip 에 없는 장비. 착용 중이 아니면 지운다.
	var wearers := _wearers()
	for id in existing:
		if not wearers.has(existing[id]):
			_util._delete(existing[id])
	_remove_unused_art(used_art)
	_util._remove_empty_dirs(root)


## zip 에 장비 목록 키가 있는지. 없으면 예전 zip 이라 장비를 건드리지 않는다.
func _has_equipment() -> bool:
	return typeof(_data.get("equipment")) == TYPE_ARRAY


## zip 의 장비 목록 (id 없는 항목은 뺀다)
func _list() -> Array:
	var out := []
	for e in _data.get("equipment", []):
		if typeof(e) == TYPE_DICTIONARY and not str(e.get("id", "")).is_empty():
			out.append(e)
	return out


## 장비 id → 저장할 경로. 경로: <종류>/<이름>.tres, 같은 경로가 겹치면 뒤 장비에 "_<id>".
func _paths() -> Dictionary:
	var out := {}
	var taken := {}
	for e in _list():
		var id := str(e.get("id", ""))
		var file := _util._safe_name(_util._text(e, "name", "ko"), id)
		var folder := _pick(e.get("slot"), EquipmentData.SLOTS)
		var path := root.path_join("%s/%s.tres" % [folder, file])
		if taken.has(path):
			path = root.path_join("%s/%s_%s.tres" % [folder, file, id])
		taken[path] = true
		out[id] = path
	return out


## 장비 하나의 웹 담당 칸을 채운다. statuses 는 건드리지 않는다.
func _fill(eq: EquipmentData, e: Dictionary, used_art: Dictionary) -> void:
	eq.display_name = _util._text(e, "name", "ko")
	eq.name_en = _util._text(e, "name", "en")
	eq.description_ko = _util._text(e, "description", "ko")
	eq.description_en = _util._text(e, "description", "en")
	# 모르는 종류·등급은 첫 값(무기·노말)으로
	eq.slot = _pick(e.get("slot"), EquipmentData.SLOTS)
	eq.rarity = _pick(e.get("rarity"), EquipmentData.RARITIES)
	# 스탯 줄 {stat, kind, amount} → StatModifier. 모르는 스탯 키는 버린다.
	var stats: Array[StatModifier] = []
	for s in e.get("stats", []):
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var idx := STAT_KEYS.find(str(s.get("stat", "")))
		if idx < 0:
			continue
		var mod := StatModifier.new()
		mod.stat = idx
		mod.kind = BattleTypes.ModKind.PERCENT if s.get("kind") == "percent" else BattleTypes.ModKind.FLAT
		mod.amount = float(s.get("amount", 0))
		stats.append(mod)
	eq.stats = stats
	eq.keywords = PackedStringArray(e.get("keywords", []))
	eq.art = _copy_art(e.get("art"), used_art)


## 값이 목록에 있으면 그대로, 아니면 목록의 첫 값.
func _pick(value, allowed: Array[String]) -> String:
	var s := str(value) if value != null else ""
	return s if allowed.has(s) else allowed[0]


## 그림을 root/art/ 로 복사하고 경로를 돌려준다. 그림이 없거나 zip 에 없으면 "".
func _copy_art(src, used_art: Dictionary) -> String:
	if typeof(src) != TYPE_STRING or not _art.has(src):
		return ""
	var dest := root.path_join("art").path_join(src.get_file())
	if not used_art.has(dest):
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		var f := FileAccess.open(dest, FileAccess.WRITE)
		f.store_buffer(_art[src])
		f.close()
		used_art[dest] = true
	return dest


## 장비 그림 폴더에서 이번에 쓰이지 않은 그림을 지운다 (.import 는 _delete 가 같이 지운다).
func _remove_unused_art(used_art: Dictionary) -> void:
	var dir_path := root.path_join("art")
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".import"):
			continue
		var path := dir_path.path_join(f)
		if not used_art.has(path):
			_util._delete(path)


## id 가 있는 기존 장비 파일 { 장비 id: 경로 }. id 없는 예전 파일은 관리 대상이 아니라 뺀다.
func _existing() -> Dictionary:
	var out := {}
	for path in _util._tres_paths(root):
		var eq := _util._load(path) as EquipmentData
		if eq and not eq.id.is_empty():
			out[eq.id] = path
	return out


## 장비 파일 경로 → 그 장비를 착용한 유닛 이름들. units_root 아래 모든 UnitData 를 본다.
func _wearers() -> Dictionary:
	var out := {}
	for path in _util._tres_paths(units_root):
		var unit := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as UnitData
		if unit == null:
			continue
		var name := unit.display_name if not unit.display_name.is_empty() else path.get_file().get_basename()
		for eq in unit.equipment:
			if eq == null or eq.resource_path.is_empty():
				continue
			if not out.has(eq.resource_path):
				out[eq.resource_path] = PackedStringArray()
			out[eq.resource_path].append(name)
	return out
