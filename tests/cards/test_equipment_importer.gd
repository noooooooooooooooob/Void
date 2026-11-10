extends GutTest

var root: String
var units: String

func before_each():
	var t := Time.get_ticks_usec()
	root = "user://test_equip_%d" % t
	units = "user://test_units_%d" % t

func after_each():
	_remove_tree(root)
	_remove_tree(units)

func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_remove_tree(path.path_join(sub))
	for f in dir.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)

func _equip(id: String, name_ko: String, slot := "weapon", art = null) -> Dictionary:
	return {
		"id": id,
		"name": {"ko": name_ko, "en": name_ko + "_en"},
		"description": {"ko": "설명", "en": "desc"},
		"slot": slot, "rarity": "rare",
		"stats": [{"stat": "attack", "kind": "flat", "amount": 5}, {"stat": "speed", "kind": "percent", "amount": -10}],
		"keywords": ["k1"], "art": art,
	}

func _export(equipment: Array) -> Dictionary:
	return {"keywords": [], "decks": [], "cards": [], "equipment": equipment}

func _importer(data: Dictionary, art := {}) -> EquipmentImporter:
	var imp := EquipmentImporter.new(root, units)
	imp.load_export(data, art)
	return imp

func _import(data: Dictionary, art := {}) -> EquipmentImporter:
	var imp := _importer(data, art)
	imp.apply()
	return imp

func _load(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)

func _path(slot: String, file_name: String) -> String:
	return root.path_join("%s/%s.tres" % [slot, file_name])

func _uid_line(path: String) -> String:
	return FileAccess.get_file_as_string(path).get_slice("\n", 0)


func test_new_equipment_created_in_slot_folder():
	_import(_export([_equip("e1", "검")]))
	var eq: EquipmentData = _load(_path("weapon", "검"))
	assert_not_null(eq)
	assert_eq(eq.id, "e1")
	assert_eq(eq.display_name, "검")
	assert_eq(eq.name_en, "검_en")
	assert_eq(eq.description_ko, "설명")
	assert_eq(eq.description_en, "desc")
	assert_eq(eq.slot, "weapon")
	assert_eq(eq.rarity, "rare")
	assert_eq(eq.stats.size(), 2)
	assert_eq(eq.stats[0].stat, BattleTypes.Stat.ATTACK)
	assert_eq(eq.stats[0].kind, BattleTypes.ModKind.FLAT)
	assert_eq(eq.stats[0].amount, 5.0)
	assert_eq(eq.stats[1].stat, BattleTypes.Stat.SPEED)
	assert_eq(eq.stats[1].kind, BattleTypes.ModKind.PERCENT)
	assert_eq(eq.stats[1].amount, -10.0)
	assert_eq(eq.keywords, PackedStringArray(["k1"]))

func test_same_name_in_slot_gets_id_suffix():
	_import(_export([_equip("e1", "검"), _equip("e2", "검")]))
	assert_true(FileAccess.file_exists(_path("weapon", "검")))
	assert_true(FileAccess.file_exists(_path("weapon", "검_e2")))

func test_reimport_keeps_godot_statuses():
	_import(_export([_equip("e1", "검")]))
	var eq: EquipmentData = _load(_path("weapon", "검"))
	var st := StatusData.new()
	st.id = "gear_buff"
	eq.statuses.append(st)
	ResourceSaver.save(eq, _path("weapon", "검"))
	var again := _equip("e1", "검")
	again["stats"] = [{"stat": "hp", "kind": "flat", "amount": 20}]
	_import(_export([again]))
	eq = _load(_path("weapon", "검"))
	assert_eq(eq.statuses.size(), 1)
	assert_eq(eq.stats.size(), 1)
	assert_eq(eq.stats[0].stat, BattleTypes.Stat.HP)

func test_rename_moves_file_keeps_uid():
	_import(_export([_equip("e1", "검")]))
	var uid := _uid_line(_path("weapon", "검"))
	_import(_export([_equip("e1", "큰 방패", "armor")]))
	assert_false(FileAccess.file_exists(_path("weapon", "검")))
	assert_true(FileAccess.file_exists(_path("armor", "큰 방패")))
	assert_eq(_uid_line(_path("armor", "큰 방패")), uid)

func test_removed_equipment_deleted_and_previewed():
	_import(_export([_equip("e1", "검"), _equip("e2", "방패", "armor")]))
	var imp := _importer(_export([_equip("e1", "검")]))
	var p := imp.preview()
	assert_eq(p.updated, PackedStringArray(["검"]))
	assert_eq(p.removed.size(), 1)
	assert_eq(p.removed[0].name, "방패")
	assert_false(p.removed[0].has_statuses)
	imp.apply()
	assert_false(FileAccess.file_exists(_path("armor", "방패")))

func test_preview_lists_added():
	var p := _importer(_export([_equip("e1", "검")])).preview()
	assert_eq(p.added, PackedStringArray(["검"]))
	assert_eq(p.removed.size(), 0)

func test_equipped_equipment_kept():
	_import(_export([_equip("e1", "검")]))
	var unit := UnitData.new()
	unit.display_name = "홍연"
	unit.equipment.assign([_load(_path("weapon", "검"))])
	DirAccess.make_dir_recursive_absolute(units.path_join("sub"))
	ResourceSaver.save(unit, units.path_join("sub/hong.tres"))
	var imp := _importer(_export([]))
	var p := imp.preview()
	assert_eq(p.removed.size(), 0)
	assert_eq(p.kept.size(), 1)
	assert_eq(p.kept[0].name, "검")
	assert_eq(p.kept[0].units, PackedStringArray(["홍연"]))
	imp.apply()
	assert_true(FileAccess.file_exists(_path("weapon", "검")))

func test_file_without_id_untouched():
	var old := EquipmentData.new()
	old.display_name = "시험용 검"
	DirAccess.make_dir_recursive_absolute(root)
	ResourceSaver.save(old, root.path_join("test_sword.tres"))
	_import(_export([_equip("e1", "검")]))
	assert_true(FileAccess.file_exists(root.path_join("test_sword.tres")))

func test_zip_without_equipment_key_changes_nothing():
	_import(_export([_equip("e1", "검")]))
	var imp := _importer({"keywords": [], "decks": [], "cards": []})
	var p := imp.preview()
	assert_eq(p.removed.size(), 0)
	imp.apply()
	assert_true(FileAccess.file_exists(_path("weapon", "검")))

func test_equipment_art_copied_and_unused_removed():
	var bytes := PackedByteArray([1, 2, 3])
	_import(_export([_equip("e1", "검", "weapon", "art/sword.png")]), {"art/sword.png": bytes})
	var eq: EquipmentData = _load(_path("weapon", "검"))
	assert_eq(eq.art, root.path_join("art/sword.png"))
	assert_eq(FileAccess.get_file_as_bytes(eq.art), bytes)
	_import(_export([_equip("e1", "검")]))
	assert_false(FileAccess.file_exists(root.path_join("art/sword.png")))
	eq = _load(_path("weapon", "검"))
	assert_eq(eq.art, "")

func test_unknown_slot_and_rarity_fall_back():
	var e := _equip("e1", "검")
	e["slot"] = "hat"
	e["rarity"] = "mythic"
	e["stats"] = [{"stat": "luck", "kind": "flat", "amount": 1}]
	_import(_export([e]))
	var eq: EquipmentData = _load(_path("weapon", "검"))
	assert_eq(eq.slot, "weapon")
	assert_eq(eq.rarity, "normal")
	assert_eq(eq.stats.size(), 0)
