class_name RosterData
extends Resource
## 사원 명부: 플레이어 사무소에 있는 캐릭터 목록. entities/roster.tres 하나를 에디터 인스펙터에서 편집한다.
## 캐릭터 페이지(roster.tscn)가 목록을 보여주고, StageRun 이 의뢰 파티를 전투 유닛이 있는 캐릭터로 만든다.
## (entities/ 폴더를 통째로 읽지 않는 이유: 시험용 적·시험용 유닛까지 섞이기 때문)

## 사무소 캐릭터들 (캐릭터 페이지 왼쪽 목록 순서)
@export var characters: Array[CharacterProfile] = []


## 전투에 나갈 수 있는 캐릭터의 유닛들 (목록 순서). 파티는 앞에서부터 전투 데이터의 아군 자리 수만큼
func playable_units() -> Array[UnitData]:
	var out: Array[UnitData] = []
	for c in characters:
		if c and c.unit:
			out.append(c.unit)
	return out
