class_name ResDir
extends RefCounted
## 데이터 폴더를 훑을 때 쓰는 도우미. 카드·키워드·소비 아이템 목록, 카드 갤러리가 같이 쓴다.
## 내보낸 게임(export)에서는 리소스 파일 이름 끝에 .remap 이 붙으므로 떼고 돌려준다
## — 그래야 load() 가 에디터와 내보낸 게임 양쪽에서 같은 경로로 동작한다.


## dir 바로 안의 .tres 파일 경로들 (하위 폴더는 보지 않는다). 폴더가 없으면 빈 배열.
## 예) "res://items/consumables/폭탄.tres"
static func tres_paths(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		var file := f.trim_suffix(".remap")
		if file.get_extension() == "tres":
			out.append(dir.path_join(file))
	return out
