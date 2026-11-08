class_name VoidSiteData
extends Resource
## 공허 지도의 장소(공허) 하나. voids/<id>.tres 로 에디터 인스펙터에서 만든다.
## 공허 지도(void_map.tscn)가 sites 목록으로 들고 있고, 들어가면 StageRun 이 이 공허로 의뢰를 시작한다.
## 장소마다 이름·설명·지도 위 위치·전투 배경이 다르다. 스테이지 규칙은 지금 1층 하나뿐이다.

## 고유 이름 (파일 이름과 같게). 정화 기록(StageRun.cleared_sites)의 열쇠
@export var id: String
## 화면에 보이는 이름 (예: "산중 신사")
@export var display_name: String
## 공허 지도 정보 패널의 설명
@export_multiline var description: String
## 공허 지도 그림 위 위치 (px, 지도 그림 왼쪽 위 기준, 표식의 중심)
@export var map_position: Vector2
## 층. 지금은 1층 규칙(StageGenerator)뿐이라 1
@export var floor_level: int = 1
## 이 공허에서 싸울 때의 전투 배경 씬 (Scenes/backgrounds/ 의 루트 Control 씬)
@export var background: PackedScene
