@tool
class_name EquipmentData
extends Resource
## 장비 하나. 유닛(UnitData.equipment)이 착용하면 항상 적용된다 (전투 밖에서도, 기획 결정).
## 칸은 두 부류로 나뉜다 (카드와 같은 분담, 설계: docs/superpowers/specs/2026-11-10-equipment-editor-design.md):
##   - 웹 카드 에디터가 담당: id, 이름·설명, 종류, 등급, 스탯(stats), 키워드, 그림.
##     "카드 가져오기"가 덮어쓰므로 여기서 손으로 고치지 말고 웹 에디터에서 고친 뒤 다시 가져온다.
##   - Godot 이 담당: statuses (특별한 버프·특수 효과). 가져오기가 건드리지 않는다.
## 기획 규칙: 장비 공격 보너스는 카드 피해가 아니라 공격 스탯에 더해진다.

## 종류 값 목록 (웹 에디터와 같은 순서·이름). 저장 폴더 이름으로도 쓴다.
const SLOTS: Array[String] = ["weapon", "armor", "accessory"]
## 등급 값 목록. 노말 → 레어 → 유니크 → 유물 순.
const RARITIES: Array[String] = ["normal", "rare", "unique", "relic"]

## 웹 에디터의 장비 id. 가져오기가 파일을 찾는 기준. 비어 있으면 가져오기·내보내기가 이 파일을 무시한다.
@export var id: String
## 화면에 보일 이름 (한국어)
@export var display_name: String
## 영어 이름
@export var name_en: String
## 설명 (한국어). 특별한 버프·특수 효과도 여기 글로 적고, 실제 동작은 statuses 에 붙인다.
@export_multiline var description_ko: String
## 설명 (영어)
@export_multiline var description_en: String
## 종류: "weapon" 무기 / "armor" 방어구 / "accessory" 장신구. 지금은 분류·표시용 (착용 칸 제한 없음)
@export_enum("weapon", "armor", "accessory") var slot: String = "weapon"
## 등급: "normal" 노말 / "rare" 레어 / "unique" 유니크 / "relic" 유물
@export_enum("normal", "rare", "unique", "relic") var rarity: String = "normal"
## 착용 중 항상 더해지는 스탯 보정 (웹 에디터의 스탯 줄). 상태가 아니라 BattleUnit 이 장비에서 직접 읽는다.
## 그래서 장비를 빼면 그만큼 바로 빠진다.
@export var stats: Array[StatModifier] = []
## 키워드 id 목록 (cards/keywords/ 의 키워드를 카드와 함께 쓴다. KeywordData.find 로 찾음)
@export var keywords: PackedStringArray = []
## 그림 경로 (res://statuses/equipment/art/…). 비어 있으면 그림 없음.
@export var art: String
## 착용하면 붙는 상태들 (보통 uses_stacks = false 인 패시브). 특별한 버프·특수 효과용 — Godot 담당.
@export var statuses: Array[StatusData] = []
