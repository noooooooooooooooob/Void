@tool
class_name KeywordData
extends Resource
## 키워드 하나(예: 출혈, 관통)의 이름과 설명. cards/keywords/<id>.tres 로 저장된다.
## 웹 카드 에디터의 키워드 탭에서 만들고, 카드 가져오기 때 덮어쓴다.
## 카드에는 키워드 id 만 저장되고(CardData.keywords), 화면에 보일 때 여기서 이름·설명을 찾는다.
## (카드에 마우스를 올리면 오른쪽에 이 설명이 뜬다)

## 웹 에디터의 키워드 id. 파일 이름과 같다.
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
