@tool
class_name CardExporter
extends RefCounted
## Godot 카드 데이터를 웹 카드 에디터가 읽는 zip 으로 내보내는 로직. CardImporter 의 반대 방향.
##
## zip 구성은 웹 에디터의 내보내기와 같다: cards.json(카드·덱·키워드 목록) + art/(카드 그림).
## 웹 에디터의 "가져오기" 버튼과 Godot 의 "카드 가져오기" 양쪽에서 그대로 읽을 수 있다.
##
## 내보내는 칸은 웹 에디터가 담당하는 칸뿐이다. costs / conditions / effects / KeywordData.rules 처럼
## 웹 에디터에 없는 Godot 쪽 칸은 넣지 않는다 (.tres 에 그대로 남는다).
##
## 사용 순서: write_zip() 하나면 된다. 내용만 필요하면 build().
## 에디터 메뉴(plugin.gd)와 테스트가 이 클래스를 같이 쓴다.

## 읽어 올 최상위 폴더. 테스트에서는 user:// 아래 임시 폴더를 넣는다.
var root: String
## 카드가 가리키지만 파일이 없어 빠진 그림 경로. build() 때마다 새로 채운다.
var missing_art := PackedStringArray()
## zip 안의 그림 경로("art/<파일 이름>") → 실제 파일 경로
var _art_sources: Dictionary = {}
## 실제 파일 경로 → zip 안의 그림 경로 (같은 그림을 여러 카드가 쓰면 한 번만 넣는다)
var _art_paths: Dictionary = {}


## root_dir: 카드 데이터 폴더. 생략하면 res://cards.
func _init(root_dir: String = "res://cards") -> void:
	root = root_dir


## cards.json 과 같은 구조의 내용을 만든다. { keywords: [...], decks: [...], cards: [...] }
func build() -> Dictionary:
	missing_art = PackedStringArray()
	_art_sources = {}
	_art_paths = {}
	var cards := []
	var decks := []
	var seen_decks := {}  # 이미 넣은 덱 id 집합

	for path in CardImporter.new(root)._tres_paths(root.path_join("data")):
		var card := _load(path) as CardData
		if card == null:
			continue
		# 덱 이름은 CardData 에 없고 폴더 이름으로만 남아 있다. 영어 이름은 복원할 수 없어 빈 값이다.
		if not card.deck_id.is_empty() and not seen_decks.has(card.deck_id):
			seen_decks[card.deck_id] = true
			decks.append({"id": card.deck_id, "name": {"ko": _deck_name(path, card.deck_id), "en": ""}})
		cards.append(_card_entry(card, path))

	return {"keywords": _keyword_entries(), "decks": decks, "cards": cards}


## zip 파일을 만든다. 성공하면 "", 실패하면 사람이 읽을 오류 문구를 돌려준다 (에디터 오류 창에 그대로 표시).
## 빠진 그림이 있어도 실패가 아니다. 호출한 쪽에서 missing_art 로 확인한다.
func write_zip(path: String) -> String:
	var json := JSON.stringify(build(), "  ")
	var zip := ZIPPacker.new()
	if zip.open(path) != OK:
		return "zip 파일을 만들 수 없어요: %s" % path
	var ok := _add_file(zip, "cards.json", json.to_utf8_buffer())
	for art_path in _art_sources:
		ok = ok and _add_file(zip, art_path, FileAccess.get_file_as_bytes(_art_sources[art_path]))
	zip.close()
	return "" if ok else "zip 파일을 쓰지 못했어요: %s" % path


## zip 에 파일 하나를 넣는다. 성공 여부를 돌려준다.
func _add_file(zip: ZIPPacker, name: String, bytes: PackedByteArray) -> bool:
	if zip.start_file(name) != OK or zip.write_file(bytes) != OK:
		return false
	return zip.close_file() == OK


## 카드 한 장의 항목. 면 칸 + id·덱·강화 단계.
func _card_entry(card: CardData, path: String) -> Dictionary:
	var entry := _face_entry(card)
	# id 가 비어 있는 예전 파일은 파일 이름을 id 로 본다 (CardImporter 와 같은 규칙)
	entry["id"] = card.id if not card.id.is_empty() else path.get_file().get_basename()
	entry["deck"] = null if card.deck_id.is_empty() else card.deck_id
	var ups := []
	for up in card.upgrades:
		ups.append(_face_entry(up))
	entry["upgrades"] = ups
	return entry


## 카드 한 면(기본 또는 강화 단계)의 웹 에디터 칸. 키 이름은 웹 에디터 형식(camelCase)을 따른다.
func _face_entry(card: CardData) -> Dictionary:
	var area := []
	for cell in card.area:
		area.append([cell.x, cell.y])
	return {
		"name": {"ko": card.name_ko, "en": card.name_en},
		"description": {"ko": card.description_ko, "en": card.description_en},
		"sp": card.sp,
		"cost": card.cost,
		"category": card.category,
		"attackType": card.attack_type,
		"area": area,
		"keywords": Array(card.keywords),
		"art": _art_entry(card.art),
	}


## 그림을 zip 목록에 넣고 zip 안의 경로를 돌려준다. 그림이 없으면 null.
## 다른 폴더의 같은 파일 이름은 뒤에 _2, _3 을 붙여 서로 덮어쓰지 않게 한다.
func _art_entry(src: String):
	if src.is_empty():
		return null
	if _art_paths.has(src):
		return _art_paths[src]
	if not FileAccess.file_exists(src):
		if not missing_art.has(src):
			missing_art.append(src)
		return null
	var dest := "art/%s" % src.get_file()
	var n := 2
	while _art_sources.has(dest):
		dest = "art/%s_%d.%s" % [src.get_file().get_basename(), n, src.get_extension()]
		n += 1
	_art_sources[dest] = src
	_art_paths[src] = dest
	return dest


## 키워드 항목 목록. id 가 비어 있으면 파일 이름(= 키워드 id)을 쓴다.
func _keyword_entries() -> Array:
	var out := []
	for path in CardImporter.new(root)._tres_paths(root.path_join("keywords")):
		var kw := _load(path) as KeywordData
		if kw == null:
			continue
		out.append({
			"id": kw.id if not kw.id.is_empty() else path.get_file().get_basename(),
			"name": {"ko": kw.name_ko, "en": kw.name_en},
			"description": {"ko": kw.description_ko, "en": kw.description_en},
		})
	return out


## 카드가 있는 폴더 이름에서 덱 이름을 되살린다.
## 이름이 겹친 덱의 폴더는 "<이름>_<id>" 이므로 뒤의 id 를 뗀다 (CardImporter._deck_folders 참고).
func _deck_name(card_path: String, deck_id: String) -> String:
	var folder := card_path.get_base_dir().get_file()
	var suffix := "_" + deck_id
	return folder.trim_suffix(suffix) if folder.length() > suffix.length() else folder


## 리소스를 디스크에서 읽는다. CACHE_MODE_IGNORE: 에디터가 열어 둔 리소스를 건드리지 않고,
## 저장된 내용만 내보낸다.
func _load(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
