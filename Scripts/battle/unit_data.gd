@tool
class_name UnitData
extends Resource
## 캐릭터·적 한 명의 기본 데이터. 게임에서 쓸 유닛은 .tres 로 만들어 둔다.
## 전투에 들어가면 BattleUnit 이 이 데이터를 바탕으로 HP·SP 등을 들고 싸운다.
## 스탯 이름과 의미는 노션 "구현 확정"과 설계 문서 3.4 를 따른다.

## 화면에 보일 이름
@export var display_name: String

@export_group("스탯")
## 최대 HP
@export var max_hp: int = 100
## 최대 SP. 자기 차례가 시작될 때 가득 회복된다.
@export var max_sp: int = 3
## 공격. 피해·회복 효과의 기준 스탯 (수치 = 공격 × %).
@export var attack: int = 10
## 방어. 방어도 효과의 기준 스탯. 받는 피해를 줄이지는 않는다 (기획 결정).
@export var defense: int = 10
## 속도 범위 (최소~최대). 매 라운드 행동마다 이 범위에서 속도를 굴리고, 클수록 먼저 행동한다.
## 감속·가속 보정은 굴린 값에 적용되고, 라운드 중에 바뀌면 행동 순서가 즉시 다시 정렬된다.
@export var speed_min: int = 1
@export var speed_max: int = 10
## 행동 횟수. 한 라운드에 몇 번 행동하는지. 행동마다 속도를 따로 굴린다. 버프·장비로 바뀔 수 있다.
@export var actions_per_round: int = 1
## 이동속도. 자기 차례에 움직일 수 있는 칸 수 (상하좌우 한 칸 = 1).
@export var move: int = 2
## 치명확률 (%). 피해 효과에만, 맞는 유닛마다 따로 판정.
@export var crit_rate: int = 0
## 치명피해 (%). 150 이면 치명타 때 ×1.5.
@export var crit_damage: int = 150
## 어그로. 값만 있고 규칙은 아직 미정.
@export var aggro: int = 0
## 최대 스태미너. 받은 피해(방어도로 막은 양 포함)만큼 깎이고, 준 피해의 절반만큼 회복. 0 이 되면 기절·탈진(미정).
@export var max_stamina: int = 100

@export_group("덱")
## 자기 차례에 뽑는 카드 수 (아군 기준. 적은 1장).
@export var draw_count: int = BattleTypes.DEFAULT_DRAW

@export_group("화면")
## 전투 화면에 서 있는 픽셀 캐릭터 그림 (Art/characters/<id>/<id>_pixel.png). 비우면 네모 상자로 그린다 (지금 적들)
@export var battle_sprite: Texture2D
## 보스면 덱을 섞지 않고 덱 순서대로 한 장씩 쓴다.
@export var is_boss: bool = false
## 전투에 들고 가는 카드들
@export var deck: Array[CardData] = []

@export_group("패시브·장비")
## 전투 시작 시 붙는 패시브 상태들
@export var passives: Array[StatusData] = []
## 착용 장비들 (전투 시작 시 장비의 상태들이 붙는다)
@export var equipment: Array[EquipmentData] = []
