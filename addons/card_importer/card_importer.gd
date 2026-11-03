@tool
class_name CardImporter
extends RefCounted
## 웹 카드 에디터 내보내기(zip: cards.json + art/)를 CardData / KeywordData .tres 로 만든다.
## 다시 가져오면 에디터가 담당하는 칸만 덮어쓰고 costs / conditions / effects 는 유지한다.
## 에디터에서 지운 카드·키워드와 더 이상 쓰지 않는 그림은 지운다.

var root: String
var _data: Dictionary = {}
var _art: Dictionary = {}  # "art/<file>" -> PackedByteArray


func _init(root_dir: String = "res://cards") -> void:
	root = root_dir


func load_export(data: Dictionary, art: Dictionary = {}) -> void:
	_data = data
	_art = art


## 성공하면 "", 실패하면 사람이 읽을 오류 문구.
func read_zip(path: String) -> String:
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		return "zip 파일을 열 수 없어요: %s" % path
	var files := zip.get_files()
	if not files.has("cards.json"):
		zip.close()
		return "cards.json 이 없어요. 카드 에디터의 '내보내기'로 받은 zip 인지 확인하세요."
	var parsed = JSON.parse_string(zip.read_file("cards.json").get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("cards"):
		zip.close()
		return "cards.json 형식이 올바르지 않아요."
	var art := {}
	for f in files:
		if f.begins_with("art/") and not f.ends_with("/"):
			art[f] = zip.read_file(f)
	zip.close()
	load_export(parsed, art)
	return ""


## 파일을 건드리지 않고 바뀔 내용만 계산한다.
## { added: 이름들, updated: 이름들, removed: [{ name, has_effects }] }
func preview() -> Dictionary:
	var existing := _existing_files(root.path_join("data"))
	var added := PackedStringArray()
	var updated := PackedStringArray()
	var incoming := {}
	for c in _list("cards"):
		var id := str(c.get("id", ""))
		incoming[id] = true
		var name := _text(c, "name", "ko")
		if existing.has(id):
			updated.append(name)
		else:
			added.append(name)
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


func apply() -> void:
	var used_art := {}
	_apply_cards(used_art)
	_apply_keywords()
	_remove_unused_art(used_art)


func _apply_cards(used_art: Dictionary) -> void:
	var existing := _existing_files(root.path_join("data"))
	var folders := _deck_folders()
	for c in _list("cards"):
		var id := str(c.get("id", ""))
		if id.is_empty():
			continue
		var deck = c.get("deck")
		var deck_id := "" if deck == null else str(deck)
		var folder := "common" if deck_id.is_empty() else folders.get(deck_id, _safe_name(deck_id, deck_id))
		var path := root.path_join("data/%s/%s.tres" % [folder, id])
		var card: CardData = null
		if existing.has(id):
			card = _load(existing[id]) as CardData
		if card == null:
			card = CardData.new()
		_fill(card, c, used_art)
		card.id = id
		card.deck_id = deck_id
		var faces: Array = c.get("upgrades", [])
		var ups: Array[CardData] = []
		for i in faces.size():
			var up: CardData = card.upgrades[i] if i < card.upgrades.size() else CardData.new()
			_fill(up, faces[i], used_art)
			ups.append(up)
		card.upgrades = ups
		_save(card, path)
		if existing.has(id) and existing[id] != path:
			_delete(existing[id])
		existing.erase(id)
	for id in existing:
		_delete(existing[id])
	_remove_empty_dirs(root.path_join("data"))


## 덱 id → 폴더 이름(덱 한국어 이름). 이름이 겹치면 뒤에 오는 덱에 _<id> 를 붙인다.
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


func _safe_name(name: String, fallback: String) -> String:
	var s := name.strip_edges()
	for ch in ["\\", "/", ":", "*", "?", "\"", "<", ">", "|"]:
		s = s.replace(ch, "_")
	s = s.rstrip(". ")
	return s if not s.is_empty() else fallback


func _remove_empty_dirs(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		var sub_path := dir_path.path_join(sub)
		_remove_empty_dirs(sub_path)
		var sub_dir := DirAccess.open(sub_path)
		if sub_dir and sub_dir.get_files().is_empty() and sub_dir.get_directories().is_empty():
			DirAccess.remove_absolute(sub_path)


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


func _fill(card: CardData, face: Dictionary, used_art: Dictionary) -> void:
	card.name_ko = _text(face, "name", "ko")
	card.name_en = _text(face, "name", "en")
	card.description_ko = _text(face, "description", "ko")
	card.description_en = _text(face, "description", "en")
	card.sp = int(face.get("sp", 0))
	card.cost = int(face.get("cost", 0))
	card.category = str(face.get("category", "attack"))
	card.attack_type = str(face.get("attackType", "melee"))
	var area: Array[Vector2i] = []
	for cell in face.get("area", []):
		area.append(Vector2i(int(cell[0]), int(cell[1])))
	card.area = area
	card.keywords = PackedStringArray(face.get("keywords", []))
	card.art = _copy_art(face.get("art"), used_art)


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


func _has_godot_parts(card: CardData) -> bool:
	for c in [card] + card.upgrades:
		if not (c.costs.is_empty() and c.conditions.is_empty() and c.effects.is_empty()):
			return true
	return false


## 폴더 아래 모든 .tres 를 재귀로 찾아 { 파일 이름(id): 경로 }.
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


func _list(key: String) -> Array:
	var v = _data.get(key, [])
	return v if typeof(v) == TYPE_ARRAY else []


func _text(d: Dictionary, key: String, lang: String) -> String:
	var v = d.get(key, {})
	return str(v.get(lang, "")) if typeof(v) == TYPE_DICTIONARY else ""


func _load(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)


func _save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	res.take_over_path(path)
	ResourceSaver.save(res, path)


func _delete(path: String) -> void:
	DirAccess.remove_absolute(path)
	if FileAccess.file_exists(path + ".import"):
		DirAccess.remove_absolute(path + ".import")
