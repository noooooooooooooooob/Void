class_name CharacterProfile
extends Resource
## 사무소 캐릭터 한 명의 프로필: 이름·역할·소속·설명·특성과 그림(일러스트·픽셀·초상), 전투 유닛.
## entities/characters/<id>.tres 로 에디터 인스펙터에서 편집한다. 사원 명부(RosterData)가 목록으로 들고 있고,
## 캐릭터 페이지(roster.tscn)가 보여준다. 글 칸은 지금 임시 문구 — 노션 등장인물 표가 정해지면 바꾼다.

## 고유 이름 (파일 이름과 같게, 영어 snake_case)
@export var id: String
## 화면 이름 (예: "브람 웰번")
@export var display_name: String
## 역할 (예: "탱커 · 노동자")
@export var role: String
## 소속 (예: "정화 사무소")
@export var affiliation: String
## 나이 (글자, 모르면 "미정")
@export var age: String = "미정"
## 키 (글자, 모르면 "미정")
@export var height: String = "미정"
## 캐릭터 페이지의 설명
@export_multiline var description: String
## 특성 이름들 (캐릭터 페이지 아래쪽 칩)
@export var traits: PackedStringArray = []

@export_group("그림")
## 큰 일러스트 (Art/characters/<id>/<id>_illust.png)
@export var illustration: Texture2D
## 픽셀 캐릭터 (Art/characters/<id>/<id>_pixel.png). 없으면 비워 둔다
@export var pixel: Texture2D
## 목록용 얼굴 그림. 보통 일러스트의 얼굴 부분을 자른 AtlasTexture (자르는 범위 region 은 인스펙터에서 조정)
@export var portrait: Texture2D

@export_group("전투")
## 전투 유닛 (스탯·덱). 비어 있으면 아직 전투에 못 나가고 덱은 "미정"
@export var unit: UnitData
