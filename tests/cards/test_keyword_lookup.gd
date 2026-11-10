extends GutTest

var dir: String

func before_each():
	dir = "user://test_kw_lookup_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)

func after_each():
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)

func _save(file_name: String, id: String, name_ko: String) -> void:
	var kw := KeywordData.new()
	kw.id = id
	kw.name_ko = name_ko
	ResourceSaver.save(kw, dir.path_join(file_name))

func test_find_by_id_inside_file():
	_save("출혈.tres", "k1", "출혈")
	assert_eq(KeywordData.find(dir, "k1").name_ko, "출혈")

func test_find_missing_returns_null():
	_save("출혈.tres", "k1", "출혈")
	assert_null(KeywordData.find(dir, "nope"))

func test_find_after_file_renamed():
	_save("출혈.tres", "k1", "출혈")
	assert_not_null(KeywordData.find(dir, "k1"))
	DirAccess.rename_absolute(dir.path_join("출혈.tres"), dir.path_join("깊은 출혈.tres"))
	assert_not_null(KeywordData.find(dir, "k1"))

func test_find_new_file_added_later():
	_save("출혈.tres", "k1", "출혈")
	KeywordData.find(dir, "k1")
	_save("소멸.tres", "k2", "소멸")
	assert_eq(KeywordData.find(dir, "k2").name_ko, "소멸")
