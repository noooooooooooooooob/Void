@tool
class_name CardData
extends Resource
## 카드 한 장의 데이터. cards/data/<덱 이름>/<카드 이름>.tres 로 저장된다.
##
## 칸은 두 그룹으로 나뉜다.
## - "웹 에디터" 그룹: 웹 카드 에디터가 담당. 카드 가져오기 때마다 덮어쓴다. 여기서 고쳐도 다음 가져오기에 사라진다.
## - "Godot" 그룹: Godot 에서 조합하는 비용·조건·효과. 카드 가져오기를 해도 유지된다.
##
## 이름과 값은 웹 에디터 내보내기 형식에 맞춘다 (attackType → attack_type 처럼 snake_case 로만 바꿈).
## 전투 규칙(설계 문서 3.3, 4.1~4.4): docs/superpowers/specs/2026-11-03-card-effect-system-design.md

@export_group("웹 에디터")
## 웹 에디터의 카드 id. 파일 이름과 같다. 다시 가져올 때 같은 카드를 찾는 기준.
@export var id: String
## 덱 전용 카드면 웹 에디터의 덱 id, 공용 카드면 "".
@export var deck_id: String
## 카드 이름 (한국어 / 영어)
@export var name_ko: String
@export var name_en: String
## 카드 설명 (한국어 / 영어)
@export_multiline var description_ko: String
@export_multiline var description_en: String
## 사용할 때 드는 SP. 전투에서 자동으로 SP 비용으로 처리된다 (costs 에 따로 넣지 않는다).
@export var sp: int = 1
## 덱 코스트 (덱에 넣을 때의 비용. 규칙은 아직 미정)
@export var cost: int = 0
## 분류: attack 공격(빨강) / skill 스킬(파랑) / special 특수(보라) / enemy 적 전용(검정, 플레이어 덱에 안 나옴)
@export_enum("attack", "skill", "special", "enemy") var category: String = "attack"
## 공격 종류
## melee  근접: 같은 행의 맨 앞 적에게 자동 적용. 그 행에 적이 없으면 못 씀
## ranged 원거리: 상대 편 아무 유닛을 기준으로 지정
## ally   아군: 아군 아무나(자신 포함)
## self   자신: 대상 지정 없이 즉시 사용
@export_enum("melee", "ranged", "ally", "self") var attack_type: String = "melee"
## 광역 범위: 기준 유닛에서의 칸 오프셋 목록 (x = 앞쪽이 +, y = 행, 각각 −2..2). 비어 있으면 단일 대상.
@export var area: Array[Vector2i] = []
## 키워드 id 목록. 이름·설명은 cards/keywords/ 안의 KeywordData 에 있다 (KeywordData.find 로 id 로 찾음).
@export var keywords: PackedStringArray = []
## 카드 그림 경로 (보통 res://cards/art/...). 없으면 "".
@export_file("*.png", "*.jpg", "*.webp", "*.gif") var art: String
## 강화 단계 (최대 5). 각 단계도 CardData 이고, 같은 규칙으로 웹 에디터 칸만 덮어쓴다.
@export var upgrades: Array[CardData] = []

@export_group("Godot")
## 추가 비용 (SP 외). 예: 상태 수치 소모(StatusCost). 모두 지불할 수 있어야 카드를 쓸 수 있다.
@export var costs: Array[CardCost] = []
## 사용 조건. 예: 특정 상태 수치 이상(HasStatusCondition). 모두 만족해야 카드를 쓸 수 있다.
@export var conditions: Array[CardCondition] = []
## 효과 목록. 위에서부터 차례로 실행된다. 예: 피해 → 상태 부여.
@export var effects: Array[CardEffect] = []
