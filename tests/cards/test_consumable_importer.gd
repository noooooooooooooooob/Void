extends GutTest

var root: String

func before_each():
	root = "user://test_consumables_%d" % Time.get_ticks_usec()

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

func _item(id: String, name_ko: String, extra := {}) -> Dictionary:
	var d := {
		"id": id,
		"name": {"ko": name_ko, "en": name_ko + "_en"},
		"description": {"ko": "설명", "en": "desc"},
		"target": "enemy", "area": [[0, 0], [0, 1]],
		"effects": [{"type": "heal_hp", "kind": "flat", "amount": -20}, {"type": "heal_sp", "kind": "percent", "amount": 10}],
		"keywords": ["k1"], "art": null,
	}
	d.merge(extra, true)
	return d

func _export(items: Array) -> Dictionary:
	return {"keywords": [], "decks": [], "cards": [], "equipment": [], "consumables": items}

func _importer(data: Dictionary, art := {}) -> ConsumableImporter:
	var imp := ConsumableImporter.new(root)
	imp.load_export(data, art)
	return imp

func _import(data: Dictionary, art := {}) -> ConsumableImporter:
	var imp := _importer(data, art)
	imp.apply()
	return imp

func _load(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)

func _path(file_name: String) -> String:
	return root.path_join(file_name + ".tres")

func _uid_line(path: String) -> String:
	return FileAccess.get_file_as_string(path).get_slice("\n", 0)


func test_new_item_created():
	_import(_export([_item("c1", "폭탄")]))
	var item: ConsumableData = _load(_path("폭탄"))
	assert_not_null(item)
	assert_eq(item.id, "c1")
	assert_eq(item.display_name, "폭탄")
	assert_eq(item.name_en, "폭탄_en")
	assert_eq(item.description_ko, "설명")
	assert_eq(item.target, ConsumableData.Target.ENEMY)
	assert_eq(item.area, [Vector2i(0, 0), Vector2i(0, 1)] as Array[Vector2i])
	assert_eq(item.lines.size(), 2)
	assert_eq(item.lines[0].type, ConsumableLine.Type.HEAL_HP)
	assert_eq(item.lines[0].kind, ConsumableLine.Kind.FLAT)
	assert_eq(item.lines[0].amount, -20)
	assert_eq(item.lines[1].type, ConsumableLine.Type.HEAL_SP)
	assert_eq(item.lines[1].kind, ConsumableLine.Kind.PERCENT)
	assert_eq(item.lines[1].amount, 10)
	assert_eq(item.keywords, PackedStringArray(["k1"]))

func test_buff_lines_dropped_and_previewed():
	var it := _item("c1", "힘의 물약", {"effects": [
		{"type": "buff", "stat": "attack", "kind": "flat", "amount": 5, "turns": 3},
		{"type": "heal_hp", "kind": "flat", "amount": 10}]})
	var imp := _importer(_export([it]))
	assert_eq(imp.preview().dropped, [{"name": "힘의 물약", "count": 1}])
	imp.apply()
	var item: ConsumableData = _load(_path("힘의 물약"))
	assert_eq(item.lines.size(), 1)
	assert_eq(item.lines[0].amount, 10)

func test_old_item_without_target_area_is_ally_single():
	var it := _item("c1", "물약")
	it.erase("target")
	it.erase("area")
	_import(_export([it]))
	var item: ConsumableData = _load(_path("물약"))
	assert_eq(item.target, ConsumableData.Target.ALLY)
	assert_true(item.area.is_empty())

func test_unknown_target_falls_back_to_ally():
	_import(_export([_item("c1", "물약", {"target": "nobody"})]))
	assert_eq((_load(_path("물약")) as ConsumableData).target, ConsumableData.Target.ALLY)

func test_both_target():
	_import(_export([_item("c1", "물약", {"target": "both"})]))
	assert_eq((_load(_path("물약")) as ConsumableData).target, ConsumableData.Target.BOTH)

func test_area_out_of_range_and_duplicates_dropped():
	_import(_export([_item("c1", "물약", {"area": [[3, 0], [0, 0], [0, 0]]})]))
	assert_eq((_load(_path("물약")) as ConsumableData).area, [Vector2i(0, 0)] as Array[Vector2i])

func test_reimport_keeps_godot_effects():
	_import(_export([_item("c1", "폭탄")]))
	var item: ConsumableData = _load(_path("폭탄"))
	var fx := HealEffect.new()
	item.effects.assign([fx])
	ResourceSaver.save(item, _path("폭탄"))
	_import(_export([_item("c1", "폭탄", {"description": {"ko": "바뀐 설명", "en": ""}})]))
	var again: ConsumableData = _load(_path("폭탄"))
	assert_eq(again.description_ko, "바뀐 설명")
	assert_eq(again.effects.size(), 1)

func test_rename_moves_file_keeps_uid():
	_import(_export([_item("c1", "폭탄")]))
	var uid := _uid_line(_path("폭탄"))
	_import(_export([_item("c1", "큰 폭탄")]))
	assert_false(FileAccess.file_exists(_path("폭탄")))
	assert_true(FileAccess.file_exists(_path("큰 폭탄")))
	assert_eq(_uid_line(_path("큰 폭탄")), uid)

func test_removed_item_deleted_and_previewed():
	_import(_export([_item("c1", "폭탄"), _item("c2", "독약")]))
	var item: ConsumableData = _load(_path("독약"))
	item.effects.assign([HealEffect.new()])
	ResourceSaver.save(item, _path("독약"))
	var imp := _importer(_export([_item("c1", "폭탄")]))
	assert_eq(imp.preview().removed, [{"name": "독약", "has_effects": true}])
	imp.apply()
	assert_false(FileAccess.file_exists(_path("독약")))
	assert_true(FileAccess.file_exists(_path("폭탄")))

func test_preview_lists_added_and_updated():
	_import(_export([_item("c1", "폭탄")]))
	var p := _importer(_export([_item("c1", "폭탄"), _item("c2", "독약")])).preview()
	assert_eq(p.added, PackedStringArray(["독약"]))
	assert_eq(p.updated, PackedStringArray(["폭탄"]))

func test_file_without_id_untouched():
	DirAccess.make_dir_recursive_absolute(root)
	var own := ConsumableData.new()
	own.display_name = "회복약"
	ResourceSaver.save(own, _path("회복약"))
	_import(_export([_item("c1", "회복약")]))
	var kept: ConsumableData = _load(_path("회복약"))
	assert_eq(kept.id, "")
	assert_true(FileAccess.file_exists(_path("회복약_c1")))
	_import(_export([]))
	assert_true(FileAccess.file_exists(_path("회복약")))

func test_zip_without_consumables_key_changes_nothing():
	_import(_export([_item("c1", "폭탄")]))
	var imp := _importer({"keywords": [], "decks": [], "cards": []})
	assert_eq(imp.preview().removed, [])
	imp.apply()
	assert_true(FileAccess.file_exists(_path("폭탄")))

func test_art_copied_and_unused_removed():
	_import(_export([_item("c1", "폭탄", {"art": "art/bomb.png"})]), {"art/bomb.png": PackedByteArray([1, 2, 3])})
	var item: ConsumableData = _load(_path("폭탄"))
	assert_eq(item.art, root.path_join("art/bomb.png"))
	assert_true(FileAccess.file_exists(root.path_join("art/bomb.png")))
	_import(_export([_item("c1", "폭탄")]))
	assert_false(FileAccess.file_exists(root.path_join("art/bomb.png")))
