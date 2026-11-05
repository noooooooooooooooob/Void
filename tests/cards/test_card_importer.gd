extends GutTest

var root: String

func before_each():
	root = "user://test_cards_%d" % Time.get_ticks_usec()

func after_each():
	_remove_tree(root)

func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_remove_tree(path.path_join(sub))
	for f in dir.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)

func _face(name_ko: String, sp := 1, art = null) -> Dictionary:
	return {
		"name": {"ko": name_ko, "en": name_ko + "_en"},
		"description": {"ko": "설명", "en": "desc"},
		"sp": sp, "cost": 2, "category": "skill", "attackType": "ranged",
		"area": [[0, 0], [1, 0]], "keywords": ["k1"], "art": art,
	}

func _card(id: String, name_ko: String, deck = null, sp := 1, upgrades := [], art = null) -> Dictionary:
	var c := _face(name_ko, sp, art)
	c["id"] = id
	c["deck"] = deck
	c["upgrades"] = upgrades
	return c

func _export(cards: Array, keywords := [], decks := []) -> Dictionary:
	return {"keywords": keywords, "decks": decks, "cards": cards}

func _import(data: Dictionary, art := {}) -> CardImporter:
	var imp := CardImporter.new(root)
	imp.load_export(data, art)
	imp.apply()
	return imp

func _load(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)

func _add_effect_and_save(path: String) -> void:
	var card: CardData = _load(path)
	card.effects.append(CardEffect.new())
	ResourceSaver.save(card, path)

# 공용 카드 파일 경로. 파일 이름 = 카드 이름
func _common(file_name: String) -> String:
	return root.path_join("data/common/%s.tres" % file_name)


func test_new_common_card_created_with_fields():
	_import(_export([_card("c1", "베기", null, 2)]))
	var card: CardData = _load(_common("베기"))
	assert_not_null(card)
	assert_eq(card.id, "c1")
	assert_eq(card.deck_id, "")
	assert_eq(card.name_ko, "베기")
	assert_eq(card.name_en, "베기_en")
	assert_eq(card.description_ko, "설명")
	assert_eq(card.description_en, "desc")
	assert_eq(card.sp, 2)
	assert_eq(card.cost, 2)
	assert_eq(card.category, "skill")
	assert_eq(card.attack_type, "ranged")
	assert_eq(card.area, [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i])
	assert_eq(card.keywords, PackedStringArray(["k1"]))

func test_deck_card_goes_to_deck_folder():
	_import(_export([_card("c1", "베기", "deckA")]))
	var card: CardData = _load(root.path_join("data/deckA/베기.tres"))
	assert_not_null(card)
	assert_eq(card.deck_id, "deckA")

func _deck(id: String, name_ko: String) -> Dictionary:
	return {"id": id, "name": {"ko": name_ko, "en": ""}}

func test_deck_folder_uses_deck_name():
	_import(_export([_card("c1", "베기", "d1")], [], [_deck("d1", "홍연")]))
	assert_true(FileAccess.file_exists(root.path_join("data/홍연/베기.tres")))

func test_deck_rename_moves_cards_and_removes_empty_folder():
	_import(_export([_card("c1", "베기", "d1")], [], [_deck("d1", "홍연")]))
	_add_effect_and_save(root.path_join("data/홍연/베기.tres"))
	_import(_export([_card("c1", "베기", "d1")], [], [_deck("d1", "홍연 덱")]))
	assert_false(DirAccess.dir_exists_absolute(root.path_join("data/홍연")))
	var card: CardData = _load(root.path_join("data/홍연 덱/베기.tres"))
	assert_eq(card.effects.size(), 1)

func test_deck_name_unsafe_characters_replaced():
	_import(_export([_card("c1", "베기", "d1")], [], [_deck("d1", "a/b:c?")]))
	assert_true(FileAccess.file_exists(root.path_join("data/a_b_c_/베기.tres")))

func test_duplicate_deck_names_get_id_suffix():
	_import(_export([_card("c1", "베기", "d1"), _card("c2", "막기", "d2")], [], [_deck("d1", "같은"), _deck("d2", "같은")]))
	assert_true(FileAccess.file_exists(root.path_join("data/같은/베기.tres")))
	assert_true(FileAccess.file_exists(root.path_join("data/같은_d2/막기.tres")))

func test_reimport_keeps_effects():
	_import(_export([_card("c1", "베기")]))
	_add_effect_and_save(_common("베기"))
	_import(_export([_card("c1", "강타", null, 3)]))
	assert_false(FileAccess.file_exists(_common("베기")))
	var card: CardData = _load(_common("강타"))
	assert_eq(card.name_ko, "강타")
	assert_eq(card.sp, 3)
	assert_eq(card.effects.size(), 1)

func test_upgrade_effects_kept_and_extra_upgrades_dropped():
	_import(_export([_card("c1", "베기", null, 1, [_face("베기+", 1), _face("베기++", 1)])]))
	var card: CardData = _load(_common("베기"))
	card.upgrades[0].effects.append(CardEffect.new())
	ResourceSaver.save(card, _common("베기"))
	_import(_export([_card("c1", "베기", null, 1, [_face("베기+", 0)])]))
	card = _load(_common("베기"))
	assert_eq(card.upgrades.size(), 1)
	assert_eq(card.upgrades[0].sp, 0)
	assert_eq(card.upgrades[0].effects.size(), 1)

func test_removed_card_deleted():
	_import(_export([_card("c1", "베기"), _card("c2", "막기")]))
	_import(_export([_card("c2", "막기")]))
	assert_false(FileAccess.file_exists(_common("베기")))
	assert_true(FileAccess.file_exists(_common("막기")))

func test_card_moved_between_decks_keeps_effects():
	_import(_export([_card("c1", "베기")]))
	_add_effect_and_save(_common("베기"))
	_import(_export([_card("c1", "베기", "deckA")]))
	assert_false(FileAccess.file_exists(_common("베기")))
	var card: CardData = _load(root.path_join("data/deckA/베기.tres"))
	assert_eq(card.effects.size(), 1)

func test_preview_lists_changes_without_writing():
	_import(_export([_card("c1", "베기"), _card("c2", "막기")]))
	_add_effect_and_save(_common("베기"))
	var imp := CardImporter.new(root)
	imp.load_export(_export([_card("c2", "막기!"), _card("c3", "찌르기")]))
	var p := imp.preview()
	assert_eq(p.added, PackedStringArray(["찌르기"]))
	assert_eq(p.updated, PackedStringArray(["막기!"]))
	assert_eq(p.removed.size(), 1)
	assert_eq(p.removed[0].name, "베기")
	assert_true(p.removed[0].has_effects)
	assert_true(FileAccess.file_exists(_common("베기")))
	assert_false(FileAccess.file_exists(_common("찌르기")))

func test_art_copied_and_linked():
	var bytes := PackedByteArray([1, 2, 3, 4])
	_import(_export([_card("c1", "베기", null, 1, [], "art/a1.png")]), {"art/a1.png": bytes})
	var art_path := root.path_join("art/a1.png")
	assert_eq(FileAccess.get_file_as_bytes(art_path), bytes)
	var card: CardData = _load(_common("베기"))
	assert_eq(card.art, art_path)

func test_missing_art_leaves_card_without_art():
	_import(_export([_card("c1", "베기", null, 1, [], "art/missing.png")]))
	var card: CardData = _load(_common("베기"))
	assert_eq(card.art, "")

func test_unused_art_removed():
	var bytes := PackedByteArray([9])
	_import(_export([_card("c1", "베기", null, 1, [], "art/a1.png")]), {"art/a1.png": bytes})
	_import(_export([_card("c1", "베기")]))
	assert_false(FileAccess.file_exists(root.path_join("art/a1.png")))

func test_keywords_written_and_removed():
	var kw := {"id": "k1", "name": {"ko": "출혈", "en": "Bleed"}, "description": {"ko": "아픔", "en": "hurts"}}
	_import(_export([], [kw]))
	var data: KeywordData = _load(root.path_join("keywords/k1.tres"))
	assert_eq(data.name_ko, "출혈")
	assert_eq(data.description_en, "hurts")
	_import(_export([], []))
	assert_false(FileAccess.file_exists(root.path_join("keywords/k1.tres")))

func test_reimport_keeps_keyword_godot_fields():
	var kw := {"id": "k1", "name": {"ko": "소멸", "en": "Exhaust"}, "description": {"ko": "사용시 제외", "en": ""}}
	_import(_export([], [kw]))
	var path := root.path_join("keywords/k1.tres")
	var data: KeywordData = _load(path)
	data.rules.assign([ExileAfterUseRule.new()])
	ResourceSaver.save(data, path)
	kw["description"] = {"ko": "사용하면 이번 전투에서 제외", "en": ""}
	_import(_export([], [kw]))
	data = _load(path)
	assert_eq(data.rules.size(), 1)
	assert_true(data.rules[0] is ExileAfterUseRule)
	assert_eq(data.description_ko, "사용하면 이번 전투에서 제외")

func test_read_zip():
	var zip_path := root.path_join("in.zip")
	DirAccess.make_dir_recursive_absolute(root)
	var zp := ZIPPacker.new()
	zp.open(zip_path)
	zp.start_file("cards.json")
	zp.write_file(JSON.stringify(_export([_card("c1", "베기", null, 1, [], "art/a1.png")])).to_utf8_buffer())
	zp.close_file()
	zp.start_file("art/a1.png")
	zp.write_file(PackedByteArray([7, 7]))
	zp.close_file()
	zp.close()
	var imp := CardImporter.new(root)
	assert_eq(imp.read_zip(zip_path), "")
	assert_eq(imp.preview().added, PackedStringArray(["베기"]))
	imp.apply()
	assert_eq(FileAccess.get_file_as_bytes(root.path_join("art/a1.png")), PackedByteArray([7, 7]))

func test_read_zip_without_cards_json_fails():
	var zip_path := root.path_join("bad.zip")
	DirAccess.make_dir_recursive_absolute(root)
	var zp := ZIPPacker.new()
	zp.open(zip_path)
	zp.start_file("other.txt")
	zp.write_file("x".to_utf8_buffer())
	zp.close_file()
	zp.close()
	assert_ne(CardImporter.new(root).read_zip(zip_path), "")

func test_same_name_in_same_folder_gets_id_suffix():
	_import(_export([_card("c1", "베기"), _card("c2", "베기")]))
	assert_true(FileAccess.file_exists(_common("베기")))
	assert_true(FileAccess.file_exists(_common("베기_c2")))

func test_unsafe_card_name_replaced():
	_import(_export([_card("c1", "베기/찌르기?")]))
	assert_true(FileAccess.file_exists(_common("베기_찌르기_")))

# 이름이 바뀌면 파일을 새로 만들지 않고 옮긴다 → 머리줄(uid 포함)이 그대로 남아 다른 리소스의 참조가 안 끊긴다
func _header(path: String) -> String:
	return FileAccess.get_file_as_string(path).get_slice("
", 0)

func test_renamed_card_file_is_moved_not_recreated():
	_import(_export([_card("c1", "베기")]))
	var before := _header(_common("베기"))
	_import(_export([_card("c1", "강타")]))
	assert_eq(_header(_common("강타")), before)

func test_legacy_id_named_file_renamed_to_card_name():
	# 예전 방식(파일 이름 = id)으로 저장된 카드도 다시 가져오면 이름 파일로 바뀐다
	_import(_export([_card("c1", "베기")]))
	DirAccess.rename_absolute(_common("베기"), _common("c1"))
	_add_effect_and_save(_common("c1"))
	_import(_export([_card("c1", "베기")]))
	assert_false(FileAccess.file_exists(_common("c1")))
	assert_eq((_load(_common("베기")) as CardData).effects.size(), 1)

func test_cached_resource_follows_renamed_file():
	# 에디터처럼 카드를 메모리에 들고 있는 상태에서 이름이 바뀌어도, 그 객체를 저장하면 새 경로로 가야 한다
	_import(_export([_card("c1", "베기")]))
	var held: CardData = ResourceLoader.load(_common("베기"))
	_import(_export([_card("c1", "강타")]))
	assert_eq(held.resource_path, _common("강타"))
	ResourceSaver.save(held)
	assert_false(FileAccess.file_exists(_common("베기")))
