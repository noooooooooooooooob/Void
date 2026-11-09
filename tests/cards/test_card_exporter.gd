extends GutTest

var root: String
var out_root: String

func before_each():
	var stamp := Time.get_ticks_usec()
	root = "user://test_export_%d" % stamp
	out_root = "user://test_export_out_%d" % stamp

func after_each():
	_remove_tree(root)
	_remove_tree(out_root)

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

func _card(id: String, name_ko: String, deck = null, upgrades := [], art = null) -> Dictionary:
	var c := _face(name_ko, 1, art)
	c["id"] = id
	c["deck"] = deck
	c["upgrades"] = upgrades
	return c

func _keyword() -> Dictionary:
	return {"id": "k1", "name": {"ko": "출혈", "en": "Bleed"}, "description": {"ko": "아픔", "en": "hurts"}}

func _deck(id: String, name_ko: String) -> Dictionary:
	return {"id": id, "name": {"ko": name_ko, "en": ""}}

func _import(data: Dictionary, art := {}, into := "") -> void:
	var imp := CardImporter.new(root if into.is_empty() else into)
	imp.load_export(data, art)
	imp.apply()

func _load(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)

func _by_id(items: Array, id: String) -> Dictionary:
	for it in items:
		if it.id == id:
			return it
	return {}


func test_card_fields_match_web_export_format():
	_import({"keywords": [_keyword()], "decks": [], "cards": [_card("c1", "베기")]})
	var card := _by_id(CardExporter.new(root).build().cards, "c1")
	assert_eq(card.deck, null)
	assert_eq(card.name, {"ko": "베기", "en": "베기_en"})
	assert_eq(card.description, {"ko": "설명", "en": "desc"})
	assert_eq(card.sp, 1)
	assert_eq(card.cost, 2)
	assert_eq(card.category, "skill")
	assert_eq(card.attackType, "ranged")
	assert_eq(card.area, [[0, 0], [1, 0]])
	assert_eq(card.keywords, ["k1"])
	assert_eq(card.art, null)
	assert_eq(card.upgrades, [])

func test_godot_parts_are_not_exported():
	_import({"keywords": [], "decks": [], "cards": [_card("c1", "베기")]})
	var card := _by_id(CardExporter.new(root).build().cards, "c1")
	assert_false(card.has("effects"))
	assert_false(card.has("costs"))
	assert_false(card.has("conditions"))

func test_upgrades_exported_as_faces():
	_import({"keywords": [], "decks": [], "cards": [_card("c1", "베기", null, [_face("베기+", 3)])]})
	var card := _by_id(CardExporter.new(root).build().cards, "c1")
	assert_eq(card.upgrades.size(), 1)
	assert_eq(card.upgrades[0].name.ko, "베기+")
	assert_eq(card.upgrades[0].sp, 3)
	assert_false(card.upgrades[0].has("id"))

func test_keywords_exported():
	_import({"keywords": [_keyword()], "decks": [], "cards": []})
	var data := CardExporter.new(root).build()
	assert_eq(data.keywords, [_keyword()])

func test_deck_name_comes_from_folder():
	_import({"keywords": [], "decks": [_deck("d1", "홍연")], "cards": [_card("c1", "베기", "d1"), _card("c2", "막기", "d1")]})
	var data := CardExporter.new(root).build()
	assert_eq(data.decks, [_deck("d1", "홍연")])
	assert_eq(_by_id(data.cards, "c1").deck, "d1")

func test_duplicate_deck_folder_suffix_removed_from_name():
	_import({"keywords": [], "decks": [_deck("d1", "같은"), _deck("d2", "같은")], "cards": [_card("c1", "베기", "d1"), _card("c2", "막기", "d2")]})
	var data := CardExporter.new(root).build()
	assert_eq(_by_id(data.decks, "d2").name.ko, "같은")

func test_empty_card_id_uses_file_name():
	_import({"keywords": [], "decks": [], "cards": [_card("c1", "베기")]})
	var path := root.path_join("data/common/베기.tres")
	var card: CardData = _load(path)
	card.id = ""
	ResourceSaver.save(card, path)
	assert_eq(CardExporter.new(root).build().cards[0].id, "베기")

func test_art_listed_and_missing_art_reported():
	var bytes := PackedByteArray([1, 2, 3])
	_import({"keywords": [], "decks": [], "cards": [_card("c1", "베기", null, [], "art/a1.png"), _card("c2", "막기", null, [], "art/a1.png")]}, {"art/a1.png": bytes})
	var path := root.path_join("data/common/막기.tres")
	var card: CardData = _load(path)
	card.art = root.path_join("art/none.png")
	ResourceSaver.save(card, path)
	var exp := CardExporter.new(root)
	var data := exp.build()
	assert_eq(_by_id(data.cards, "c1").art, "art/a1.png")
	assert_eq(_by_id(data.cards, "c2").art, null)
	assert_eq(exp.missing_art, PackedStringArray([root.path_join("art/none.png")]))

func test_same_file_name_from_other_folders_does_not_collide():
	_import({"keywords": [], "decks": [], "cards": [_card("c1", "베기"), _card("c2", "막기")]})
	DirAccess.make_dir_recursive_absolute(root.path_join("x"))
	DirAccess.make_dir_recursive_absolute(root.path_join("y"))
	for pair in [["베기", "x", 1], ["막기", "y", 2]]:
		var art_path: String = root.path_join("%s/a.png" % pair[1])
		var f := FileAccess.open(art_path, FileAccess.WRITE)
		f.store_buffer(PackedByteArray([pair[2]]))
		f.close()
		var card_path: String = root.path_join("data/common/%s.tres" % pair[0])
		var card: CardData = _load(card_path)
		card.art = art_path
		ResourceSaver.save(card, card_path)
	var data := CardExporter.new(root).build()
	assert_ne(_by_id(data.cards, "c1").art, _by_id(data.cards, "c2").art)

func test_write_zip_round_trips_through_importer():
	var bytes := PackedByteArray([7, 7, 7])
	var original := {
		"keywords": [_keyword()],
		"decks": [_deck("d1", "홍연")],
		"cards": [_card("c1", "베기", "d1", [_face("베기+", 2, "art/a1.png")], "art/a1.png"), _card("c2", "막기")],
	}
	_import(original, {"art/a1.png": bytes})
	var zip_path := root.path_join("out.zip")
	assert_eq(CardExporter.new(root).write_zip(zip_path), "")

	var imp := CardImporter.new(out_root)
	assert_eq(imp.read_zip(zip_path), "")
	imp.apply()

	assert_eq(FileAccess.get_file_as_bytes(out_root.path_join("art/a1.png")), bytes)
	var again := CardExporter.new(out_root).build()
	assert_eq(_by_id(again.cards, "c1"), _by_id(original.cards, "c1"))
	assert_eq(_by_id(again.cards, "c2"), _by_id(original.cards, "c2"))
	assert_eq(again.keywords, original.keywords)
	assert_eq(again.decks, original.decks)

func test_reimporting_own_export_keeps_effects():
	_import({"keywords": [], "decks": [], "cards": [_card("c1", "베기")]})
	var path := root.path_join("data/common/베기.tres")
	var card: CardData = _load(path)
	card.effects.append(CardEffect.new())
	ResourceSaver.save(card, path)
	var zip_path := root.path_join("out.zip")
	CardExporter.new(root).write_zip(zip_path)
	var imp := CardImporter.new(root)
	imp.read_zip(zip_path)
	imp.apply()
	assert_eq((_load(path) as CardData).effects.size(), 1)

func test_write_zip_to_bad_path_returns_error():
	_import({"keywords": [], "decks": [], "cards": [_card("c1", "베기")]})
	assert_ne(CardExporter.new(root).write_zip(root.path_join("no/such/dir/out.zip")), "")

func test_empty_project_exports_empty_lists():
	assert_eq(CardExporter.new(root).build(), {"keywords": [], "decks": [], "cards": []})
