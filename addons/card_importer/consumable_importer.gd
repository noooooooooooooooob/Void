@tool
class_name ConsumableImporter
extends RefCounted
## 웹 카드 에디터 내보내기 zip 의 소비 아이템(cards.json 의 "consumables")을 Godot 소비 아이템 데이터로 바꾸는 가져오기 로직.
## 카드는 CardImporter, 장비는 EquipmentImporter, 소비 아이템은 이 클래스가 맡는다. 같은 zip 을 CardImporter.read_zip() 으로 읽고
## get_data() / get_art() 를 넘겨받아 쓴다 (plugin.gd 참고).
##
## 만드는 파일 (root 기본값 res://items/consumables 기준):
##   <아이템 이름>.tres   소비 아이템. 이름이 겹치면 <이름>_<id>.tres
##   art/<파일 이름>      아이템 그림
##
## 다시 가져올 때 규칙 (설계: docs/superpowers/specs/2026-11-17-consumable-targets-design.md):
##   - 웹 에디터 담당 칸(이름, 설명, 키워드, 그림, 사용 대상, 범위, 효과 줄)만 덮어쓴다. Godot 에서 붙인 effects 는 그대로 둔다.
##   - 효과 줄 중 스탯 버프(buff)와 모르는 종류는 Godot 에 아직 없어 버린다. 버린 줄 수는 preview().dropped 로 알린다.
##   - 파일은 이름이 아니라 파일 안의 id 로 찾는다. 이름이 바뀌면 파일을 옮겨 uid 를 유지한다.
##   - id 가 없는 아이템 파일(Godot 에서 직접 만든 시험 아이템)은 건드리지 않는다.
##   - zip 에 없는 아이템은 지운다 (가방은 의뢰 동안만 있고 파일로 남지 않으므로 "사용 중이라 남김"은 없다).
##   - zip 에 "consumables" 키 자체가 없으면(예전 zip) 아이템을 하나도 바꾸지 않는다.
##
## 사용 순서: load_export() → preview()로 확인 → apply().

## 웹 에디터의 사용 대상 값 → ConsumableData.Target. 없는 값은 아군.
const TARGETS := {"ally": ConsumableData.Target.ALLY, "enemy": ConsumableData.Target.ENEMY, "both": ConsumableData.Target.BOTH}
## 웹 에디터의 효과 종류 → ConsumableLine.Type. 여기에 없는 종류(buff 등)는 버린다.
const LINE_TYPES := {"heal_hp": ConsumableLine.Type.HEAL_HP, "heal_sp": ConsumableLine.Type.HEAL_SP}
## 범위 격자의 반지름 (−2..2, 웹 에디터·카드와 같음)
const AREA_RADIUS := 2

## 결과 파일을 저장할 폴더. 테스트에서는 user:// 아래 임시 폴더를 넣는다.
var root: String
## cards.json 을 파싱한 내용
var _data: Dictionary = {}
## zip 안의 그림 파일. "art/<파일 이름>" → 파일 내용
var _art: Dictionary = {}
## 파일 이름 다듬기·저장·삭제 같은 공용 도구 (CardImporter 의 것을 그대로 쓴다)
var _util: CardImporter


## root_dir: 소비 아이템을 저장할 폴더.
func _init(root_dir: String = "res://items/consumables") -> void:
	root = root_dir
	_util = CardImporter.new(root)


## 가져올 내용을 넣는다. data: cards.json 과 같은 구조, art: "art/<파일 이름>" → 파일 내용.
func load_export(data: Dictionary, art: Dictionary = {}) -> void:
	_data = data
	_art = art


## 파일을 건드리지 않고, apply() 하면 무엇이 바뀌는지만 계산한다. 미리보기 창에 쓴다.
## 반환: { added: 새로 생길 아이템 이름들, updated: 덮어쓸 아이템 이름들,
##         removed: [{ name, has_effects: Godot 에서 붙인 특수 효과가 있는지 }],
##         dropped: [{ name, count: 버린 효과 줄 수 }] — Godot 에 없는 효과(스탯 버프 등)를 뺀 아이템 }
func preview() -> Dictionary:
	var out := {"added": PackedStringArray(), "updated": PackedStringArray(), "removed": [], "dropped": []}
	if not _has_consumables():
		return out
	var existing := _existing()
	var incoming := {}
	for c in _list():
		var id := str(c.get("id", ""))
		var name := _util._text(c, "name", "ko")
		incoming[id] = true
		(out.updated if existing.has(id) else out.added).append(name)
		var dropped := _dropped_count(c)
		if dropped > 0:
			out.dropped.append({"name": name, "count": dropped})
	# 파일은 있는데 zip 에 없는 아이템 = 웹 에디터에서 지운 아이템
	for id in existing:
		if incoming.has(id):
			continue
		var item := _util._load(existing[id]) as ConsumableData
		out.removed.append({"name": item.display_name if item else id, "has_effects": item != null and not item.effects.is_empty()})
	return out


## 실제로 파일을 만들고, 덮어쓰고, 지운다.
func apply() -> void:
	if not _has_consumables():
		return
	var existing := _existing()  # 아이템 id → 현재 파일 경로
	var incoming := {}
	for c in _list():
		incoming[str(c.get("id", ""))] = true

	# 0. zip 에 없는 아이템은 먼저 지운다 (그 자리를 새 아이템이 쓸 수 있게).
	#    id 없는 파일(시험 아이템)의 경로와 그림은 다른 아이템이 덮어쓰지 못하게 비워 둔다.
	var reserved := _unmanaged_paths()
	var used_art := {}
	for path in reserved:
		_keep_art(path, used_art)
	for id in existing.keys():
		if not incoming.has(id):
			_util._delete(existing[id])
			existing.erase(id)
	var targets := _paths(reserved)  # 아이템 id → 저장할 경로

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

	for c in _list():
		var id := str(c.get("id", ""))
		var path: String = targets[id]
		# 2. 비켜 둔 파일을 새 경로로 옮긴다 (파일째 옮기므로 uid 유지).
		if moving.has(id):
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			DirAccess.rename_absolute(moving[id], path)
			if held.has(id):
				held[id].take_over_path(path)
		# 3. 기존 파일을 불러와 웹 칸만 고친다 → effects 유지.
		var item: ConsumableData = _util._load(path) as ConsumableData if existing.has(id) else null
		if item == null:
			item = ConsumableData.new()
		_fill(item, c, used_art)
		item.id = id
		_util._save(item, path)

	_remove_unused_art(used_art)
	_util._remove_empty_dirs(root)


## zip 에 소비 아이템 목록 키가 있는지. 없으면 예전 zip 이라 아이템을 건드리지 않는다.
func _has_consumables() -> bool:
	return typeof(_data.get("consumables")) == TYPE_ARRAY


## zip 의 아이템 목록 (id 없는 항목은 뺀다)
func _list() -> Array:
	var out := []
	for c in _data.get("consumables", []):
		if typeof(c) == TYPE_DICTIONARY and not str(c.get("id", "")).is_empty():
			out.append(c)
	return out


## 아이템 id → 저장할 경로. 경로: <이름>.tres, 같은 경로가 겹치면 뒤 아이템에 "_<id>".
## reserved: 이미 다른 파일(id 없는 시험 아이템)이 쓰는 경로 — 겹치면 역시 "_<id>".
func _paths(reserved: Dictionary = {}) -> Dictionary:
	var out := {}
	var taken := reserved.duplicate()
	for c in _list():
		var id := str(c.get("id", ""))
		var file := _util._safe_name(_util._text(c, "name", "ko"), id)
		var path := root.path_join("%s.tres" % file)
		if taken.has(path):
			path = root.path_join("%s_%s.tres" % [file, id])
		taken[path] = true
		out[id] = path
	return out


## 아이템 하나의 웹 담당 칸을 채운다. effects 는 건드리지 않는다.
func _fill(item: ConsumableData, c: Dictionary, used_art: Dictionary) -> void:
	item.display_name = _util._text(c, "name", "ko")
	item.name_en = _util._text(c, "name", "en")
	item.description_ko = _util._text(c, "description", "ko")
	item.description_en = _util._text(c, "description", "en")
	# 모르는 대상은 아군 (예전 아이템도 아군)
	item.target = TARGETS.get(str(c.get("target", "")), ConsumableData.Target.ALLY)
	item.area = _area(c.get("area"))
	# 효과 줄 {type, kind, amount} → ConsumableLine. Godot 에 없는 종류(buff 등)는 버린다.
	var lines: Array[ConsumableLine] = []
	for e in c.get("effects", []):
		if typeof(e) != TYPE_DICTIONARY or not LINE_TYPES.has(str(e.get("type", ""))):
			continue
		var line := ConsumableLine.new()
		line.type = LINE_TYPES[str(e.get("type"))]
		line.kind = ConsumableLine.Kind.PERCENT if e.get("kind") == "percent" else ConsumableLine.Kind.FLAT
		line.amount = int(e.get("amount", 0))
		lines.append(line)
	item.lines = lines
	item.keywords = PackedStringArray(c.get("keywords", []))
	item.art = _copy_art(c.get("art"), used_art)


## 웹 범위 [[x, y], …] → Vector2i 목록. 격자(−2..2) 밖·중복·형식이 틀린 칸은 버린다.
func _area(raw) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for cell in raw:
		if typeof(cell) != TYPE_ARRAY or cell.size() != 2:
			continue
		var v := Vector2i(int(cell[0]), int(cell[1]))
		if absi(v.x) > AREA_RADIUS or absi(v.y) > AREA_RADIUS or out.has(v):
			continue
		out.append(v)
	return out


## 아이템의 효과 줄 중 Godot 에 없어 버리는 줄 수.
func _dropped_count(c: Dictionary) -> int:
	var n := 0
	for e in c.get("effects", []):
		if typeof(e) == TYPE_DICTIONARY and not LINE_TYPES.has(str(e.get("type", ""))):
			n += 1
	return n


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


## 아이템 그림 폴더에서 이번에 쓰이지 않은 그림을 지운다 (.import 는 _delete 가 같이 지운다).
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


## id 가 있는 기존 아이템 파일 { 아이템 id: 경로 }. id 없는 시험 아이템은 관리 대상이 아니라 뺀다.
func _existing() -> Dictionary:
	var out := {}
	for path in _util._tres_paths(root):
		var item := _util._load(path) as ConsumableData
		if item and not item.id.is_empty():
			out[item.id] = path
	return out


## 가져오기가 관리하지 않는(id 없는) 아이템 파일 경로 → true
func _unmanaged_paths() -> Dictionary:
	var out := {}
	for path in _util._tres_paths(root):
		var item := _util._load(path) as ConsumableData
		if item and item.id.is_empty():
			out[path] = true
	return out


## path 의 아이템이 쓰는 그림을 "사용 중"으로 표시한다 (남기는 아이템의 그림이 정리되지 않게).
func _keep_art(path: String, used_art: Dictionary) -> void:
	var item := _util._load(path) as ConsumableData
	if item and not item.art.is_empty():
		used_art[item.art] = true
