@tool
class_name CardImporter
extends RefCounted
## 웹 카드 에디터의 내보내기 파일(zip)을 Godot 카드 데이터로 바꾸는 가져오기 로직.
##
## zip 구성: cards.json(카드·덱·키워드 목록) + art/(카드 그림).
## 만드는 파일 (root 기본값 res://cards 기준):
##   data/<덱 이름>/<카드 이름>.tres 카드 (공용 카드는 data/common/)
##     같은 폴더에 이름이 같은 카드가 있으면 뒤 카드는 <카드 이름>_<id>.tres
##   keywords/<키워드 id>.tres        키워드 이름·설명
##   art/<파일 이름>                  그림
##
## 다시 가져올 때 규칙:
##   - 웹 에디터가 담당하는 칸(이름, 설명, SP, 코스트, 분류, 공격 종류, 범위, 키워드, 그림)만 덮어쓴다.
##   - Godot 에서 붙인 costs / conditions / effects 는 그대로 둔다. 강화 단계도 같은 규칙.
##   - 웹 에디터에서 지운 카드·키워드, 더 이상 쓰지 않는 그림은 지운다.
##   - 카드 파일은 파일 이름이 아니라 파일 안의 id 로 찾는다. 이름·덱이 바뀌면 파일을 옮긴다(이름 바꾸기).
##     새로 만들지 않고 옮기기 때문에 파일 안의 uid 가 유지되어 유닛 덱 등의 참조가 끊기지 않는다.
##
## 사용 순서: read_zip() 또는 load_export() → preview()로 확인 → apply().
## 에디터 메뉴(plugin.gd)와 테스트가 이 클래스를 같이 쓴다.

## 결과 파일을 저장할 최상위 폴더. 테스트에서는 user:// 아래 임시 폴더를 넣는다.
var root: String
## cards.json 을 파싱한 내용. { cards: [...], decks: [...], keywords: [...] }
var _data: Dictionary = {}
## zip 안의 그림 파일. "art/<파일 이름>" → 파일 내용(PackedByteArray)
var _art: Dictionary = {}


## root_dir: 결과를 저장할 폴더. 생략하면 res://cards.
func _init(root_dir: String = "res://cards") -> void:
	root = root_dir


## zip 을 거치지 않고 내용을 직접 넣는다 (테스트용으로도 쓴다).
## data: cards.json 과 같은 구조, art: "art/<파일 이름>" → 파일 내용.
func load_export(data: Dictionary, art: Dictionary = {}) -> void:
	_data = data
	_art = art


## 읽어 둔 cards.json 내용. 장비 가져오기(EquipmentImporter)가 같은 zip 내용을 넘겨받을 때 쓴다.
func get_data() -> Dictionary:
	return _data


## 읽어 둔 zip 그림들 ("art/<파일 이름>" → 내용). EquipmentImporter 에 넘긴다.
func get_art() -> Dictionary:
	return _art


## zip 파일을 읽어 가져올 준비를 한다.
## 성공하면 "", 실패하면 사람이 읽을 오류 문구를 돌려준다 (에디터 오류 창에 그대로 표시).
func read_zip(path: String) -> String:
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		return "zip 파일을 열 수 없어요: %s" % path
	var files := zip.get_files()

	# 카드 에디터 내보내기 zip 인지 확인: cards.json 이 반드시 있어야 한다.
	if not files.has("cards.json"):
		zip.close()
		return "cards.json 이 없어요. 카드 에디터의 '내보내기'로 받은 zip 인지 확인하세요."
	var parsed = JSON.parse_string(zip.read_file("cards.json").get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("cards"):
		zip.close()
		return "cards.json 형식이 올바르지 않아요."

	# art/ 폴더 안의 파일만 그림으로 모은다 (폴더 항목 자체는 제외).
	var art := {}
	for f in files:
		if f.begins_with("art/") and not f.ends_with("/"):
			art[f] = zip.read_file(f)
	zip.close()
	load_export(parsed, art)
	return ""


## 파일을 건드리지 않고, apply() 하면 무엇이 바뀌는지만 계산한다. 미리보기 창에 쓴다.
## 반환: { added: 새로 생길 카드 이름들, updated: 덮어쓸 카드 이름들,
##         removed: [{ name: 이름, has_effects: Godot 에서 붙인 효과가 있는지 }] }
func preview() -> Dictionary:
	var existing := _existing_cards(root.path_join("data"))
	var added := PackedStringArray()
	var updated := PackedStringArray()
	var incoming := {}  # 이번 zip 에 있는 카드 id 집합

	# zip 의 카드: 이미 파일이 있으면 갱신, 없으면 추가.
	for c in _list("cards"):
		var id := str(c.get("id", ""))
		incoming[id] = true
		var name := _text(c, "name", "ko")
		if existing.has(id):
			updated.append(name)
		else:
			added.append(name)

	# 파일은 있는데 zip 에 없는 카드 = 웹 에디터에서 지운 카드 → 삭제 대상.
	var removed := []
	for id in existing:
		if incoming.has(id):
			continue
		var card := _load(existing[id]) as CardData
		removed.append({
			"name": card.name_ko if card else id,
			"has_effects": card != null and _has_godot_parts(card),
		})
	return {"added": added, "updated": updated, "removed": removed}


## 실제로 파일을 만들고, 덮어쓰고, 지운다.
func apply() -> void:
	var used_art := {}  # 이번에 카드가 참조한 그림 경로 집합 (안 쓰는 그림 정리에 사용)
	_apply_cards(used_art)
	_apply_keywords()
	_remove_unused_art(used_art)


## 카드 .tres 를 만들거나 갱신하고, zip 에 없는 카드 파일은 지운다.
func _apply_cards(used_art: Dictionary) -> void:
	var existing := _existing_cards(root.path_join("data"))  # 카드 id → 현재 파일 경로
	var targets := _card_paths()  # 카드 id → 저장할 경로

	# 1. 옮겨야 하는 기존 파일은 먼저 전부 임시 이름으로 비켜 둔다.
	#    (A 의 새 이름이 B 의 옛 이름인 경우처럼 서로 자리를 바꿔도 덮어쓰지 않게)
	var moving := {}  # 카드 id → 임시 경로
	var held := {}  # 카드 id → 메모리에 이미 올라와 있던 리소스 (에디터가 열어 둔 카드 등)
	for id in targets:
		if existing.has(id) and existing[id] != targets[id]:
			# 에디터가 옛 경로로 들고 있는 객체는 나중에 그대로 옛 경로에 다시 저장되어 중복 파일이 생긴다.
			# 그래서 파일과 함께 이 객체의 경로도 새 경로로 옮긴다 (아래 2단계).
			if ResourceLoader.has_cached(existing[id]):
				held[id] = ResourceLoader.load(existing[id])
			var tmp: String = existing[id] + ".moving"
			DirAccess.rename_absolute(existing[id], tmp)
			moving[id] = tmp

	for c in _list("cards"):
		var id := str(c.get("id", ""))
		if not targets.has(id):
			continue
		var path: String = targets[id]
		var deck = c.get("deck")
		var deck_id := "" if deck == null else str(deck)

		# 2. 비켜 둔 파일을 새 경로로 옮긴다 (파일째 옮기므로 uid 유지).
		if moving.has(id):
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			DirAccess.rename_absolute(moving[id], path)
			if held.has(id):
				held[id].take_over_path(path)

		# 3. 기존 파일이 있으면 그걸 불러와서 고친다 → Godot 쪽 칸(effects 등)이 유지된다.
		var card: CardData = null
		if existing.has(id):
			card = _load(path) as CardData
		if card == null:
			card = CardData.new()
		_fill(card, c, used_art)
		card.id = id
		card.deck_id = deck_id

		# 4. 강화 단계: 같은 순번의 기존 강화 데이터를 재사용해서 효과를 유지한다.
		#    zip 의 강화 단계가 줄었으면 남는 단계는 버린다.
		var faces: Array = c.get("upgrades", [])
		var ups: Array[CardData] = []
		for i in faces.size():
			var up: CardData = card.upgrades[i] if i < card.upgrades.size() else CardData.new()
			_fill(up, faces[i], used_art)
			ups.append(up)
		card.upgrades = ups

		_save(card, path)
		existing.erase(id)

	# 여기까지 남은 파일 = zip 에 없는 카드 → 삭제. 비게 된 덱 폴더도 정리.
	for id in existing:
		_delete(existing[id])
	_remove_empty_dirs(root.path_join("data"))


## 카드 id → 저장할 경로 표를 만든다.
## 경로: data/<덱 폴더>/<카드 이름>.tres. 공용 카드는 common, 덱 목록에 없는 덱 id 는 id 를 폴더 이름으로.
## 같은 폴더에서 이름이 겹치면 뒤에 오는 카드에 "_<id>" 를 붙인다. 이름이 비면 id 를 쓴다.
func _card_paths() -> Dictionary:
	var folders := _deck_folders()  # 덱 id → 폴더 이름
	var out := {}
	var taken := {}  # 이미 쓴 경로
	for c in _list("cards"):
		var id := str(c.get("id", ""))
		if id.is_empty():
			continue
		var deck = c.get("deck")
		var deck_id := "" if deck == null else str(deck)
		var folder := "common" if deck_id.is_empty() else folders.get(deck_id, _safe_name(deck_id, deck_id))
		var file := _safe_name(_text(c, "name", "ko"), id)
		var path := root.path_join("data/%s/%s.tres" % [folder, file])
		if taken.has(path):
			path = root.path_join("data/%s/%s_%s.tres" % [folder, file, id])
		taken[path] = true
		out[id] = path
	return out


## 덱 id → 폴더 이름(덱의 한국어 이름) 표를 만든다.
## 이름이 겹치면 뒤에 오는 덱에 "_<id>" 를 붙여 폴더가 섞이지 않게 한다.
## "common" 은 공용 카드 폴더라 덱 이름으로 쓰지 않는다.
func _deck_folders() -> Dictionary:
	var out := {}
	var taken := {"common": true}
	for d in _list("decks"):
		var id := str(d.get("id", ""))
		if id.is_empty():
			continue
		var folder := _safe_name(_text(d, "name", "ko"), id)
		if taken.has(folder):
			folder = "%s_%s" % [folder, id]
		taken[folder] = true
		out[id] = folder
	return out


## 폴더·파일 이름으로 못 쓰는 문자(\ / : * ? " < > |)를 _ 로 바꾼다.
## Windows 는 끝의 점·공백을 허용하지 않아 지운다. 결과가 비면 fallback 을 쓴다.
func _safe_name(name: String, fallback: String) -> String:
	var s := name.strip_edges()
	for ch in ["\\", "/", ":", "*", "?", "\"", "<", ">", "|"]:
		s = s.replace(ch, "_")
	s = s.rstrip(". ")
	return s if not s.is_empty() else fallback


## dir_path 아래의 빈 폴더를 안쪽부터 지운다 (dir_path 자신은 남긴다).
func _remove_empty_dirs(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		var sub_path := dir_path.path_join(sub)
		_remove_empty_dirs(sub_path)  # 안쪽 폴더부터 비워야 바깥 폴더가 빈 폴더가 된다
		var sub_dir := DirAccess.open(sub_path)
		if sub_dir and sub_dir.get_files().is_empty() and sub_dir.get_directories().is_empty():
			DirAccess.remove_absolute(sub_path)


## 키워드 .tres 를 만들거나 갱신하고, zip 에 없는 키워드 파일은 지운다.
func _apply_keywords() -> void:
	var existing := _existing_files(root.path_join("keywords"))
	for k in _list("keywords"):
		var id := str(k.get("id", ""))
		if id.is_empty():
			continue
		var path := root.path_join("keywords/%s.tres" % id)
		var kw: KeywordData = _load(path) as KeywordData if existing.has(id) else null
		if kw == null:
			kw = KeywordData.new()
		kw.id = id
		kw.name_ko = _text(k, "name", "ko")
		kw.name_en = _text(k, "name", "en")
		kw.description_ko = _text(k, "description", "ko")
		kw.description_en = _text(k, "description", "en")
		_save(kw, path)
		existing.erase(id)
	for id in existing:
		_delete(existing[id])


## 카드 한 면(기본 또는 강화 단계)의 웹 에디터 담당 칸을 채운다.
## costs / conditions / effects 는 건드리지 않는다.
## face 의 키 이름은 웹 에디터 내보내기 형식(camelCase: attackType 등)을 따른다.
func _fill(card: CardData, face: Dictionary, used_art: Dictionary) -> void:
	card.name_ko = _text(face, "name", "ko")
	card.name_en = _text(face, "name", "en")
	card.description_ko = _text(face, "description", "ko")
	card.description_en = _text(face, "description", "en")
	# JSON 숫자는 float 로 읽히므로 int 로 바꾼다.
	card.sp = int(face.get("sp", 0))
	card.cost = int(face.get("cost", 0))
	card.category = str(face.get("category", "attack"))
	card.attack_type = str(face.get("attackType", "melee"))
	# 범위: [[x, y], ...] → Vector2i 배열 (기준 칸 기준 오프셋, −2..2)
	var area: Array[Vector2i] = []
	for cell in face.get("area", []):
		area.append(Vector2i(int(cell[0]), int(cell[1])))
	card.area = area
	card.keywords = PackedStringArray(face.get("keywords", []))
	card.art = _copy_art(face.get("art"), used_art)


## 그림을 root/art/ 로 복사하고 그 경로를 돌려준다.
## 그림이 없거나 zip 에 파일이 없으면 "" (카드는 그림 없이 표시된다).
## 같은 그림을 여러 카드가 써도 한 번만 쓴다.
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


## art 폴더에서 이번 가져오기에 쓰이지 않은 그림을 지운다.
## .import 파일은 _delete 가 그림과 함께 지우므로 여기선 건너뛴다.
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
			_delete(path)


## 카드(또는 그 강화 단계)에 Godot 에서 붙인 비용·조건·효과가 하나라도 있는지.
## 삭제 미리보기에서 ⚠ 표시에 쓴다.
func _has_godot_parts(card: CardData) -> bool:
	for c in [card] + card.upgrades:
		if not (c.costs.is_empty() and c.conditions.is_empty() and c.effects.is_empty()):
			return true
	return false


## 폴더 아래 모든 카드 .tres 를 재귀로 찾아 { 카드 id: 경로 } 로 돌려준다.
## id 는 파일 안의 CardData.id 를 쓴다 (파일 이름은 카드 이름이라 바뀔 수 있음).
## id 가 비어 있으면 파일 이름을 id 로 본다.
func _existing_cards(dir_path: String) -> Dictionary:
	var out := {}
	for path in _tres_paths(dir_path):
		var card := _load(path) as CardData
		var id: String = card.id if card and not card.id.is_empty() else path.get_file().get_basename()
		out[id] = path
	return out


## 폴더 아래 모든 .tres 경로를 재귀로 모은다.
## (카드 이름은 덱마다 겹칠 수 있어서 파일 이름이 아니라 경로 목록으로 돌려준다)
func _tres_paths(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub in dir.get_directories():
		out.append_array(_tres_paths(dir_path.path_join(sub)))
	for f in dir.get_files():
		if f.get_extension() == "tres":
			out.append(dir_path.path_join(f))
	return out


## 폴더 아래 모든 .tres 를 재귀로 찾아 { 파일 이름(확장자 뺌): 경로 } 로 돌려준다.
## 키워드는 파일 이름 = 키워드 id. 카드는 _existing_cards 를 쓴다.
func _existing_files(dir_path: String) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub in dir.get_directories():
		out.merge(_existing_files(dir_path.path_join(sub)))
	for f in dir.get_files():
		if f.get_extension() == "tres":
			out[f.get_basename()] = dir_path.path_join(f)
	return out


## cards.json 의 배열 항목(cards / decks / keywords). 없거나 형식이 틀리면 빈 배열.
func _list(key: String) -> Array:
	var v = _data.get(key, [])
	return v if typeof(v) == TYPE_ARRAY else []


## { key: { ko: ..., en: ... } } 형태에서 한 언어의 글자를 꺼낸다. 없으면 "".
func _text(d: Dictionary, key: String, lang: String) -> String:
	var v = d.get(key, {})
	return str(v.get(lang, "")) if typeof(v) == TYPE_DICTIONARY else ""


## 리소스를 불러온다. CACHE_MODE_REPLACE: 에디터에 열려 있는 같은 리소스도
## 디스크 내용으로 갱신해서, 인스펙터와 파일이 어긋나지 않게 한다.
func _load(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)


## 폴더를 만들고 리소스를 저장한다. take_over_path 로 리소스의 경로를 새 위치로 옮긴다.
func _save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	res.take_over_path(path)
	ResourceSaver.save(res, path)


## 파일을 지운다. 그림이면 Godot 이 만든 .import 파일도 같이 지운다.
func _delete(path: String) -> void:
	DirAccess.remove_absolute(path)
	if FileAccess.file_exists(path + ".import"):
		DirAccess.remove_absolute(path + ".import")
