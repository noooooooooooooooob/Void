class_name BattleTypes
extends RefCounted
## 전투 로직 전체가 같이 쓰는 열거형과 상수. 인스턴스를 만들지 않고 BattleTypes.Side.ALLY 처럼 쓴다.
## 규칙 출처: docs/superpowers/specs/2026-11-03-card-effect-system-design.md

## 편. 격자도 편마다 따로 있다 (왼쪽 아군, 오른쪽 적).
enum Side { ALLY, ENEMY }

## 스탯 종류. 최종값 = floor(기본 × (1 + %보정 합/100)) + 고정보정 합.
## SPEED 속도 = 행동 순서. 고정값이 아니라 최소~최대 범위이고, 매 라운드 행동마다 굴린다.
##   SPEED 보정은 굴린 값에 적용한다 (BattleUnit.action_speed). get_stat(SPEED) 는 쓰지 않는다.
## MOVE 이동속도 = 한 차례에 움직일 수 있는 칸 수 (속도와 다른 스탯).
## CRIT_RATE 치명확률(%), CRIT_DAMAGE 치명피해(150 = ×1.5), STAMINA 스태미너 최대치.
## ACTIONS 행동 횟수 = 한 라운드에 행동하는 횟수. 행동마다 속도를 따로 굴린다.
## (새 스탯은 맨 뒤에 붙인다: .tres 에 숫자로 저장되므로 순서를 바꾸면 기존 데이터가 어긋난다)
enum Stat { HP, SP, ATTACK, DEFENSE, SPEED, MOVE, CRIT_RATE, CRIT_DAMAGE, AGGRO, STAMINA, ACTIONS }

## 전투 이벤트. 상태·패시브·장비가 이 이벤트에 구독해서 반응한다.
## 같은 이벤트의 구독자는 구독한 순서대로 실행된다.
enum Event {
	BATTLE_START, BATTLE_END, ROUND_START, ROUND_END,     # 전투·라운드
	TURN_START, DRAW_PHASE, STANDBY_PHASE, END_PHASE, TURN_END,  # 한 유닛의 차례 (이 순서로 진행)
	BEFORE_CARD_PLAYED, AFTER_CARD_PLAYED, CARD_DRAWN, CARD_DISCARDED,  # 카드
	DAMAGE_DEALT, DAMAGE_TAKEN, HEALED, BLOCK_GAINED, BLOCK_RESET,  # 피해·회복·방어도
	STATUS_APPLIED, STATUS_REMOVED, UNIT_MOVED, UNIT_DIED, STAMINA_BROKEN,  # 상태·이동·사망·스태미너 0
	TURN_ORDER_CHANGED,  # 속도 변화로 행동 순서가 바뀜 (화면의 순서 표시 갱신용)
}

## 효과가 누구에게 적용되는지.
## TARGETS: 카드가 정한 대상들 (광역 범위 포함) / 상태 트리거에서는 이벤트의 대상
## SELF: 행위자(카드를 쓴 유닛, 상태를 건 유닛) / OWNER: 상태를 가진 유닛 (카드에서는 SELF 와 같음)
## ALL_ALLIES / ALL_ENEMIES: 주인 기준 아군 전체 / 적 전체
enum Target { TARGETS, SELF, OWNER, ALL_ALLIES, ALL_ENEMIES }

## 배율 등에서 "누구의" 값을 볼지. ACTOR 행위자 / OWNER 상태를 가진 유닛.
enum Who { ACTOR, OWNER }

## 상태 트리거가 어떤 이벤트에 반응할지.
## ANY 모두 / OWNER_IS_ACTOR 주인이 이벤트의 행위자일 때 (예: 내 차례, 내가 준 피해)
## OWNER_IS_TARGET 주인이 이벤트의 대상일 때 (예: 내가 받은 피해)
enum Filter { ANY, OWNER_IS_ACTOR, OWNER_IS_TARGET }

## 상태의 종류 (노션 버프 상태 DB의 태그와 같음)
enum StatusTag { BUFF, DEBUFF, PASSIVE }

## 스탯 보정 방식. PERCENT 는 먼저 더해서 곱하고, FLAT 은 그 뒤에 더한다.
enum ModKind { PERCENT, FLAT }

## 격자 크기 기본값 (행 × 열). 실제 크기는 전투마다 정한다 (Battle 생성 인자).
## 행 수는 양쪽 편이 같아야 하고(근접 = 같은 행), 열 수는 편마다 다를 수 있다. 열은 클수록 앞(상대 쪽).
const DEFAULT_GRID_ROWS := 3
const DEFAULT_GRID_COLS := 4
## 이벤트가 이벤트를 부르는 연쇄의 최대 깊이. 넘으면 더 발행하지 않는다 (무한 반복 방지).
const CHAIN_LIMIT := 10
## 아군의 기본 드로우 장수 (적은 1장)
const DEFAULT_DRAW := 5
