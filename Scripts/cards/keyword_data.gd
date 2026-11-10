@tool
class_name KeywordData
extends Resource
## 키워드 하나(예: 출혈, 관통)의 이름과 설명. cards/keywords/<키워드 이름>.tres 로 저장된다 (겹치면 <이름>_<id>).
## 파일 이름은 바뀔 수 있으므로 찾을 때는 파일 이름이 아니라 파일 안의 id 로 찾는다 → find().
## 웹 카드 에디터의 키워드 탭에서 만들고, 카드 가져오기 때 덮어쓴다.
## 카드에는 키워드 id 만 저장되고(CardData.keywords), 화면에 보일 때 여기서 이름·설명을 찾는다.
## (카드에 마우스를 올리면 오른쪽에 이 설명이 뜬다)

## 웹 에디터의 키워드 id. 카드(CardData.keywords)·장비가 이 값으로 키워드를 가리킨다.
@export var id: String
## 키워드 이름 (한국어 / 영어)
@export var name_ko: String
@export var name_en: String
## 키워드 설명 (한국어 / 영어). 툴팁에 표시된다.
@export_multiline var description_ko: String
@export_multiline var description_en: String

@export_group("Godot")
## 이 키워드의 동작 부품 목록 (카드의 Effects 와 같은 방식). 특별한 동작이 없는 키워드는 비워 둔다.
## 예) 소멸 → [ExileAfterUseRule] (사용 후 제외)
## 웹 에디터에는 없는 Godot 쪽 칸이라 카드 가져오기를 다시 해도 유지된다.
@export var rules: Array[KeywordRule] = []


## 폴더 경로 → { 키워드 id: 파일 경로 }. find() 가 채우고, 못 찾으면 폴더를 다시 훑어 갱신한다.
static var _index: Dictionary = {}


## dir 폴더에서 id 가 같은 키워드를 찾는다. 없으면 null.
## 파일 이름이 아니라 파일 안의 id 로 찾는다 (가져오기가 이름이 바뀐 키워드 파일을 옮기므로).
## 전투(BattleCardPlay)와 카드 화면(CardView)이 같이 쓴다.
static func find(dir: String, id: String) -> KeywordData:
	var kw := _from_index(dir, id)
	if kw == null:
		# 표에 없거나 파일이 옮겨졌으면 폴더를 다시 훑는다.
		_index[dir] = _scan(dir)
		kw = _from_index(dir, id)
	return kw


## 표에 적힌 경로의 키워드. 파일이 없거나 id 가 다르면 null.
static func _from_index(dir: String, id: String) -> KeywordData:
	var path: String = _index.get(dir, {}).get(id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var kw := load(path) as KeywordData
	return kw if kw and kw.id == id else null


## 폴더의 키워드 파일을 모두 읽어 { id: 경로 } 표를 만든다.
## 내보낸 게임에서는 파일 이름 끝에 .remap 이 붙으므로 떼고 읽는다.
static func _scan(dir: String) -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at(dir):
		var file := f.trim_suffix(".remap")
		if file.get_extension() != "tres":
			continue
		var path := dir.path_join(file)
		var kw := load(path) as KeywordData
		if kw:
			out[kw.id if not kw.id.is_empty() else file.get_basename()] = path
	return out
