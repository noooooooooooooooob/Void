class_name RosterData
extends Resource
## 사원 명부: 플레이어 사무소에 있는 캐릭터 목록. entities/roster.tres 하나를 에디터 인스펙터에서 편집한다.
## 사원 명부 화면이 목록을 보여주고, StageRun 이 의뢰 파티를 이 캐릭터들로 만든다.
## (entities/units/ 폴더를 통째로 읽지 않는 이유: 시험용 적·시험용 유닛까지 섞이기 때문)

## 사무소 캐릭터들. 앞에서부터 파티에 들어간다
@export var units: Array[UnitData] = []
