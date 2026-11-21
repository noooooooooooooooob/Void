extends GutTest
# 폴더 안 .tres 경로 찾기 (내보낸 빌드의 .remap 처리 포함).

const DIR := "user://test_res_dir"

func before_each():
	DirAccess.make_dir_recursive_absolute(DIR + "/sub")
	for f in ["a.tres", "b.tres.remap", "c.txt", "sub/d.tres"]:
		var file := FileAccess.open(DIR.path_join(f), FileAccess.WRITE)
		file.store_string("x")
		file.close()

func after_each():
	for f in ["a.tres", "b.tres.remap", "c.txt", "sub/d.tres"]:
		DirAccess.remove_absolute(DIR.path_join(f))
	DirAccess.remove_absolute(DIR + "/sub")
	DirAccess.remove_absolute(DIR)

func test_lists_tres_and_strips_remap_without_subfolders():
	var paths := ResDir.tres_paths(DIR)
	paths.sort()
	assert_eq(paths, PackedStringArray([DIR + "/a.tres", DIR + "/b.tres"]))

func test_missing_folder_is_empty():
	assert_eq(ResDir.tres_paths("user://no_such_dir").size(), 0)
